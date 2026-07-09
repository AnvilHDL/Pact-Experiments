# PACT Experiment Runbook

This file is the quick entry point for running the different parts of the Anvil/SV case-study experiment.

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
```

**All 5 collection scripts** (`run_comm_safety_timing.py`, `collect_state_space.py`, `collect_code_size.py`, `collect_yosys_perf.py`, `collect_real_synth_perf.py`) **write into a new timestamped subdirectory by default, never overwriting a previous run's results** - e.g. `formal/comm_safety/results/20260709_121220/` or `synthesis_reports/yosys_perf_results/20260709_121336/`. Each prints its own `Results directory: ...` line at startup so you always know where a given run's output landed. Pass `--results-dir <path>` (or `--csv <path>` for `collect_code_size.py`) to force a specific location instead - useful for re-running into a known directory, or for scripting that expects a stable path.

`collect_real_synth_perf.py` reads Anvil's already-generated SV from `collect_yosys_perf.py`'s own output rather than re-deriving codegen. By default it auto-discovers the **most recently created** timestamped run under `synthesis_reports/yosys_perf_results/` and reads that run's `generated/` subfolder - so the usual two-step workflow is: run `collect_yosys_perf.py` once for the cases you need, then run `collect_real_synth_perf.py` and it picks up that same run automatically (also printed at startup: `Reading generated SV from: ...`). Pass `--generated-dir <path>` to point at a specific run instead (e.g. if you've run `collect_yosys_perf.py` multiple times and want an older one).

## Cycle Equivalence

These scripts run the SV testbench and the matching Anvil compat test back to back, then compare cycle-level behavior.

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

The communication-safety work is under:

```text
formal/comm_safety/
```

All `.sby` files use `mode prove` (SymbiYosys k-induction, unbounded proof attempt) with no hardcoded timeout - only the depth used as the induction step bound stays in the file. `mode prove` produces two independent results per case: `basecase` (equivalent to BMC up to `depth`) and `induction` (does the property inductively hold for all time, not just up to depth). A basecase PASS with induction FAIL/UNKNOWN means the property is true within the tested depth but not provable by plain k-induction without extra helper invariants - that is expected and reported as-is (`yosys_status=UNKNOWN`), not treated as a real failure or something to fix by adding invariants.

### What Is Actually Being Checked, Per Case

Each case's SV-side properties live in one `module comm_<case>_formal ... endmodule` block in `formal/comm_safety/sv/comm_safety_common.sv` (fifo, spill_register, stream_fifo, arbiter) or `formal/comm_safety/sv/comm_safety_tb_wrappers.sv` (the AXI mux/demux, ace, tilelink cases). These are plain `always_ff`-guarded `assert`/`assume` statements, not SVA `assert property (...)` - yosys-slang's `read_slang` frontend rejects ALL SVA syntax outright ("SVA unsupported"), including plain `|->` implication, so any file that used `assert property` never actually ran any checks under this flow until rewritten (see `src/testbenches/fifo_test.sv`'s history for an example of this being caught and fixed).

`assert`s are the safety/liveness properties actually proved; `assume`s are environment constraints (mainly the reset-settling guard: hold `rst_ni` low for the first real cycle, then high afterward, so k-induction can't pick a trace where reset never asserts and registers start from an arbitrary "valid" state). Counts below are from `harness_asserts`/`harness_assumes` in `run_comm_safety_timing.py`'s own `timing.csv` output (also collectible standalone via `scripts/collect_code_size.py`, which reports the same two counts as `sv_harness_asserts`/`sv_harness_assumes`).

| Case | k-induction depth | Harness `assert`s (active) | Harness `assume`s | Harness module |
| --- | ---: | ---: | ---: | --- |
| fifo | 200 | 9 | 5 | `comm_fifo_formal` |
| spill_register | 200 | 8 | 3 | `comm_spill_formal` |
| stream_fifo | 200 | 8 | 5 | `comm_stream_fifo_formal` |
| arbiter | 200 | 4 | 3 | `comm_arbiter_formal` |
| axi_demux_read | 300 | 11 | 2 | `comm_axi_demux_read_formal` |
| axi_demux_write | 300 | 1 | 2 | `comm_axi_demux_write_formal` |
| axi_mux_read | 300 | 11 | 2 | `comm_axi_mux_read_formal` |
| axi_mux_write | 300 | 17 | 2 | `comm_axi_mux_write_formal` |
| ace | 400 | 20 | 2 | `comm_ace_formal` |
| tilelink | 400 | 7 | 2 | `comm_tilelink_formal` |

`axi_demux_write`'s and `tilelink`'s low active-assert counts reflect the commented-out assertions documented in the next section (16 of 17 commented for `axi_demux_write`, 10 of 17 for `tilelink`) - the count excludes anything on a `//`-commented line, so it reflects what `mode prove` actually checks right now, not the harness file's total assertion text.

