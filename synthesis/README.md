# Yosys Synthesis Case Studies

Experiment setup for the Yosys-synthesis comparison: what gets synthesized by default for each of the 10 case studies, driven by `scripts/yosys_perf_manifest.json` and run by `scripts/collect_yosys_perf.py` (generic-cell proxy metrics) and `scripts/collect_real_synth_perf.py` (real sky130 + OpenSTA area/timing/power, layered on top of the same generated SV).

For the overhead investigation and findings from these measurements, see [`yosys_perf/OVERHEAD_FINDINGS.md`](yosys_perf/OVERHEAD_FINDINGS.md) and [`yosys_perf/WIDTH_FINDINGS.md`](yosys_perf/WIDTH_FINDINGS.md). This file only documents the experiment setup - which components are synthesized, and why - not the results.

**Reproducibility note**: this whole directory (including `yosys_perf/perf_sv_wrappers.sv`, the hand-authored SV wrapper 9 of the 10 cases below build against) was previously matched by a blanket `/synthesis/` rule in `.gitignore`, added in the same commit as the genuinely-generated-output ignores for `synthesis_reports/`. Unlike those, nothing under `synthesis/` is generated - it's all hand-authored source and docs - so the rule was an overgeneralization that would have silently dropped `perf_sv_wrappers.sv` from a fresh clone. Removed as part of this pass; the directory is tracked from here on.

## How default component selection works

Both scripts read the same manifest (`scripts/yosys_perf_manifest.json`): a `defaults` block plus a `cases` list, one entry per case study.

**Anvil side**: for a case, Anvil codegen produces one `.sv` file containing every module in that test's process graph - not just the DUT, but also driver/testbench-style processes (masters, slaves, clients, managers, the memory controller, top-level `test_*` wrappers). `discover_modules()` scans that generated file for every `module ... endmodule` declaration, then each module is classified:

- **Core** if its name matches one of the case's own `anvil_core_patterns` regexes.
- **Ignored** if its name matches one of the shared `defaults.anvil_ignore_patterns` regexes (`^test_.*`, `.*_master.*`, `.*_slave.*`, `^master.*`, `^slave.*`, `^client_.*`, `^manager_.*`, `^cache_client_.*`, `^mem_controller$`).

