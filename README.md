# PACT Experiment Runbook

This file is the quick entry point for running the different parts of the Anvil/SV case-study experiment: what to run and how. For what each flow actually measures, its per-case behavior, and its findings, see the dedicated docs below rather than this file - pact.md deliberately doesn't duplicate their content.

## Where to find things

There are three independent comparison flows across the same 10 case studies (fifo, stream_fifo, spill_register, arbiter, axi_demux_read, axi_demux_write, axi_mux_read, axi_mux_write, ace, tilelink), plus two smaller standalone metrics collectors. Each flow has its own experiment-setup doc; this file only has run commands.

| Flow | Experiment setup / behavior doc | Findings | Run with |
| --- | --- | --- | --- |
| Cycle equivalence (Verilator vs Anvil compat) | [`testbench.md`](testbench.md) | - | `scripts/run_*_cycle_equiv.sh` |
| Model checking (SymbiYosys k-induction) | [`formal/comm_safety/README.md`](formal/comm_safety/README.md) | same doc | `scripts/run_comm_safety_timing.py` |
| Yosys synthesis (generic-cell proxy + real sky130/OpenSTA) | [`synthesis/README.md`](synthesis/README.md) | [`synthesis/yosys_perf/OVERHEAD_FINDINGS.md`](synthesis/yosys_perf/OVERHEAD_FINDINGS.md), [`synthesis/yosys_perf/WIDTH_FINDINGS.md`](synthesis/yosys_perf/WIDTH_FINDINGS.md) | `scripts/collect_yosys_perf.py`, `scripts/collect_real_synth_perf.py` |
| State-space estimate (SV only) | below | - | `scripts/collect_state_space.py` |
| Code size / assertion / signature-size comparison | below | - | `scripts/collect_code_size.py` |

## Prerequisites

Run commands from the repository root:

```sh
cd /home/aditya/Workspace/Anvil-Experiments
```

Expected tools on `PATH`:

- `anvil`
- `verilator`
- `yosys` with the `slang` plugin
- `sby` for SymbiYosys checks
- `ebmc` for optional EBMC proof runs
- `make`, `python3`

Most generated artifacts are intentionally ignored under:

```text
formal/comm_safety/results/
synthesis_reports/yosys_perf_results/
synthesis_reports/real_synth_perf_results/
```

**All 5 collection scripts** (`run_comm_safety_timing.py`, `collect_state_space.py`, `collect_code_size.py`, `collect_yosys_perf.py`, `collect_real_synth_perf.py`) **write into a new timestamped subdirectory by default, never overwriting a previous run's results** - e.g. `formal/comm_safety/results/20260709_121220/` or `synthesis_reports/yosys_perf_results/20260709_121336/`. Each prints its own `Results directory: ...` line at startup so you always know where a given run's output landed. Pass `--results-dir <path>` (or `--csv <path>` for `collect_code_size.py`) to force a specific location instead - useful for re-running into a known directory, or for scripting that expects a stable path.

`collect_real_synth_perf.py` reads Anvil's already-generated SV from `collect_yosys_perf.py`'s own output rather than re-deriving codegen. By default it auto-discovers the **most recently created** timestamped run under `synthesis_reports/yosys_perf_results/` and reads that run's `generated/` subfolder - so the usual two-step workflow is: run `collect_yosys_perf.py` once for the cases you need, then run `collect_real_synth_perf.py` and it picks up that same run automatically (also printed at startup: `Reading generated SV from: ...`). Pass `--generated-dir <path>` to point at a specific run instead (e.g. if you've run `collect_yosys_perf.py` multiple times and want an older one).

## Cycle Equivalence

These scripts run the SV testbench and the matching Anvil compat test back to back, then compare cycle-level behavior. See [`testbench.md`](testbench.md) for what each case's stimulus does, the shared run-script mechanics (normalization/diffing, output layout), and the submodule source-reproducibility fix applied to the 6 scripts that build from `axi/`/`ace`/`tilelink/`.

Run all common-cell cases:

```sh
./scripts/run_common_cells_cycle_equiv.sh
```

Run individual larger cases:

```sh
./scripts/run_axi_demux_read_cycle_equiv.sh
./scripts/run_axi_demux_write_cycle_equiv.sh
./scripts/run_axi_mux_read_cycle_equiv.sh
./scripts/run_axi_mux_write_cycle_equiv.sh
./scripts/run_ace_cycle_equiv.sh
./scripts/run_tilelink_cycle_equiv.sh
```

The Anvil side of these scripts uses files in:

```text
src/compat/
```

## Direct Anvil Compat Runs

Use `run_compat.py` for type/compat timing across Anvil files. Mode is the compiler's `-debug-choice`: `2` = `generalized_type_debug`, `3` = `generalized_type_v2_debug`, `4` = `open_compatibility_v2_debug` - these are different compatibility-checking algorithms, not different strictness levels of the same one, and can disagree on the same file (`type_fifo.anvil` reports `Compatible` under mode 2 but `Incompatible` under mode 4). Use mode `2` unless you specifically need one of the others.