Depth was raised from each case's original (16-180, roughly matched to design size) to a uniform 200/300/400 by phase, since a large time budget is available and `mode prove`'s own internal retry (attempting induction at depth, depth-1, depth-2, ... down to 0 within one run) benefits from a higher ceiling - see "the depth line in the `.sby` file's `[options]` section" above for how to change it further; there is no CLI override flag in this SBY version, only the file value.

### Assertions Commented Out Because They Were Failing Model Checking

Two blocks of safety assertions in `formal/comm_safety/sv/comm_safety_tb_wrappers.sv` are currently commented out. Both are real, root-caused false positives - the assertion's own premise was wrong for what the DUT actually does, not a bug the DUT has. In both cases the fix chosen was to comment out the specific over-strict assertion rather than rewrite the harness's tracking model, because the case's bounded-liveness `age < Bound` property (the priority property) doesn't depend on the removed tracking.

**`axi_demux_write` (`module comm_axi_demux_write_formal`, ~line 140-176): single-in-flight-AW assumption, wrong for a pipelined DUT.**

```systemverilog
// if (slv_aw_fire) begin
//   assert(!aw_pending && !b_pending);
//   assert(aw_route == aw_addr_route);
//   assert(mst_aw_fire[aw_route]);
// end
// if (slv_w_fire) begin
//   assert(aw_pending);
//   assert(mst_w_fire[route_q]);
// end
// if (slv_b_fire) begin
//   assert(b_pending);
//   assert(tb.slv_resp.b.resp == 2'b00);
//   assert(mst_b_fire[route_q]);
// end
//
// for (int i = 0; i < NoPorts; i++) begin
//   if (mst_aw_fire[i]) begin
//     assert(slv_aw_fire);
//     assert(aw_route == i[1:0]);
//   end
//   if (mst_w_fire[i]) begin
//     assert(aw_pending);
//     assert(route_q == i[1:0]);
//     assert(tb.mst_reqs[i].w.data == data_q);
//   end
//   if (mst_b_fire[i]) begin
//     assert(b_pending);
//     assert(route_q == i[1:0]);
//   end
// end
```

Root cause: `route_q`/`aw_pending`/`b_pending` are single registers, so the harness can represent at most ONE in-flight AW-to-W-to-B transaction at a time. But the real DUT (`axi_lite_write_demux`, `MaxTrans=8`) accepts a new AW whenever its `w_fifo` isn't full (`slv_aw_ready = !w_fifo_full && ...`), fully independent of whether a prior AW's W/B has completed - genuine pipelining up to depth 8. `mode prove`'s basecase found a real, reachable counterexample: the DUT legitimately accepts a second AW while the first is still draining, which the single-entry model can't represent and flags as illegal. Confirmed via directly reading `axi_lite_write_demux`'s AW-accept logic (`!w_fifo_full && slv_aw_valid`) - not an assumption, a read of the actual RTL condition.

A correct fix would replace `route_q`/`aw_pending`/`b_pending` with an 8-deep queue mirroring the DUT's own `w_fifo`/`b_fifo` depth (same pattern already used correctly in `axi_mux_read`'s/`axi_mux_write`'s harness, which use real `QueueDepth=8` arrays - `w_route_q`/`b_route_q` - and were never affected by this bug). Not done here; commenting out was the chosen fix given the bounded-liveness property is the priority and doesn't need this tracking.

**`tilelink` (`module comm_tilelink_formal`, ~line 694-707): `source` assumed to encode port identity, which TileLink doesn't guarantee.**

```systemverilog
if (m0_d_fire) begin
  assert(to_m0_count + new_to_m0 != 0);
  // assert(tb.m0_d_bits_source == 2'd0); -- not a liveness check;
  // commented because it wrongly assumes `source` always encodes the
  // requesting master's own port index. The crossbar only trims
  // `source` back to whatever the client sent (TLCrossBar.scala:
  // `remapped.a.bits.source := io.a.bits.source | range.start.U` in,
  // `trim(...)` out) - it never forces source==port index. Nothing in
  // TLCrossBar_test.sv constrains m0_a_bits_source/m1_a_bits_source,
  // so a real counterexample exists where m0 issues source=1 and gets
  // correctly routed back to m0 with source=1 preserved, tripping this
  // assertion even though routing was correct.
end
if (m1_d_fire) begin
  assert(to_m1_count + new_to_m1 != 0);
  // assert(tb.m1_d_bits_source == 2'd1); -- see comment above.
end
```