**By default, only modules matching `anvil_core_patterns` are synthesized** - each core module is extracted into its own isolated `module ... endmodule` file (so unrelated driver code elsewhere in the same generated `.sv` can't fail synthesis on its own syntax/semantics, a real tooling artifact hit and fixed during this investigation, documented in `WIDTH_FINDINGS.md`) and synthesized standalone. Passing `--include-neighbors` on either collection script additionally synthesizes every ignore-pattern-matching module too (tagged separately from the core modules in the output), for a broader view that includes the driver/testbench-side cost - this is off unless explicitly requested.

**SV side**: only `sv_top` (built from `sv_files`) is synthesized by default. The manifest supports a per-case `sv_neighbor_tops` list for the same kind of opt-in broader comparison as the Anvil side's `--include-neighbors`, but no case in the current manifest defines one, so it's an available-but-unused hook today, not part of any default run.

`defaults.include_dirs` (`common_cells/include`, `axi/include`, `ace/include`) and `defaults.defines` (`COMMON_CELLS_ASSERTS_OFF`) apply to every case's Yosys invocation. `defaults.sv_ignore_patterns` is declared in the manifest but not read by either collection script - it has no effect today; if SV-side neighbor filtering is ever wired up, this is presumably where it was meant to plug in.

## Per-case setup

| Case | Phase | Anvil `anvil_core_patterns` (synthesized by default) | SV `sv_top` | SV `sv_files` |
| --- | --- | --- | --- | --- |
| `fifo` | short | `^fifo_0$` | `perf_fifo_sv` | `common_cells/src/fifo_v3.sv`, `axi/src/axi_pkg.sv`, `synthesis/yosys_perf/perf_sv_wrappers.sv` |
| `stream_fifo` | short | `^stream_fifo_0$` | `perf_stream_fifo_sv` | `common_cells/src/passthrough_stream_fifo.sv`, `axi/src/axi_pkg.sv`, `synthesis/yosys_perf/perf_sv_wrappers.sv` |
| `spill_register` | short | `^spill_reg_0$` | `perf_spill_register_sv` | `common_cells/src/spill_register_flushable.sv`, `common_cells/src/spill_register.sv`, `axi/src/axi_pkg.sv`, `synthesis/yosys_perf/perf_sv_wrappers.sv` |
| `arbiter` | short | `^arbiter_0$` | `perf_arbiter_sv` | `common_cells/src/cf_math_pkg.sv`, `common_cells/src/lzc.sv`, `common_cells/src/rr_arb_tree.sv`, `axi/src/axi_pkg.sv`, `synthesis/yosys_perf/perf_sv_wrappers.sv` |
| `axi_demux_read` | short | `^demux_ar_main$`, `^demux_r_main$`, `^fifo_.*` | `perf_axi_demux_read_sv` | `common_cells/src/spill_register_flushable.sv`, `common_cells/src/spill_register.sv`, `common_cells/src/fifo_v3.sv`, `axi/src/axi_lite_demux_read.sv`, `axi/src/axi_pkg.sv`, `synthesis/yosys_perf/perf_sv_wrappers.sv` |
| `axi_demux_write` | big | `^demux_aw_main$`, `^demux_w_main$`, `^demux_b_main$`, `^fifo_.*` | `perf_axi_demux_write_sv` | `common_cells/src/spill_register_flushable.sv`, `common_cells/src/spill_register.sv`, `common_cells/src/fifo_v3.sv`, `axi/src/axi_lite_demux_write.sv`, `axi/src/axi_pkg.sv`, `synthesis/yosys_perf/perf_sv_wrappers.sv` |
| `axi_mux_read` | big | `^mux_ar_main$`, `^mux_r_main$`, `^arbiter_.*`, `^fifo_.*` | `perf_axi_mux_read_sv` | `common_cells/src/cf_math_pkg.sv`, `common_cells/src/lzc.sv`, `common_cells/src/rr_arb_tree.sv`, `common_cells/src/spill_register_flushable.sv`, `common_cells/src/spill_register.sv`, `common_cells/src/fifo_v3.sv`, `axi/src/axi_lite_mux_read.sv`, `axi/src/axi_pkg.sv`, `synthesis/yosys_perf/perf_sv_wrappers.sv` |
| `axi_mux_write` | big | `^mux_aw_main$`, `^mux_w_main$`, `^mux_b_main$`, `^arbiter_.*`, `^fifo_.*` | `perf_axi_mux_write_sv` | `common_cells/src/cf_math_pkg.sv`, `common_cells/src/lzc.sv`, `common_cells/src/rr_arb_tree.sv`, `common_cells/src/spill_register_flushable.sv`, `common_cells/src/spill_register.sv`, `common_cells/src/fifo_v3.sv`, `axi/src/axi_lite_mux_write.sv`, `axi/src/axi_pkg.sv`, `synthesis/yosys_perf/perf_sv_wrappers.sv` |
| `ace` | big | `^ace_main$` | `perf_ace_sv` | `ace/src/snoop_pkg.sv`, `ace/src/ccu_fsm.sv`, `axi/src/axi_pkg.sv`, `synthesis/yosys_perf/perf_sv_wrappers.sv` |
| `tilelink` | big | `^tilelink_arb$`, `^crossbar_A_.*`, `^crossbar_D_.*` | `TLCrossBar` | `tilelink/debug_output/TLArbiter.sv`, `TLArbiter_2.sv`, `TLArbiter_4.sv`, `TLArbiter_6.sv`, `TLArbiter_8.sv`, `TLCrossBar.sv` |

Note the asymmetry that's the whole point of the comparison: the Anvil side always synthesizes the DUT-equivalent core module(s) only (driver/master/slave processes filtered out via `anvil_ignore_patterns` by default), while the SV side's `sv_top`/`sv_files` are hand-picked per case to be the closest SV analog of that same DUT - e.g. `axi_demux_read`'s Anvil core includes the embedded `fifo_.*` instance(s) its protocol state machine spawns, matched on the SV side by including `fifo_v3.sv` as one of `perf_axi_demux_read_sv`'s `sv_files` so the embedded FIFO is present on both sides, not just one. `tilelink` is the one case with no `synthesis/yosys_perf/perf_sv_wrappers.sv` wrapper at all - its SV side measures the raw, unwrapped Chisel-generated `TLCrossBar` directly (see `WIDTH_FINDINGS.md`'s "TileLink Notes" for why: the manifest intentionally compares against the full raw crossbar rather than a compat-width wrapper).

`perf_sv_wrappers.sv` (the wrapper file all other 9 cases include) supplies each case's `perf_<case>_sv` top module - a thin SV top that instantiates the real `common_cells`/`axi`/`ace` DUT(s) at widths matched to the Anvil model (see `WIDTH_FINDINGS.md` for the width-alignment table and rationale per case).

## Real-synthesis flow specifics

`collect_real_synth_perf.py` does not re-run Anvil codegen or re-derive the module selection above - it reads the already-generated/sanitized SV from a specific `collect_yosys_perf.py` run's `generated/` output directory (auto-discovered as the most recent timestamped run under `synthesis_reports/yosys_perf_results/` unless `--generated-dir` is passed - see `pact.md`), and layers real sky130 synthesis (`dfflibmap` + `abc -liberty`) and OpenSTA timing/power reporting on top of the exact same per-module isolated files `collect_yosys_perf.py` already produced. So the component-selection rules above (core patterns, ignore patterns, `--include-neighbors`) are inherited from whichever `collect_yosys_perf.py` run is being read, not re-decided by the real-synthesis script itself.

## See also

- `yosys_perf/OVERHEAD_FINDINGS.md` - root-caused Anvil/SV cell-count and area/power overhead sources.
- `yosys_perf/WIDTH_FINDINGS.md` - per-case width-alignment verification and structural notes.
- `../formal/comm_safety/README.md` - the model-checking case studies (a separate flow).
- `../testbench.md` - the cycle-equivalence case studies (a separate flow).
- `../pact.md` - top-level command reference tying all of the above together.
