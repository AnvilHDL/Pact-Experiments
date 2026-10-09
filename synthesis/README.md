# Synthesis

`scripts/run_synthesis.py` (`make synthesis`) runs two steps and writes `results/synthesis_<time>/comparison.md`.

1. `scripts/collect_yosys_perf.py` compiles each Pact benchmark (`src/compat/test_*.anvil`) at `-O 3` and selects the design modules listed in `scripts/yosys_perf_manifest.json`. Testbench processes are excluded; a module instantiated several times is counted once per instance. The SV side is the wrapper in `yosys_perf/perf_sv_wrappers.sv` (the generated `TLCrossBar` for TileLink).
2. `scripts/collect_real_synth_perf.py` maps both sides to `sky130_fd_sc_hd__tt_025C_1v80` cells with Yosys and runs OpenSTA with a 10 ns clock and 1 ns input and output delays. It uses the `sta` binary on `PATH`; with `--sta-bin ''` it runs OpenSTA in a container (`--podman-bin`, `--sta-image`).

Both sides use the same data widths. The AXI routers use 8-entry FIFOs on both sides (`MaxTrans = 8` in SV). ACE has 3 caches on both sides. TileLink implements every field of the A and D channels with 16-bit data and single-beat transfers.

Output: `results/synthesis_<time>/yosys/` (generated SV, generic synthesis) and `results/synthesis_<time>/cells/` (netlists, Yosys and OpenSTA logs, `summary.csv`, with one row per module and one aggregate row per benchmark and side).

Other collectors:

| Script | Output |
|---|---|
| `scripts/collect_state_space.py` | Flip-flop count of each design, as `2^n` |
| `scripts/collect_code_size.py` | Lines of process source, interface sizes, harness assertion counts |