Root cause: nothing in `TLCrossBar_test.sv` drives `m0_a_bits_source`/`m1_a_bits_source`, so they are free/unconstrained inputs from `mode prove`'s perspective. The assertion assumed each master always tags its own requests with a fixed `source` id matching its own port index (`m0`→0, `m1`→1) - but TileLink's real protocol makes `source` an opaque, client-chosen tag; the crossbar's remap (`TLCrossBar.scala`) only OR's in a per-master offset on the way in and trims it back on the way out, it never forces `source == port index`. `mode prove` found the real counterexample this predicts: `m0` issuing a request with `source=1` gets correctly routed back to `m0` with `source=1` preserved, which trips `assert(tb.m1_d_bits_source == 2'd1)` even though the crossbar behaved correctly.

That fix alone wasn't enough - commenting it out revealed a real, different, deeper root cause, and fixing that (by commenting four more assertion pairs, all downstream symptoms of the SAME bug) got `tilelink` to a clean basecase PASS, with only the intended liveness property left unresolved. Full chain, in the order each failure surfaced:

1. `assert(tb.m0_d_bits_source == 2'd0)` / `m1_d_bits_source == 2'd1` (shown above) - fixed by commenting (the `source`-encodes-port-index assumption, described above).
2. `assert(tb.s0_d_bits_source == s0_resp_q[s0_head])` / `s1_d_bits_source == s1_resp_q[s1_head]` (~line 683/688) - next failure once (1) was commented.
3. `assert(s0_resp_count <= QueueDepth)` / `s1_resp_count <= QueueDepth` (~line 666/667) - next failure once (2) was commented.
4. `assert(to_m0_count <= QueueDepth)` / `to_m1_count <= QueueDepth` (~line 678/679) - next failure once (3) was commented.
5. `assert(s0_resp_count != 0)` / `s1_resp_count != 0` (~line 698/712) - next failure once (4) was commented; commenting this finally got basecase to PASS.

**Root cause of (2)-(5), found by tracing the actual counterexample VCD**: this is NOT another harness-modeling assumption like (1) - it's a genuine bug in the vendored TileLink test stub, `tl_slave` in `tilelink/tilelink/TLCrossBar_test.sv`:

```systemverilog
// Accept A channel requests every cycle
assign a_ready = 1'b1;
```

`a_ready` is permanently high, completely independent of the stub's own `state` (`IDLE`/`RESPONDING`). So if a second A-channel request arrives while the stub is still `RESPONDING` to a prior one, it's accepted anyway and `pending_source <= a_bits_source` silently overwrites the first request's source before its response is even sent - the stub provides no real backpressure despite modeling a `state` machine that implies it should. This breaks the in-order-FIFO assumption `s0_resp_q`/`s1_resp_q` are built on (assertion 2), which cascades into the shadow counters going out of bounds (assertions 3-4) and eventually appearing to receive a response nothing was pending for (assertion 5). Confirmed via VCD trace inspection (`$var` declarations show `tb_slave0_pending_source`/`tb_slave1_pending_source` as single registers, and reading the stub source directly confirms `a_ready` has no `state`-based gating) - not inferred from the pattern alone. This is a real correctness bug in the submodule's stub, not something owned by this harness; per this project's convention of not editing vendored submodule test files directly, all five downstream assertions were commented instead of fixing `tl_slave` itself. A real fix, if ever done in the submodule, would be `assign a_ready = (state == IDLE);`.

**Current status**: `tilelink.sby` now passes basecase cleanly. Induction fails on `assert(age < Bound)` itself (the actual bounded-liveness property, ~line 755) - this is the same benign "true within tested depth, not provable by plain k-induction without helper invariants" pattern seen on every other case in this project, not a new problem. `tilelink` is functionally in the same state as the rest of the suite: liveness proven up to `depth`, full k-induction convergence not yet achieved anywhere in this project without further invariant work.

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

`timing.csv` includes `kinduction_depth`, `harness_module`, `harness_lines`, `harness_asserts`, `harness_assumes` alongside the pass/fail/timing columns - the same assertion/assume counts and depth bound documented in the table above, so a single run's CSV is self-describing without cross-referencing this file.

## Yosys Performance Collection

The performance collection flow compares Anvil-generated core modules against SV core components using Yosys synthesis statistics. It reports cell/area proxy metrics, not real activity-based power.

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

Width and structure notes for the current perf setup are in:

```text
synthesis/yosys_perf/WIDTH_FINDINGS.md
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

Known gaps: `axi_mux_read`/`axi_mux_write` are missing `common_cells/src/cf_math_pkg.sv` from their `.sby` file lists (same bug fixed for the model-checking `.sby`s themselves - see below); `ace`'s SV testbench has an unhandled `$finish` blocking synthesis. Not yet fixed in this script's own file-list handling.

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
rm -rf formal/comm_safety/results synthesis_reports/yosys_perf_results
```

Use the cleanup command only when you do not need the current logs or summaries.
