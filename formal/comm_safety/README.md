# Model checking of the SV designs

Each `<benchmark>.sby` checks one SV design inside its testbench (`src/testbenches/`), which drives every interface. The harness modules in `sv/` read the handshake signals and add two groups of assertions:

- `COMM_S_ASSERT` (safety): every handshake a participant commits to completes in the same cycle, and both sides of a channel agree on every exchange.
- `COMM_L_ASSERT` (bounded liveness): every started exchange completes within a fixed number of cycles; the bound is a parameter of each harness.

Defining `COMM_ONLY_S` or `COMM_ONLY_L` keeps only one group. SymbiYosys runs `mode prove` (k-induction, depth 500) with the `smtbmc` engine and Yices. Payload values are not checked.

`scripts/run_timing.py --part sv` (`make modelcheck`) runs every configuration three times (all assertions, `COMM_ONLY_S`, `COMM_ONLY_L`) with a 2 h limit per run and writes `results/timing_<time>/comparison.md`. SymbiYosys work directories, logs and counterexample traces are kept under `results/timing_<time>/sby/`.

| Status | Meaning |
|---|---|
| proved | k-induction proved the assertions |
| counterexample | the base case found a reachable violation (`engine_0/trace.vcd`) |
| unproved | no violation up to depth 500; the induction step did not succeed |
| timeout | no result within the limit |

Run one configuration directly:

```sh
sby -f formal/comm_safety/fifo.sby
```

TileLink requires `bash scripts/build_tilelink_rtl.sh` first.
