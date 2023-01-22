FROM bids/validator:v1.9.9 AS validator

FROM mambaorg/micromamba:1.2.0-jammy

COPY --from=validator /src/bids-validator /opt/bids-validator
COPY --chown=$MAMBA_USER:$MAMBA_USER env.yml /tmp/env.yml

ENV MAMBA_DOCKERFILE_ACTIVATE=1 
RUN micromamba install --name base --yes --file /tmp/env.yml  \
    && pip install pybids nipype \ 
    && git clone https://github.com/rordenlab/dcm2niix /tmp/dcm2niix \
    && cd /tmp/dcm2niix/console \
    && make \
    && cp ./dcm2niix /opt/conda/bin \
    && pip install --no-deps git+https://github.com/moloney/dcmstack.git@v0.9 \
    && pip install --no-deps git+https://github.com/nipy/heudiconv.git@v0.10.0 \
    && rm -rf ~/.cache/pip \
    && rm -f /tmp/env*yml \
    && micromamba clean --yes --all 
