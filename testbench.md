# Cycle-Equivalence Testbenches

This document covers the 10 case studies compared for cycle-level Anvil/SV equivalence: what each testbench's stimulus does, how each run script builds and executes it, and the source-reproducibility fix applied to all 6 scripts that pull SV from a submodule.

## How a cycle-equivalence run works

Every script in this family follows the same two-sided shape:

1. **SV side**: Verilator compiles a fixed set of `.sv` sources plus a per-case C++ driver (`src/compat/sim_main.cpp`, `sed`-substituted per case into a `Vtop` → `V<top_module>` rename) into a standalone executable, which is run for a fixed cycle budget. Its `[Cycle N] ...` stdout lines are captured to a log.
2. **Anvil side**: `make -B run` in `src/compat/`, parameterized by `MODULE_NAME=<test>`, builds and runs the matching Anvil compat test, whose `[Cycle N] ...` lines are captured the same way.
3. Both logs are normalized (`grep '^\[Cycle'`, whitespace-collapsed, and for the arbitrated-order cases, sorted by cycle/tag so nondeterministic same-cycle event ordering doesn't cause spurious diffs) and diffed. A clean `diff -u` is the pass condition; the script does not itself assert on this (`set -euo pipefail` will already have aborted on any earlier build/run failure, but a nonempty `logic.diff` does not stop the script - inspect `logic.diff` in the log directory to confirm equivalence, don't just trust the "Logical logs match" trailer, which always prints once execution reaches the end).

Output layout is per-script (SV logs, driver, and diffs live next to the source group being tested - `src/logs/common_cells_cycle_equiv/`, `axi/logs/<case>_cycle_equiv/`, `ace/logs/cycle_equiv/`, `tilelink/logs/tilelink_cycle_equiv/`), while build objects go to a matching `build/` directory. Both are gitignored; only the source copies described below are tracked.

## Source reproducibility: why every script copies into `src/testbenches/`

`axi/`, `ace/`, and `tilelink/` are git submodules whose working trees hold **untracked** testbench and (for tilelink) generated-SV files - `git log -- <file>` on any of them returns nothing, because they were never committed anywhere in the submodule's own history. Only `common_cells/` is fully tracked and clean.

