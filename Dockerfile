FROM bids/validator:v1.9.9 AS validator

FROM mambaorg/micromamba:1.0.0

COPY --from=validator /src/bids-validator /opt/bids-validator
COPY --chown=$MAMBA_USER:$MAMBA_USER env.yml /tmp/env.yml

ENV MAMBA_DOCKERFILE_ACTIVATE=1 
RUN micromamba install --name base --yes --file /tmp/env.yml  \
    && pip install pybids \ 
    && pip install --no-deps git+https://github.com/moloney/dcmstack.git@v0.9 \
    && rm -rf ~/.cache/pip \
    && rm -f /tmp/env*yml \
    && micromamba clean --yes --all 
