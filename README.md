# Pact experiments

Benchmarks and scripts for the evaluation of Pact. Ten hardware designs are written both in Pact and as SystemVerilog (SV) references: FIFO, stream FIFO, spill register, arbiter, ACE cache-coherence controller, TileLink crossbar, and four AXI-Lite routers.

| Experiment | Command | Output |
|---|---|---|
| Compatibility-checking time (Pact) | `make compat` | `results/timing_<time>/comparison.md` |
| Model-checking time (SV, SymbiYosys) | `make modelcheck` | `results/timing_<time>/comparison.md` |
| Area and timing (Pact vs. SV) | `make synthesis` | `results/synthesis_<time>/comparison.md` |
| Cycle-level trace equivalence (Pact vs. SV) | `make equiv` | `results/equiv/` |
| Real-world AXI communication errors (Pact) | `make opencompat` | `results/opencompat_<time>/comparison.md` |

Every `comparison.md` lists each value as `expected / measured`. Expected values are stored in `expected/*.json`.

> **Note** The results below are revised from the submitted version of the paper, and improve on it: generated circuits are smaller, and compatibility checks are faster. The compiler optimizations behind them are described in [OPTIMIZATIONS.md](OPTIMIZATIONS.md).

## Main results

> For artifact reviewers, [updates](result-updates.md) summarizes the compiler optimizations that improve on the results reported in the paper.

The values below are the expected values in `expected/*.json`, measured on the reference machine described under [Requirements](#requirements).

### Checking communication safety

Pact checks the pool of each benchmark for compatibility (`make compat`). SymbiYosys checks the SV design against the safety (S) and liveness (L) assertions (`make modelcheck`). Times are wall-clock seconds. Each SymbiYosys run uses two processes, one for the base case and one for the induction step, so the Pact 1-thread column is the closest comparison.

| Benchmark | Part. | Pact verdict | Pact, 1 thr. (s) | Pact, 8 thr. (s) | SymbiYosys, S + L | SymbiYosys, S only | SymbiYosys, L only |
| --- | ---: | --- | ---: | ---: | --- | --- | --- |
| FIFO | 3 | compatible | 0.007 | 0.015 | proved, 3355 | proved, 6470 | proved, 2026 |
| Stream FIFO | 3 | compatible | 0.007 | 0.015 | timeout | timeout | timeout |
| Spill register | 3 | compatible | 0.015 | 0.015 | timeout | timeout | timeout |
| Arbiter | 6 | compatible | 0.114 | 0.064 | proved, 3307 | proved, 27.3 | proved, 3149 |
| ACE | 9 | compatible | 127 | 20.6 | timeout | unproved, 3825 | timeout |
| TileLink | 10 | compatible | 8.0 | 1.3 | proved, 2839 | proved, 2862 | proved, 2143 |
| AXI demux, read | 8 | compatible | 30.3 | 5.2 | unproved, 314 | unproved, 109 | unproved, 3138 |
| AXI demux, write | 10 | compatible | 564 | 85.8 | unproved, 516 | unproved, 79.2 | timeout |
| AXI mux, read | 9 | compatible | 109 | 16.6 | timeout | unproved, 249 | timeout |
| AXI mux, write | 11 | compatible | 1188 | 173 | timeout | unproved, 515 | timeout |

Every Pact check finishes with a verdict: the longest takes 20 min on one thread and 3 min on eight. SymbiYosys proves both groups of assertions for 3 of the 10 designs. For the others, a run either reaches the 2 h limit or ends unproved; the status words are defined under [Model-checking time](#model-checking-time).

### Area and timing

Pact designs are compiled at `-O 3` and synthesized with the SV references to sky130 cells (`make synthesis`). Slack is the worst setup slack at 100 MHz.

| Benchmark | Pact area (µm²) | SV area (µm²) | Pact/SV | Pact FFs | SV FFs | Pact slack (ns) | SV slack (ns) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| FIFO | 11,658.7 | 11,616.1 | 1.00 | 270 | 266 | 4.65 | 4.80 |
| Stream FIFO | 11,671.2 | 11,486.0 | 1.02 | 270 | 264 | 4.52 | 4.76 |
| Spill register | 3,363.2 | 2,770.2 | 1.21 | 72 | 66 | 5.28 | 6.01 |
| Arbiter | 1,044.8 | 1,386.3 | 0.75 | 7 | 7 | 4.85 | 4.93 |
| ACE | 4,792.1 | 8,423.1 | 0.57 | 106 | 173 | 6.79 | 6.12 |
| TileLink | 1,941.9 | 2,279.7 | 0.85 | 14 | 20 | 6.80 | 5.04 |
| AXI demux, read | 2,947.8 | 1,978.1 | 1.49 | 46 | 26 | 4.13 | 6.13 |
| AXI demux, write | 4,461.8 | 2,726.4 | 1.64 | 86 | 53 | 5.72 | 6.80 |
| AXI mux, read | 3,489.6 | 2,602.5 | 1.34 | 52 | 33 | 4.34 | 4.70 |
| AXI mux, write | 6,035.8 | 4,216.5 | 1.43 | 89 | 60 | 4.38 | 5.91 |

The geometric-mean area ratio is 1.08, and every design meets 100 MHz.

### Trace equivalence

Each of the ten Pact designs produces the same events, in the same cycles, as its SV reference on the supplied stimuli (`make equiv`).

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
| `make opencompat` | a few seconds |

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
| `opencompat/` | Real-world AXI communication-error cases ([README](opencompat/README.md)) |
| `expected/` | Expected values for `comparison.md` |
| `OPTIMIZATIONS.md` | Compiler optimizations used for these results |
| `scripts/` | Experiment scripts |
