# Pact experiments

Benchmarks and scripts for the evaluation of Pact. Ten hardware designs are written both in Pact and as SystemVerilog (SV) references: FIFO, stream FIFO, spill register, arbiter, ACE cache-coherence controller, TileLink crossbar, and four AXI-Lite routers.

| Experiment | Command | Output |
|---|---|---|
| Compatibility-checking time (Pact) | `make compat` | `results/timing_<time>/comparison.md` |
| Model-checking time (SV, SymbiYosys) | `make modelcheck` | `results/timing_<time>/comparison.md` |
| Area and timing (Pact vs. SV) | `make synthesis` | `results/synthesis_<time>/comparison.md` |
| Cycle-level trace equivalence (Pact vs. SV) | `make equiv` | `results/equiv/` |

Every `comparison.md` lists each value as `expected / measured`. Expected values are stored in `expected/*.json`.

## Requirements

| | |
|---|---|
| CPU | x86-64, 8 or more cores (Pact runs use up to 8 threads; each parallel SymbiYosys run uses 2 processes) |
| Memory | 16 GB (about 4 GB per parallel SymbiYosys run) |
| Disk | 15 GB for the Docker image |
| Software | Docker |

Expected values were measured on 2× AMD EPYC 9115 (32 cores, 64 threads) with 125 GB of memory. Times depend on the machine; verdicts, areas and flip-flop counts do not.

| Experiment | Time on the reference machine |
|---|---|
| `make compat` | about 1.5 h |
| `make modelcheck` | about 35 h of run time in total (30 runs, 13 of them reach the 2 h limit): about 9 h with `SV_JOBS=4`, about 4 h with `SV_JOBS=15` |
| `make synthesis` | about 10 min |
| `make equiv` | a few minutes per benchmark |

## Setup

Build the image (`podman` accepts the same commands as `docker`):

```sh
git clone --recurse-submodules https://github.com/AnvilHDL/Pact-Experiments.git
cd Pact-Experiments
docker build -t pact-experiments .
```

The image clones the Pact compiler into `/artifact/Pact` at the commit given by `PACT_COMMIT` in the `Dockerfile`, and contains OCaml 5.2.0, oss-cad-suite 2026-09-10 (Yosys 0.69+10 with yosys-slang, SymbiYosys, Yices, Verilator 5.053), the sky130 PDK (volare `c6d73a35`), OpenSTA, and the TileLink reference RTL.

All experiments write to `results/` in `/artifact/Pact-Experiments`. Mount a host directory there to keep the results; files in it are given the owner of that directory.

Run one experiment without an interactive session:

```sh
mkdir -p results
docker run --rm -v "$PWD/results:/artifact/Pact-Experiments/results" pact-experiments make compat
docker run --rm -v "$PWD/results:/artifact/Pact-Experiments/results" pact-experiments make all
```

Or open a shell in the container and run the commands below:

```sh
docker run -it --rm -v "$PWD/results:/artifact/Pact-Experiments/results" pact-experiments
```

## Compatibility-checking time

```sh
make compat                                      # all ten benchmarks, about 1.5 h
python3 scripts/run_timing.py --part pact --case fifo --case ace
```

For each benchmark, Pact checks that all members of the benchmark's type pool (`src/compat/type_*.anvil`) are compatible, using the simultaneous product of all members (`-debug-choice 3`). Each check runs with 1 and with 8 threads (`-j`), 5 times; the median is reported (one run when a run exceeds 300 s).

| Column | Meaning |
|---|---|
| Part. | Number of members (participants) in the pool |
| Verdict | Result of the compatibility check: `compatible` or `incompatible` |
| Mode 3, N thr. | Wall-clock time of the check with N threads, in seconds |

## Model-checking time

```sh
make modelcheck SV_JOBS=4                        # 30 runs of up to 2 h each, SV_JOBS in parallel
python3 scripts/run_timing.py --part sv --case arbiter
```

Each SV design runs inside its testbench, which drives every interface. A harness (`formal/comm_safety/sv/`) adds two groups of assertions:

- **Safety (S):** every handshake a participant commits to completes in the same cycle, and both sides of a channel agree on every exchange.
- **Liveness (L):** every started exchange completes within a fixed number of cycles (bounded liveness).

SymbiYosys proves the assertions by k-induction to depth 500 with Yices (`formal/comm_safety/*.sby`). Each benchmark has three runs with a 2 h limit each: S only, L only, and all assertions.

| Result | Meaning |
|---|---|
| proved | k-induction proved the assertions |
| counterexample | the base case found a reachable violation |
| unproved | no violation up to depth 500, but the induction step did not succeed |
| timeout | no result within 2 h |

The time column is the run with all assertions.

## Area and timing

```sh
make synthesis                                   # about 10 min
```

Each Pact benchmark is compiled at `-O 3`. The Pact design modules (testbench processes excluded; a module instantiated several times counts once per instance) and the SV reference design are synthesized with Yosys to `sky130_fd_sc_hd__tt_025C_1v80` cells. OpenSTA reports setup slack at a 10 ns clock (100 MHz) with 1 ns input and output delays.

| Column | Meaning |
|---|---|
| Pact area, SV area | Total cell area in µm² |
| Pact/SV | Area ratio |
| Pact FFs, SV FFs | Number of flip-flops after synthesis |
| Pact setup slack | Worst setup slack in ns; positive means the design meets 100 MHz |

## Trace equivalence

```sh
make equiv                                       # Pact compiled at -O 3; PACT_OPT=2 selects -O 2
```

Each script simulates the Pact design and the SV testbench with Verilator, using matching stimuli, and compares the logged events (cycle number, event, data). `Logical logs match` means both designs produce the same events in the same cycles, so Pact adds no cycle latency for that stimulus; a mismatch exits with a nonzero status and leaves the difference in `logic.diff`. Per-script output directories are listed in `testbench.md`.

## Repository layout

| Path | Contents |
|---|---|
| `src/compat/type_*.anvil` | Pact interface types and compatibility pools |
| `src/compat/test_*.anvil` | Pact process implementations and simulation stimulus |
| `src/testbenches/` | SV reference designs and testbenches |
| `formal/comm_safety/` | SymbiYosys configurations and assertion harnesses |
| `synthesis/`, `scripts/yosys_perf_manifest.json` | Synthesis wrappers and the module list per benchmark |
| `axi`, `common_cells`, `ace`, `tilelink` | Upstream SV sources (git submodules) |
| `expected/` | Expected values for `comparison.md` |
| `scripts/` | Experiment scripts |