Default comparison mode:

```sh
python3 run_compat.py 2
```

Run selected files only:

```sh
python3 run_compat.py 2 --only type_fifo.anvil,type_stream_fifo.anvil,type_arbiter.anvil
```

Write a timing CSV:

```sh
python3 run_compat.py 2 --csv formal/comm_safety/results/anvil_compat.csv
```

Direct single-test Anvil type/session check:

```sh
./run_anvil -jc src/compat/test_tilelink.anvil
```

For the original compat Makefile flow, run from `src/compat`:

```sh
cd src/compat
make run MODULE_NAME=test_ace LTOFF=1 COMPAT=1
```

## Communication Safety And Liveness

The communication-safety work is under `formal/comm_safety/`. See [`formal/comm_safety/README.md`](formal/comm_safety/README.md) for the full picture: `mode prove`/k-induction semantics, the per-case status table (depth, active assertion/assume counts, harness module), full safety-coverage descriptions per case, and the two root-caused findings behind why `axi_demux_write` and `tilelink` currently run with some assertions commented out (a harness-modeling gap in one case, a genuine vendored-submodule stub bug in the other - both explained there with the full counterexample chain).

The timing driver runs model checking and Anvil compat timing in one command.

Short phase:

```sh
python3 scripts/run_comm_safety_timing.py --phase short --mode 2
```

Big phase:

```sh
python3 scripts/run_comm_safety_timing.py --phase big --mode 2
```

All cases:

```sh
python3 scripts/run_comm_safety_timing.py --phase all --mode 2
```

Run only selected cases:

```sh
python3 scripts/run_comm_safety_timing.py --case fifo --case axi_demux_read --mode 2
```

Use EBMC instead of SymbiYosys, or both:

```sh
python3 scripts/run_comm_safety_timing.py --phase short --checker ebmc
python3 scripts/run_comm_safety_timing.py --phase short --checker both
```

Set up SBY workdirs without running the full checker:

```sh
python3 scripts/run_comm_safety_timing.py --phase short --setup-only
```

Run cases in parallel (one OS process/thread per case; each case's own sby/ebmc/anvil steps still run sequentially within that case) with a per-subprocess wall-clock timeout:

```sh
python3 scripts/run_comm_safety_timing.py --phase all --mode 2 --jobs 10 --timeout 3600
```

`--jobs` defaults to 1 (sequential, original behavior) - raise it to run that many cases concurrently; there are 10 total cases (5 short + 5 big), so `--jobs 10` runs every selected case at once. `--timeout` (seconds) is applied independently to each of a case's sby/ebmc/anvil subprocess calls (not shared across a case) - a killed subprocess is reported as `EXTERNAL_TIMEOUT` in `timing.csv`, and this is distinct from SBY's own internal `TIMEOUT` status (rc=8) if SBY times out on its own before the external timeout fires. Without `--timeout`, every case runs to completion with no cap - pick a `--timeout` up front rather than guessing, since `mode prove`'s induction step can run for a very long time on larger cases (e.g. `type_arbiter.anvil`'s own Anvil-side mode-4 compat check alone was observed to exceed 90s with no output).

Direct SBY run for one case:

```sh
sby -f formal/comm_safety/fifo.sby
```

Outputs:

```text
formal/comm_safety/results/<case>.log
formal/comm_safety/results/<case>.anvil.log
formal/comm_safety/results/<case>.anvil.csv
formal/comm_safety/results/timing.csv
formal/comm_safety/results/sby_<case>/
```

`timing.csv` includes `kinduction_depth`, `harness_module`, `harness_lines`, `harness_asserts`, `harness_assumes` alongside the pass/fail/timing columns - the same assertion/assume counts and depth bound documented in `formal/comm_safety/README.md`'s per-case status table, so a single run's CSV is self-describing without cross-referencing that doc.

## Yosys Performance Collection

The performance collection flow compares Anvil-generated core modules against SV core components using Yosys synthesis statistics. See [`synthesis/README.md`](synthesis/README.md) for the experiment setup - which modules are synthesized by default per case (`anvil_core_patterns`/`sv_top`/`sv_files` in the manifest), how the default-vs-`--include-neighbors` module selection works, and the `perf_sv_wrappers.sv` wrapper each case builds against. For results and root-caused overhead sources, see `synthesis/yosys_perf/OVERHEAD_FINDINGS.md` and `WIDTH_FINDINGS.md`.

`collect_yosys_perf.py` reports Yosys's generic-cell counts as a cell/area proxy, not real activity-based power. `collect_real_synth_perf.py` layers real sky130 synthesis and OpenSTA static timing/power on top of `collect_yosys_perf.py`'s already-generated SV (see Prerequisites above for how it auto-discovers which run to read).

Smoke test:

```sh
python3 scripts/collect_yosys_perf.py --case fifo --variant both --strict
```

Short phase:

```sh
python3 scripts/collect_yosys_perf.py --phase short --variant both
```

Big phase:

```sh
python3 scripts/collect_yosys_perf.py --phase big --variant both
```

