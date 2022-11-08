# Generated by: Neurodocker version 0.7.0+0.gdc97516.dirty
# Latest release: Neurodocker version 0.7.0
# Timestamp: 2021/12/29 21:49:59 UTC
# 
# Thank you for using Neurodocker. If you discover any issues
# or ways to improve this software, please submit an issue or
# pull request on our GitHub repository:
# 
#     https://github.com/ReproNim/neurodocker

FROM mambaorg/micromamba:1.0.0

COPY --chown=$MAMBA_USER:$MAMBA_USER env.yml /tmp/env.yml

ENV MAMBA_DOCKERFILE_ACTIVATE=1 
RUN micromamba install --name base --yes --file /tmp/env.yml  \
    && pip install pybids git+https://github.com/moloney/dcmstack@v0.9 \
    && rm -f /tmp/env.yml \
    && micromamba clean --yes --all
