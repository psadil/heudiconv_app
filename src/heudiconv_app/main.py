from datetime import datetime
from importlib import resources
import logging
import pathlib
import stat
import tempfile
import zipfile

import click

import pandas as pd

import pydicom

from nilearn import image

from heudiconv.main import workflow

import prefect
from prefect import task_runners

# import prefect_dask
# from dask import config


from . import check_acq
from . import utils

BIDSIGNORE = """
*.err
*.out
__pycache__*
sub-*/ses-*/fmap/*.bval
sub-*/ses-*/fmap/*.bvec
"""


@prefect.task
def unzip(p: pathlib.Path) -> pathlib.Path:
    tmpdir = tempfile.mkdtemp()
    zipfile.ZipFile(p).extractall(tmpdir)
    return pathlib.Path(tmpdir)


def add_bidsignore(p: pathlib.Path) -> None:
    (p / ".bidsignore").write_text(BIDSIGNORE)


def delete_duplicates(p: pathlib.Path) -> None:
    dups = set(p.glob("**/*dup*"))
    if dups:
        for dup in dups:
            logging.warning(f"deleting duplicate scan: {dup.name}")
            dup.unlink()
    for scans_tsv in p.glob("**/*scans.tsv"):
        scans = pd.read_csv(scans_tsv, delim_whitespace=True)
        scans.query("not 'dup' in filename").to_csv(
            scans_tsv, sep="\t", na_rep="n/a", index=False
        )


def index_coilqa(img: pathlib.Path) -> None:
    # keep as str because load_img can't handle Path
    full = image.load_img(img)
    assert len(full.shape) == 4  # type: ignore
    final = image.index_img(full, full.shape[-1] - 1)  # type: ignore
    final.to_filename(img)


def confirm_date(dicomdir: pathlib.Path, bidsdir: pathlib.Path) -> None:
    for dcm in dicomdir.glob("**/*dcm"):
        header = pydicom.dcmread(dcm, specific_tags=["SeriesDate", "SeriesTime"])
        AcquisitionDateTime = datetime.strptime(
            header.SeriesDate + header.SeriesTime, "%Y%m%d%H%M%S.%f"
        ).isoformat()
        for scans_tsv in bidsdir.glob("**/sub*scans.tsv"):
            scans = pd.read_csv(scans_tsv, delim_whitespace=True)
            scans.acq_time = AcquisitionDateTime
            scans.to_csv(scans_tsv, sep="\t", na_rep="n/a", index=False)
        break


def delete_rest_events(p: pathlib.Path) -> None:
    events = set(p.glob("**/*rest*events*"))
    for event in events:
        event.unlink()


def get_heuristic() -> str:
    a2cps = resources.files("heudiconv_app").joinpath("a2cps.py")
    with resources.as_file(a2cps) as f:
        heuristic = f
    return str(heuristic)


@prefect.task
def exclude_derived_dwi(root: pathlib.Path) -> pathlib.Path:
    TOEXCLUDE = ["DWI_ColFA", "DWI_ADC", "DWI_TRACEW", "DWI_FA", "DWI_TENSOR_B0"]
    for dcm in set(root.glob("**/*dcm")):
        header = pydicom.dcmread(dcm, specific_tags=["SeriesDescription"])
        if (SeriesDescription := header.SeriesDescription) in TOEXCLUDE:
            logging.warning(
                f"excluding file {dcm} with SeriesDescription {SeriesDescription}"
            )
            dcm.unlink()

    return root


def delete_adc(p: pathlib.Path) -> None:
    # For UC, dcm2niix generates extra "ADC" scans, which are derived volumes. They could be
    # avoided by using the -i y flag, except that flag would also cause dcm2niix to skip the anat
    # scans from NS
    adcs = set(p.glob("**/*ADC*"))
    if adcs:
        for adc in adcs:
            logging.warning(f"deleting ADC scan: {adc.name}")
            adc.unlink()


def write_ge_bvals_bvecs(p: pathlib.Path) -> None:
    bval_ = resources.files("heudiconv_app.data").joinpath("bval_GE")
    bvev_ = resources.files("heudiconv_app.data").joinpath("bvec_GE")
    with resources.as_file(bval_) as f:
        bvals = f
    with resources.as_file(bvev_) as f:
        bvecs = f
    # only write if there is a json (e.g., dwi might not have been run)
    for j in p.glob("sub*/ses*/dwi/*dwi.json"):
        j.with_stem(".bval").write_text(bvals.read_text())
        j.with_stem(".bvec").write_text(bvecs.read_text())