All cases:

```sh
python3 scripts/collect_yosys_perf.py --phase all --variant both
```

Selected case and variant:

```sh
python3 scripts/collect_yosys_perf.py --case tilelink --variant both
python3 scripts/collect_yosys_perf.py --case ace --variant sv
```

Include normally ignored test actors/neighbors:

```sh
python3 scripts/collect_yosys_perf.py --phase short --include-neighbors
```

Use a longer timeout for slow Anvil codegen:

```sh
python3 scripts/collect_yosys_perf.py --phase big --variant both --timeout-seconds 240
```

Outputs:

```text
synthesis_reports/yosys_perf_results/generated/<case>/
synthesis_reports/yosys_perf_results/logs/<case>/<variant>/
synthesis_reports/yosys_perf_results/json/<case>/<variant>/
synthesis_reports/yosys_perf_results/summary.csv
synthesis_reports/yosys_perf_results/summary.json
synthesis_reports/yosys_perf_results/summary.md
```

The manifest for case mappings and ignored-neighbor patterns is:

```text
scripts/yosys_perf_manifest.json
```

Real sky130 synthesis + OpenSTA timing/power, reading a `collect_yosys_perf.py` run's already-generated SV (defaults to the most recent timestamped run - see Prerequisites):

```sh
python3 scripts/collect_real_synth_perf.py --case fifo --variant both
python3 scripts/collect_real_synth_perf.py --variant both
python3 scripts/collect_real_synth_perf.py --generated-dir synthesis_reports/yosys_perf_results/20260709_121336/generated --variant both
```

## State-Space Estimate (SV only)

Naive state-space estimate (`2**seq_cells`, memory bits tracked and reported separately, excluded from the exponent) for the SV side of the same full-test scope used for model checking (each case's own `.sby` top module and file list - DUT plus its driver/harness wiring, not just the isolated core component `collect_yosys_perf.py` measures).

```sh
python3 scripts/collect_state_space.py
python3 scripts/collect_state_space.py --case fifo --case arbiter
```

These full-test tops have no data outputs (only `clk_i`/`rst_ni`), so a normal `synth -flatten` recipe would delete the whole design as unreachable dead logic. The script uses a lighter recipe instead (`hierarchy` → `flatten` → `setattr -set keep 1 w:*` → `proc` → `opt_clean` → `stat -json`) that forces every wire observable before running just enough passes to turn always-blocks into real `$dff`/`$mem` cells, without synth's full reachability-based optimization.

Outputs:

```text
formal/comm_safety/results/state_space/state_space.csv
formal/comm_safety/results/state_space/logs/<case>/sv.log
```

The script derives its file list and defines directly from each case's own `.sby` `read_slang` command line (it doesn't maintain a separate file list), so it inherits whatever that `.sby` already has correct: `axi_mux_read.sby`/`axi_mux_write.sby` already include `common_cells/src/cf_math_pkg.sv`, and `ace.sby` already passes `-D FORMAL_COMM_SAFETY`, which guards `ace/src/ccu_fsm_tb.sv`'s simulation-only `$finish` behind an `` `ifndef FORMAL_COMM_SAFETY `` block - both were real gaps at some earlier point, fixed in the `.sby` files/testbench itself rather than in this script, and this script picks up both fixes automatically since it reads those files' current content, not a cached copy.

## Lines of Code / Assertion / Signature-Size Comparison

Compares implementation size and (Anvil-only) session-type signature size against SV lines-of-code and the comm-safety formal harness/assertion size for that case.

```sh
python3 scripts/collect_code_size.py
python3 scripts/collect_code_size.py --case fifo --case tilelink
```

Per case, collects:
- Anvil: lines of code of the full `test_<case>.anvil` implementation, plus the line/character length of the DUT's own `interface(...) = <session type>` declaration (read from `type_<case>.anvil`, since `test_*.anvil` has no `interface` declarations of its own - only `proc` bodies implementing interfaces declared elsewhere).
- SV: lines of code of the DUT file only (`src/testbenches/`, not the `axi/`/`ace/`/`tilelink/` submodule copies), plus the line count and `assert`/`assume` count of that case's `module comm_<case>_formal ... endmodule` block in `formal/comm_safety/sv/{comm_safety_common,comm_safety_tb_wrappers}.sv` (the formal verification harness/assertion code, not the DUT itself).

No SV "type signature" is collected - SV has no session-type equivalent, so that column is Anvil-only by design.

Outputs:

```text
formal/comm_safety/results/code_size.csv
```

## Phase Split

Short cases:

```text
fifo
spill_register
stream_fifo
arbiter
axi_demux_read
```

Big cases:

```text
axi_demux_write
axi_mux_read
axi_mux_write
ace
tilelink
```

## Useful Cleanup

Most result files are ignored. To manually remove generated reports:

```sh
rm -rf formal/comm_safety/results synthesis_reports/yosys_perf_results synthesis_reports/real_synth_perf_results
```

Use the cleanup command only when you do not need the current logs or summaries.
