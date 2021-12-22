# Generated by: Neurodocker version 0.7.0+0.gdc97516.dirty
# Latest release: Neurodocker version 0.7.0
# Timestamp: 2021/12/22 00:03:58 UTC
# 
# Thank you for using Neurodocker. If you discover any issues
# or ways to improve this software, please submit an issue or
# pull request on our GitHub repository:
# 
#     https://github.com/ReproNim/neurodocker

FROM neurodebian:stretch

USER root

ARG DEBIAN_FRONTEND="noninteractive"

ENV LANG="en_US.UTF-8" \
    LC_ALL="en_US.UTF-8" \
    ND_ENTRYPOINT="/neurodocker/startup.sh"
RUN export ND_ENTRYPOINT="/neurodocker/startup.sh" \
    && apt-get update -qq \
    && apt-get install -y -q --no-install-recommends \
           apt-utils \
           bzip2 \
           ca-certificates \
           curl \
           locales \
           unzip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
    && dpkg-reconfigure --frontend=noninteractive locales \
    && update-locale LANG="en_US.UTF-8" \
    && chmod 777 /opt && chmod a+s /opt \
    && mkdir -p /neurodocker \
    && if [ ! -f "$ND_ENTRYPOINT" ]; then \
         echo '#!/usr/bin/env bash' >> "$ND_ENTRYPOINT" \
    &&   echo 'set -e' >> "$ND_ENTRYPOINT" \
    &&   echo 'export USER="${USER:=`whoami`}"' >> "$ND_ENTRYPOINT" \
    &&   echo 'if [ -n "$1" ]; then "$@"; else /usr/bin/env bash; fi' >> "$ND_ENTRYPOINT"; \
    fi \
    && chmod -R 777 /neurodocker && chmod a+s /neurodocker

ENTRYPOINT ["/neurodocker/startup.sh"]

RUN apt-get update -qq \
    && apt-get install -y -q --no-install-recommends \
           liblzma-dev libc-dev git-annex-standalone netbase \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV PATH="/opt/dcm2niix-003f0d19f1e57b0129c9dcf3e653f51ca3559028/bin:$PATH"
RUN apt-get update -qq \
    && apt-get install -y -q --no-install-recommends \
           cmake \
           g++ \
           gcc \
           git \
           make \
           pigz \
           zlib1g-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && git clone https://github.com/rordenlab/dcm2niix /tmp/dcm2niix \
    && cd /tmp/dcm2niix \
    && git fetch --tags \
    && git checkout 003f0d19f1e57b0129c9dcf3e653f51ca3559028 \
    && mkdir /tmp/dcm2niix/build \
    && cd /tmp/dcm2niix/build \
    && cmake  -DCMAKE_INSTALL_PREFIX:PATH=/opt/dcm2niix-003f0d19f1e57b0129c9dcf3e653f51ca3559028 .. \
    && make \
    && make install \
    && rm -rf /tmp/dcm2niix

RUN git clone https://github.com/rordenlab/dcm2niix /tmp/dcm2niix-UC \
    && cd /tmp/dcm2niix-UC \
    && git fetch --tags \
    && git checkout 06951ec39410625219420ff02f5e3d8c6563d7dd \
    && mkdir /tmp/dcm2niix-UC/build \
    && cd /tmp/dcm2niix-UC/build \
    && cmake .. \
    && make \
    && make install \
    && rm -rf /tmp/dcm2niix-UC

ENV CONDA_DIR="/opt/miniconda-latest" \
    PATH="/opt/miniconda-latest/bin:$PATH"
RUN export PATH="/opt/miniconda-latest/bin:$PATH" \
    && echo "Downloading Miniconda installer ..." \
    && conda_installer="/tmp/miniconda.sh" \
    && curl -fsSL --retry 5 -o "$conda_installer" https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh \
    && bash "$conda_installer" -b -p /opt/miniconda-latest \
    && rm -f "$conda_installer" \
    && conda update -yq -nbase conda \
    && conda config --system --prepend channels conda-forge \
    && conda config --system --set auto_update_conda false \
    && conda config --system --set show_channel_urls true \
    && sync && conda clean -y --all && sync \
    && conda install -y -q --name base \
           "python=3.10" \
           "traits>=4.6" \
           "scipy" \
           "numpy" \
           "pandas" \
           "nomkl" \
           "nilearn" \
           "pydicom" \
           "openpyxl" \
           "deepdiff" \
    && sync && conda clean -y --all && sync \
    && bash -c "source activate base \
    &&   pip install --no-cache-dir  \
             "heudiconv[all]==0.10.0" \
             "pybids"" \
    && rm -rf ~/.cache/pip/* \
    && sync

RUN echo '{ \
    \n  "pkg_manager": "apt", \
    \n  "instructions": [ \
    \n    [ \
    \n      "base", \
    \n      "neurodebian:stretch" \
    \n    ], \
    \n    [ \
    \n      "install", \
    \n      [ \
    \n        "liblzma-dev libc-dev git-annex-standalone netbase" \
    \n      ] \
    \n    ], \
    \n    [ \
    \n      "dcm2niix", \
    \n      { \
    \n        "version": "003f0d19f1e57b0129c9dcf3e653f51ca3559028", \
    \n        "method": "source" \
    \n      } \
    \n    ], \
    \n    [ \
    \n      "miniconda", \
    \n      { \
    \n        "use_env": "base", \
    \n        "conda_install": [ \
    \n          "python=3.10", \
    \n          "traits>=4.6", \
    \n          "scipy", \
    \n          "numpy", \
    \n          "pandas", \
    \n          "nomkl", \
    \n          "nilearn", \
    \n          "pydicom", \
    \n          "openpyxl", \
    \n          "deepdiff" \
    \n        ], \
    \n        "pip_install": [ \
    \n          "heudiconv[all]==0.10.0", \
    \n          "pybids" \
    \n        ] \
    \n      } \
    \n    ] \
    \n  ] \
    \n}' > /neurodocker/neurodocker_specs.json