def update_permissions(p: pathlib.Path) -> None:
    for f in p.glob("**/*"):
        if f.is_dir():
            f.chmod(stat.S_IRWXU | stat.S_IRWXG)
        if f.is_file():
            f.chmod(stat.S_IRUSR | stat.S_IWUSR | stat.S_IRGRP | stat.S_IWGRP)


@prefect.task
def convert(
    files: pathlib.Path,
    subject: str,
    outdir: pathlib.Path,
    session: str,
    delete_dups: bool = True,
) -> pathlib.Path:

    workflow(
        files=[files],
        subjs=[subject],
        outdir=str(outdir),
        locator="",
        heuristic=get_heuristic(),
        session=session,
        minmeta=True,
        bids_options="--bids",
    )
    update_permissions(outdir)
    site = None
    for sidecar in outdir.glob("sub*/ses*/*/*json"):
        site = check_acq.get_site(sidecar)
        break
    if not site:
        raise AssertionError("unable to deterime site")

    delete_rest_events(outdir)
    delete_adc(outdir)
    add_bidsignore(outdir)
    if delete_dups:
        delete_duplicates(outdir)
    if site == "SH":
        confirm_date(dicomdir=files, bidsdir=outdir)
    if site in ["UM1", "UM2", "UI"]:
        write_ge_bvals_bvecs(outdir)
        utils.create_fieldmaps(outdir)
    if site == "UM2" and "phantom" in subject:
        index_coilqa(outdir)

    utils.edit_json(outdir)

    return outdir


@prefect.task
def validate(p: pathlib.Path) -> None:
    pass


@prefect.flow
def _main(
    zips: tuple[pathlib.Path, ...],
    subjects: tuple[str, ...],
    sessions: tuple[str, ...],
    outdirs: tuple[pathlib.Path, ...],
    delete_dups: bool = True,
    post: bool = False,
):
    for z, subject, session, outdir in zip(zips, subjects, sessions, outdirs):

        extracted = unzip.submit(z)
        extracted2 = exclude_derived_dwi.submit(extracted)

        bids = convert.submit(
            files=extracted2,
            outdir=outdir,
            subject=subject,
            session=session,
            delete_dups=delete_dups,
        )
        checked = check_acq.check_jsons.submit(root=bids, post=post)
        validate.submit(p=checked)


@click.command(context_settings={"ignore_unknown_options": True})
@click.option(
    "--files",
    type=click.Path(
        exists=True,
        file_okay=True,
        dir_okay=False,
        resolve_path=True,
        path_type=pathlib.Path,
    ),
    required=True,
    multiple=True,
)
@click.option(
    "--outdirs",
    type=click.Path(
        exists=False,
        file_okay=False,
        dir_okay=True,
        resolve_path=True,
        path_type=pathlib.Path,
    ),
    required=True,
    multiple=True,
)
@click.option("--subjects", multiple=True, required=True)
@click.option("--sessions", multiple=True, required=True)
@click.option("--delete-dups/--no-delete-dups", default=True)
@click.option("--post/--no-post", default=False)
@click.option("--n-proc", default=1, type=int)
def main(
    files: tuple[pathlib.Path, ...],
    subjects: tuple[str, ...],
    sessions: tuple[str, ...],
    outdirs: tuple[pathlib.Path, ...],
    delete_dups: bool = True,
    post: bool = False,
    n_proc: int = 1,
) -> None:

    assert len(files) == len(subjects)
    assert len(files) == len(sessions)
    assert len(files) == len(outdirs)

    # config.set({"distributed.worker.memory.rebalance.measure": "managed_in_memory"})
    # config.set({"distributed.worker.memory.spill": False})
    # config.set({"distributed.worker.memory.target": False})
    # config.set({"distributed.worker.memory.pause": False})
    # config.set({"distributed.worker.memory.terminate": False})
    # config.set({"distributed.comm.timeouts.connect": "90s"})
    # config.set({"distributed.comm.timeouts.tcp": "90s"})
    # config.set({"distributed.scheduler.worker-ttl": "20m"})

    # _main.with_options(
    #     task_runner=prefect_dask.DaskTaskRunner(
    #         cluster_kwargs={"n_workers": n_proc, "threads_per_worker": 1}
    #     )
    # )(
    _main.with_options(task_runner=task_runners.SequentialTaskRunner)(
        zips=files,
        outdirs=outdirs,
        subjects=subjects,
        sessions=sessions,
        delete_dups=delete_dups,
        post=post,
    )
