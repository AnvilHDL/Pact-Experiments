# PACT benchmarks

This repository contains PACT protocol models, executable PACT processes, and
SystemVerilog references for ten hardware case studies: FIFO, stream FIFO, spill
register, arbiter, four AXI-Lite routers, ACE, and TileLink.

## Setup

Place the compiler and benchmarks beside each other:

```sh
git clone https://github.com/arj4web/Pact.git Pact
git clone https://github.com/project-starch/Anvil-Experiments.git PACT-Experiments
cd PACT-Experiments
git submodule update --init axi common_cells ace tilelink
```

Use the compiler revision recorded with the experiment being reproduced.
The compiler requires OCaml 4.14 or newer, Dune 3.20 or newer, Menhir, and Yojson.
Install its dependencies in an active opam switch, then build:

```sh
opam install ../Pact --deps-only
eval "$(opam env)"
dune build --root ../Pact @install
```

Scripts use `../Pact` by default. Set `PACT_DIR` to use another checkout.
Python 3.10 or newer runs the benchmark tools. Simulation also needs Make,
a C++ compiler, and Verilator 5 with timing support. TileLink generation needs
JDK 17 or newer; [its generator](src/tilelink_generator/README.md) downloads
pinned Mill, Scala, and Chisel dependencies on the first run.

## Run

Run these commands from the repository root:

```sh
make check                      # Session type-check every benchmark
make compat MODE=3 JOBS=4        # Check protocol pools concurrently
make equiv                      # Compare all ten simulation traces with RTL
```

Type checking checks each process against its interfaces. Compatibility checks
whether the interfaces can execute together. These are separate checks.
Cycle equivalence compares the supplied process and RTL stimuli at exact cycle
numbers; it does not prove equivalence for every possible input.

For individual cases:

```sh
./run_pact -jc src/compat/test_demux_read.anvil
python3 run_compat.py 3 --only type_demux_read_2p,type_mux_read_simplified_2p --jobs 2
bash scripts/run_axi_demux_read_cycle_equiv.sh
```

Compatibility modes:

| Mode | Construction |
| --- | --- |
| `2` | Fast closed-product checker |
| `3` | Simultaneous product of all pool members |
| `4` | Pairwise composition with the successful residual passed to the next member |

Compatibility logs and incremental `results.csv` files are written under
`logs/compat/<run>/`. A running check has no verdict until it finishes.
Type-check logs are under `logs/typecheck/<run>/`.

## Other measurements

- [Cycle-equivalence scripts and outputs](testbench.md)
- [RTL formal checks and compatibility timing](formal/comm_safety/README.md)
- [Synthesis, state-space estimates, and code-size measurements](synthesis/README.md)
- [Protocol and process sources](src/compat/README.md)

RTL references are tracked in `src/testbenches/`; upstream dependencies are
pinned by the submodule revisions.

Record both repository revisions, local changes, submodule revisions, tool
versions, commands, and result directories with each measurement:

```sh
git rev-parse HEAD
git diff HEAD
git submodule status
git -C ../Pact rev-parse HEAD
git -C ../Pact diff HEAD
verilator --version
python3 --version
dune --version
```

Generated RTL, build objects, and run outputs are ignored by Git. Keep the
reported output directories when comparing measurements.
