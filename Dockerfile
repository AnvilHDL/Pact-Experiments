# Environment for all experiments: Pact compiler, Yosys/SymbiYosys/Verilator, sky130 PDK, OpenSTA.
# Build from the repository root with submodules checked out:
#   docker build -t pact-experiments .
# Run one experiment, writing to ./results on the host:
#   mkdir -p results
#   docker run --rm -v "$PWD/results:/artifact/Pact-Experiments/results" pact-experiments make compat

FROM docker.io/openroad/opensta@sha256:d5aa34eed86e49a5d36afc2a81961cabb802f0439b472fe07e178289389ae1a0 AS opensta

FROM docker.io/library/ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive
ARG PACT_REPO=https://github.com/AnvilHDL/Pact.git
ARG PACT_COMMIT=2b960bf1a2aa008bd63bdf1f37225e4fa30d20e0
ARG OSS_CAD_SUITE_DATE=2026-09-10
ARG SKY130_VERSION=c6d73a35f524070e85faff4a6a9eef49553ebc2b

RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential ca-certificates curl git m4 make patch pkg-config rsync unzip \
      opam python3 python3-pip python3-venv \
      openjdk-17-jdk-headless \
      tcl8.6 libtcl8.6 tcl-tclreadline libgomp1 zlib1g \
    && rm -rf /var/lib/apt/lists/*

# OCaml toolchain for the Pact compiler.
ENV OPAMROOT=/opt/opam OPAMYES=1
RUN opam init --bare --disable-sandboxing \
    && opam switch create default ocaml-base-compiler.5.2.0 \
    && opam install --switch default dune menhir yojson \
    && opam clean -a
ENV PATH=/opt/opam/default/bin:$PATH

# Yosys, yosys-slang, SymbiYosys, Yices, Verilator.
RUN curl -fsSL "https://github.com/YosysHQ/oss-cad-suite-build/releases/download/${OSS_CAD_SUITE_DATE}/oss-cad-suite-linux-x64-$(echo ${OSS_CAD_SUITE_DATE} | tr -d -).tgz" \
      | tar -xz -C /opt
ENV PATH=/opt/oss-cad-suite/bin:$PATH

# sky130 standard cells.
ENV PDK_ROOT=/opt/pdk
RUN pip3 install --no-cache-dir volare \
    && volare enable --pdk sky130 ${SKY130_VERSION}

# OpenSTA.
COPY --from=opensta /OpenSTA/build/sta /usr/local/bin/sta

# Pact compiler, next to this repository as the scripts expect (../Pact).
RUN git clone ${PACT_REPO} /artifact/Pact \
    && git -C /artifact/Pact checkout ${PACT_COMMIT} \
    && dune build --root /artifact/Pact bin/main.exe

COPY . /artifact/Pact-Experiments
WORKDIR /artifact/Pact-Experiments

# TileLink reference RTL (Chisel; downloads its build tools on first use).
RUN bash scripts/build_tilelink_rtl.sh

ENTRYPOINT ["/artifact/Pact-Experiments/scripts/container_entry.sh"]
CMD ["bash"]
