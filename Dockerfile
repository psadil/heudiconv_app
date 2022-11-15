FROM mambaorg/micromamba:1.0.0

COPY --chown=$MAMBA_USER:$MAMBA_USER env.yml /tmp/env.yml

ENV MAMBA_DOCKERFILE_ACTIVATE=1 
RUN micromamba install --name base --yes --file /tmp/env.yml  \
    && pip install pybids \
    && rm -f /tmp/env.yml \
    && micromamba clean --yes --all \
    && rm -rf ~/.cache/pip/*

USER root

RUN  git clone https://github.com/rordenlab/dcm2niix /tmp/dcm2niix \
    && cd /tmp/dcm2niix \
    && git fetch --tags \
    && git checkout tags/v1.0.20211006 \
    && mkdir /tmp/dcm2niix/build \
    && cd /tmp/dcm2niix/build \
    && cmake  -DCMAKE_INSTALL_PREFIX:PATH=/opt/dcm2niix-v1.0.20211006 .. \
    && make \
    && make install \
    && rm -rf /tmp/dcm2niix

RUN git clone https://github.com/rordenlab/dcm2niix /tmp/dcm2niix-UC \
    && cd /tmp/dcm2niix-UC \
    && git fetch --tags \
    && git checkout 06951ec39410625219420ff02f5e3d8c6563d7dd \
    && mkdir /tmp/dcm2niix-UC/build \
    && cd /tmp/dcm2niix-UC/build \
    && cmake -DCMAKE_INSTALL_PREFIX:PATH=/opt/dcm2niix-UC .. \
    && make \
    && make install \
    && rm -rf /tmp/dcm2niix-UC

USER $MAMBA_USER