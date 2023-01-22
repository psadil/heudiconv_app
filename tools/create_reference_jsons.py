from pathlib import Path

from nifti_models import models

from heudiconv_app.check_acq import get_reference_stem

outdir = Path(__file__).parent.parent / "src" / "heudiconv_app" / "data"
src = Path("/corral-secure/projects/A2CPS/products/mris")
# root = Path(__file__).parent / "bids"

# for sidecar in root.glob("*json"):
#     m = models.MRIMeta.from_sidecarpath(sidecar)
#     stem = get_reference_stem(sidecar)
#     (outdir / stem).with_suffix(".json").write_text(m.json(indent=2))


REFS = {
    "UC": {"subid": "UC10513V1", "site": "UC_uchicago"},
    "UI": {"subid": "UI10421V3", "site": "UI_uic"},
    "NS": {"subid": "NS10434V3", "site": "NS_northshore"},
    "SH": {
        "subid": "SH20198V1",
        "site": "SH_spectrum_health",
    },
    "UM1": {"subid": "UM20067V1", "site": "UM_umichigan"},
    "UM2": {"subid": "UM20078V3", "site": "UM_umichigan"},
    "WS": {"subid": "WS25051V1", "site": "WS_wayne_state"},
    "UCphantom": {
        "subid": "QC_UC111122QA",
        "site": "UC_uchicago",
    },
    "UIphantom": {
        "subid": "QC_UI111822QA",
        "site": "UI_uic",
    },
    "NSphantom": {
        "subid": "QC_NS110722QA",
        "site": "NS_northshore",
    },
    "SHphantom": {
        "subid": "QC_SH20221027QA",
        "site": "SH_spectrum_health",
    },
    "WSphantom": {
        "subid": "QC_WS111722QA",
        "site": "WS_wayne_state",
    },
}

for value in REFS.values():
    value.update({"src": src})  # type: ignore

for value in REFS.values():
    for sidecar in (value.get("src") / value["site"] / "bids" / value["subid"]).glob(  # type: ignore
        "sub*/ses*/*/*json"
    ):
        m = models.MRIMeta.from_sidecarpath(sidecar)
        stem = get_reference_stem(sidecar)
        if "run-02" in stem:
            continue
        (outdir / stem).with_suffix(".json").write_text(
            m.json(indent=2, exclude_unset=True)
        )
