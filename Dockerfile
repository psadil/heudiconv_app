FROM mambaorg/micromamba:1.0.0

COPY --chown=$MAMBA_USER:$MAMBA_USER env.yml /tmp/env.yml
COPY --chown=$MAMBA_USER:$MAMBA_USER env-v1.0.20211006.yml /tmp/env-v1.0.20211006.yml
COPY --chown=$MAMBA_USER:$MAMBA_USER env-UC.yml /tmp/env-UC.yml

RUN micromamba create --yes --file /tmp/env.yml  \
    && micromamba run -n v1.0.20220720 pip install pybids \
    && micromamba run -n v1.0.20220720 pip install --no-deps git+https://github.com/moloney/dcmstack.git@v0.9 \
    && micromamba create --yes --file /tmp/env-v1.0.20211006.yml \
    && micromamba run -n v1.0.20211006 pip install pybids \
    && micromamba run -n v1.0.20211006 pip install --no-deps git+https://github.com/moloney/dcmstack.git@v0.9 \
    && micromamba create --yes --file /tmp/env-UC.yml \
    && micromamba run -n UC pip install pybids \
    && micromamba run -n UC pip install --no-deps git+https://github.com/moloney/dcmstack.git@v0.9 \
    && rm -f /tmp/env*yml \
    && micromamba clean --yes --all \
    && rm -rf ~/.cache/pip

USER root

RUN  micromamba run -n v1.0.20211006 git clone https://github.com/rordenlab/dcm2niix /tmp/dcm2niix \
    && cd /tmp/dcm2niix \
    && micromamba run -n v1.0.20211006 git fetch --tags \
    && micromamba run -n v1.0.20211006 git checkout tags/v1.0.20211006 \
    && mkdir /tmp/dcm2niix/build \
    && cd /tmp/dcm2niix/build \
    && micromamba run -n v1.0.20211006 cmake  -DCMAKE_INSTALL_PREFIX:PATH=/opt/conda/envs/v1.0.20211006 .. \
    && micromamba run -n v1.0.20211006 make \
    && micromamba run -n v1.0.20211006 make install \ 
    && micromamba run -n UC git checkout 06951ec39410625219420ff02f5e3d8c6563d7dd \
    && micromamba run -n UC cmake  -DCMAKE_INSTALL_PREFIX:PATH=/opt/conda/envs/UC .. \
    && micromamba run -n UC make \
    && micromamba run -n UC make install \
    && rm -rf /tmp/dcm2niix 

USER $MAMBA_USER