This was a real, live divergence, not just a theoretical risk: as of this pass, `src/testbenches/ccu_fsm_tb.sv` (the tracked copy, last touched well before the current ACE work) had drifted structurally from `ace/src/ccu_fsm_tb.sv` (the file `run_ace_cycle_equiv.sh` actually builds) - different memory sizing (12KB vs 256B), a different transaction-timing scheme, and critically, the tracked copy was missing the entire `` `ifdef ACE_TB_TRACE `` reference-log-replay block that `run_ace_cycle_equiv.sh` depends on via its `+ACE_TB_REF_LOG=` plusarg. The tracked `axi_lite_*_tb.sv` copies had a narrower drift (a `data_count` width mismatch, 32-bit vs 8-bit). Had anyone built from the tracked copies instead of the live submodule paths, the ACE case would have failed outright (missing plusarg handling) and the AXI cases would have silently exercised different stimulus widths than what the scripts' logs claim to reflect.

**Fix applied**: each of the 6 scripts that read from `axi/`, `ace/`, or `tilelink/` now copies its needed `.sv` sources into `src/testbenches/` at the start of every run (plain `cp`, unconditional - always overwrites, never conditional on staleness), and builds Verilator from those `src/testbenches/` copies rather than referencing the submodule path directly. `src/testbenches/` itself is fully tracked in the main repo, so a checked-in copy always exists even if the submodule working tree is later reset or the submodule isn't checked out with the exact local edits in place. `run_common_cells_cycle_equiv.sh` needed no change - it already built directly from `src/testbenches/`, which is the tracked, canonical location, and its upstream dependency (`common_cells/`) is a clean submodule with no drift risk.

Not copied: `common_cells/src/*.sv` (referenced in place - that submodule is tracked and clean) and `axi/src/axi_pkg.sv` (a pure type/package file referenced in place across all AXI-family scripts, left untouched for consistency with how those scripts already treated it - no drift was found in it). `tilelink/debug_output/` also holds large synthesis byproducts (an 86MB `.blif`, logs) alongside the generated `.sv` sources Verilator needs; only the seven `.sv` files actually on the build command line are copied, not the whole directory.

## Per-case behavior

### Common cells (`run_common_cells_cycle_equiv.sh`)

Four cases share one script via a `run_case(case_name, sv_file, top_module, trace_define, anvil_module)` bash function. All SV sources are read directly from `src/testbenches/` (already the tracked, canonical location - no submodule involved).

- **FIFO** (`fifo_test.sv` / `test_fifo`) - 1-bit data. Single master pushes at exponentially-spaced cycles; single slave reads continuously.
- **Stream FIFO** (`stream_fifo_test.sv` / `test_stream_fifo`) - 1-bit data. Same shape as FIFO but over a ready/valid streaming handshake instead of explicit push/pop.
- **Spill register** (`spill_register_test.sv` / `test_spill_reg`) - 1-bit data. Regression testbench for a push/pop-while-full/empty logic bug; master sends on even cycles, slave reads on multiples of 4, with spill-specific timing when a cycle is a multiple of both 4 and 3.
- **Arbiter** (`arbiter_test.sv` / `test_arbiter`) - 1-bit data. 4 slaves round-robin-arbitrate for one master; slaves request at power-of-2 cycles, master responds every 3 cycles.

### AXI Lite mux/demux (4 scripts, `axi/` submodule)

All four share a shape: build `common_cells` support cells (`fifo_v3`, `spill_register[_flushable]`, and for the mux cases the round-robin arbiter tree - `cf_math_pkg`, `lzc`, `rr_arb_tree`) plus `axi/src/axi_pkg.sv` in place, and the case's DUT + testbench from the freshly-copied `src/testbenches/` copies. Read/write directions and mux/demux roles are tested as fully separate case studies (separate scripts, separate Anvil modules), not combined.

- **`run_axi_demux_read_cycle_equiv.sh`** (`axi_lite_demux_read[_tb].sv` / `test_demux_read`) - one read master demultiplexed across multiple slaves, round-robin slave selection.
- **`run_axi_demux_write_cycle_equiv.sh`** (`axi_lite_demux_write[_tb].sv` / `test_demux_write`) - write-side counterpart; has an `ANVIL_CHECKS` env toggle (default off, sets `SESSIONOFF=1 COMPATOFF=1`) to disable Anvil-side session/compat checking for a faster run.
- **`run_axi_mux_read_cycle_equiv.sh`** (`axi_lite_mux_read[_tb].sv` / `test_mux_read`) - multiple read masters arbitrated onto one slave; also has the `ANVIL_CHECKS` toggle.
- **`run_axi_mux_write_cycle_equiv.sh`** (`axi_lite_mux_write[_tb].sv` / `test_mux_write`) - write-side counterpart; same `ANVIL_CHECKS` toggle.

Per `src/testbenches/testbench_overview.md`'s stimulus notes: masters/slaves proceed serially with exponential-cycle timing, and data width is kept at 8 bits specifically because some assertions require it - this is the width the `data_count` mismatch above was silently deviating from in the stale tracked copies.

### ACE (`run_ace_cycle_equiv.sh`, `ace/` submodule)

Inverted execution order relative to every other script: **Anvil runs first** (`test_ace`, no timeout override), and its normalized `[Cycle N] ...` output becomes the reference log (`REF_LOG`). The SV testbench (`ccu_fsm_tb.sv`, built with `--timing` for its internal delay modeling) is then run second and reads that same reference log back in via `+ACE_TB_REF_LOG=$REF_LOG` (handled by the `` `ifdef ACE_TB_TRACE `` block described above) so its own trace can be compared against it directly, rather than two independently-generated logs being diffed after the fact. Sources copied into `src/testbenches/`: `ace_pkg.sv`, `snoop_pkg.sv`, `ccu_fsm.sv` (DUT), `ccu_fsm_tb.sv` (testbench); `axi/src/axi_pkg.sv` is referenced in place (ACE's CCU FSM sits on top of AXI signal types).

Stimulus: a snoop-coherent CCU (cache coherency unit) FSM driven by slaves issuing requests at power-of-2 cycles, cycling through 5 ACE transaction types (READ_SHARED, READ_UNIQUE, CLEAN_UNIQUE, WRITE_UNIQUE, READ_NO_SNOOP across 4 address ranges), against a 4-state snoop-response FSM maintaining a 16-line MESI-like cache, and a dummy memory controller (RAM array, IDLE→READ_WAIT→READ_RESP/WRITE_DATA→WRITE_RESP, 1-2 cycle access latency).

### TileLink (`run_tilelink_cycle_equiv.sh`, `tilelink/` submodule)

Three steps, not two: `[1/3]` builds and runs the SV crossbar testbench, `[2/3]` type-checks the Anvil side standalone (`run_anvil -jc src/compat/test_tilelink.anvil`) before running it, `[3/3]` runs the Anvil compat test itself. Sources copied into `src/testbenches/`: `TLArbiter.sv`, `TLArbiter_2.sv`, `TLArbiter_4.sv`, `TLArbiter_6.sv`, `TLArbiter_8.sv`, `TLCrossBar.sv` (all from `tilelink/debug_output/`, which is CIRCT/firtool-generated SV mixed in with unrelated synthesis byproducts - only these 6 files are copied, not the directory), plus `TLCrossBar_test.sv` (from `tilelink/tilelink/`, the hand-authored testbench). Uses the arbitrated-order `normalize_logic_log` variant (sorted by cycle then tag) since crossbar transaction ordering across masters is not fully deterministic cycle-to-cycle.

Stimulus (`TLCrossBar_test.sv`, 8-bit data channels): 2 masters, 2 slaves; masters send on every even cycle, slaves respond A→D in sequence.

## See also

- `formal/README.md` - the model-checking (SymbiYosys k-induction) case studies, a separate flow from cycle equivalence.
- `synthesis/README.md` - the Yosys synthesis case studies and per-case default component selection.
- `pact.md` - top-level command reference tying all of the above together.
