FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# System Dependencies
RUN apt-get update && apt-get install -y \
# Basic Tools
    build-essential \
    gcc \
    g++ \
    make \
    cmake \
    autoconf \
    automake \
    autotools-dev \
    libtool \
    git \
    libmpc-dev \
    libmpfr-dev \
    libgmp-dev \
    zlib1g-dev \
# Required for building toolchains
    bison \
    flex \
    gawk \
    gperf \
    texinfo \
# Other Useful Tools
    curl \
    wget \
    bc \
    patchutils \
    help2man \
    device-tree-compiler \
    libfl-dev \
# Python3 and related tools
    python3 \
    python3-pip \
    python3-venv \
# Misc
    perl \
    ccache \
    libgoogle-perftools-dev \
    numactl \
    perl-doc \
    pkg-config \
    opam \
    bubblewrap \
    bash-completion \
    nano \
    sudo && \
    rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -s /bin/bash -G sudo anvil && \
    echo "anvil ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Create working directory
WORKDIR /workspace/Anvil-Experiments

COPY src/ src/
COPY scripts/ scripts/
COPY run_artefact.py .
COPY README.md .


RUN git clone https://github.com/pulp-platform/axi.git axi && \
    git clone https://github.com/lowRISC/opentitan.git opentitan && \
    git clone https://github.com/openhwgroup/cva6.git cva6_ariane && \
    git clone https://github.com/pulp-platform/common_cells.git common_cells && \
    cd axi && git checkout 5e4bf6cf0c82ec36959b047dc75723fe8711997b && git submodule update --init --recursive && cd .. && \
    cd common_cells && git checkout 1e384c932576267f55ccc4a111e14b33d988e3fd && git submodule update --init --recursive && cd .. && \
    cd cva6_ariane && git checkout 2ef1c1b1fca419354920c5487293bc605294904e && git submodule update --init --recursive && cd .. && \
    cd opentitan && git checkout cf3e35127273247826477c85eeaa2ba2f15c9491 && git submodule update --init --recursive && cd ..

RUN bash scripts/install_verilator.sh

# Python Dependencies
RUN pip3 install --no-cache-dir \
    PyYAML \
    bitstring \
    pyvsc \
    tabulate \
    pandas \
    regex


ENV RISCV=/workspace/Anvil-Experiments/tools/riscv
ENV PATH="${RISCV}/bin:${PATH}"
ENV NUM_JOBS=4

RUN sed -i -e 's+BINUTILS_REPO=.*$+BINUTILS_REPO=https://github.com/bminor/binutils-gdb+' \
    -e 's+NEWLIB_REPO=.*$+NEWLIB_REPO=https://github.com/bminor/newlib+' \
    cva6_ariane/util/toolchain-builder/config/global.sh

RUN set -e && chmod +x scripts/* && \
    ./scripts/setup-cva6.sh --install-deps 2>&1

ENV DV_SIMULATORS=veri-testharness,spike
ENV CVA6_DIR=/workspace/Anvil-Experiments/cva6_ariane
ENV ARTEFACT_ROOT=/workspace/Anvil-Experiments

RUN mkdir -p /workspace/Anvil-Experiments/out


RUN chown -R anvil:anvil /workspace/Anvil-Experiments
USER anvil
ENV HOME=/home/anvil
WORKDIR /home/anvil


RUN git clone https://github.com/jasonyu1996/anvil.git && \
    cd anvil && \
    git checkout d4241cb && \
    opam init --disable-sandboxing -y && \
    opam switch create 5.2.0 ocaml-base-compiler.5.2.0 -y && \
    eval $(opam env) && \
    opam install . --deps-only -y && \
    opam install . -y


ENV PATH="/home/anvil/.opam/5.2.0/bin:${PATH}"


RUN eval $(opam env) && anvil --help


WORKDIR /workspace/Anvil-Experiments


COPY --chown=anvil:anvil container/entrypoint.sh /entrypoint.sh

RUN sudo chmod +x /entrypoint.sh

VOLUME /workspace/Anvil-Experiments/out

ENTRYPOINT ["/entrypoint.sh"]
CMD ["python3", "run_artefact.py"]

