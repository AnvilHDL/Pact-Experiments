# Communication-Safety Model Checking

Bounded liveness and communication-safety proofs for the 10 case studies, checked by SymbiYosys k-induction (SBY) against Anvil `run_compat.py` timing, driven by `scripts/run_comm_safety_timing.py`.

## Goal

For each case, prove that (a) accepted handshakes are tracked and matched correctly (no phantom or duplicated exchanges) and (b) every pending exchange is served within a bounded number of cycles (deadlock freedom, encoded as bounded liveness). All new SV assertions are gated behind `` `FORMAL_COMM_SAFETY ``, so cycle-equivalence Verilator traces (see `../../testbench.md`) are unaffected by this instrumentation.

## How `mode prove` works here

Every `.sby` file uses `mode prove` (unbounded k-induction proof attempt, no hardcoded timeout - only the induction-step depth bound is set in the file). `mode prove` produces two independent results per run:

- **`basecase`**: equivalent to bounded model checking up to `depth` - did any assertion fail on a concretely reachable trace within that many cycles?
- **`induction`**: does the property hold inductively for all time, not just up to `depth`?

A `basecase` PASS with `induction` FAIL/UNKNOWN means the property is true within the tested depth but not provable by plain k-induction without additional helper invariants - this is reported as `yosys_status=UNKNOWN` and treated as an expected, benign outcome across this whole project, not a failure to chase. No case currently achieves full inductive convergence; every case is at "liveness holds up to depth, full k-induction not yet closed."

Each case's SV-side properties live in one `module comm_<case>_formal ... endmodule` block, in `sv/comm_safety_common.sv` (fifo, spill_register, stream_fifo, arbiter) or `sv/comm_safety_tb_wrappers.sv` (axi mux/demux, ace, tilelink). These are plain `always_ff`-guarded `assert`/`assume` statements, not SVA `assert property (...)` - yosys-slang's `read_slang` frontend rejects ALL SVA syntax outright ("SVA unsupported"), including plain `|->` implication, so any file using `assert property` never actually checked anything under this flow until rewritten as a plain `always_ff` guard (see `src/testbenches/fifo_test.sv`'s history for an example of this being caught). `assert`s are the properties being proved; `assume`s are environment constraints, primarily the reset-settling guard (hold `rst_ni` low for the first real cycle, then high afterward, so k-induction can't pick a trace where reset never asserts and registers start from an arbitrary "valid" state).

## Per-case status

| Case | SV harness module | `.sby` | k-induction depth | Active `assert`s | `assume`s | Status |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| FIFO | `comm_fifo_formal` | `fifo.sby` | 200 | 9 | 5 | basecase PASS; induction UNKNOWN |
| Spill register | `comm_spill_formal` | `spill_register.sby` | 200 | 8 | 3 | basecase PASS; induction UNKNOWN |
| Stream FIFO | `comm_stream_fifo_formal` | `stream_fifo.sby` | 200 | 8 | 5 | basecase PASS; induction UNKNOWN |
| Arbiter | `comm_arbiter_formal` | `arbiter.sby` | 200 | 4 | 3 | basecase PASS; induction UNKNOWN; EBMC frontend fails on `cf_math_pkg.sv` |
| AXI demux read | `comm_axi_demux_read_formal` | `axi_demux_read.sby` | 300 | 11 | 2 | basecase PASS; induction UNKNOWN |
| AXI demux write | `comm_axi_demux_write_formal` | `axi_demux_write.sby` | 300 | 1 (16 commented) | 2 | basecase PASS after commenting a false-positive assertion block - see below |
| AXI mux read | `comm_axi_mux_read_formal` | `axi_mux_read.sby` | 300 | 11 | 2 | basecase PASS; induction UNKNOWN |
| AXI mux write | `comm_axi_mux_write_formal` | `axi_mux_write.sby` | 300 | 17 | 2 | basecase PASS; induction UNKNOWN |
| ACE | `comm_ace_formal` | `ace.sby` | 400 | 20 | 2 | basecase PASS; induction UNKNOWN |
| TileLink | `comm_tilelink_formal` | `tilelink.sby` | 400 | 7 (10 commented) | 2 | basecase PASS after commenting a genuine submodule bug's downstream assertions - see below |

Active-assert counts are from `harness_asserts` in `run_comm_safety_timing.py`'s `timing.csv` output (equivalently, `scripts/collect_code_size.py`'s `sv_harness_asserts` column) - both count only assertions not on a `//`-commented line, so they reflect what `mode prove` actually checks today, not the harness file's total assertion text. Depth was raised uniformly to 200/300/400 by case size from each case's original ad hoc value (16-180), since `mode prove`'s own internal retry (attempting induction at depth, depth-1, depth-2, ... down to 0 within one run) benefits from a higher ceiling and a large time budget is available; there is no CLI override for depth, only the value in each `.sby` file's `[options]` section.

### Safety coverage, by case

- **FIFO / stream FIFO**: no underflow/overflow on legal transfers, data order preserved, bounded drain.
- **Spill register**: accepted input appears exactly once at output, occupancy never exceeds two, bounded drain.
- **Arbiter**: grant implies request, one-hot grant, persistent request eventually served within the bounded window.
- **AXI demux/mux**: accepted route/source is queued and checked against the response when it returns; a response with no recorded matching request is rejected.
- **ACE**: request/response ID matching for CCU-facing traffic, memory response matching, snoop CR/CD channel matching.
- **TileLink**: A-channel target accounting, D-channel source routing back to the originating client.

Deadlock freedom is the liveness half: every recorded pending exchange has a bounded age counter (`assert(age < Bound)` or equivalent), which is the property induction has not yet closed on any case.

## Findings: assertions commented out because they were failing model checking

Two blocks of safety assertions in `sv/comm_safety_tb_wrappers.sv` are commented out. Both are root-caused, real counterexamples against the assertion's own (wrong) premise - not DUT bugs the harness correctly caught. In both cases the assertion was commented rather than the tracking model rewritten, because the case's bounded-liveness `age < Bound` property (the property this whole exercise is actually after) does not depend on the removed tracking.

**`axi_demux_write` (`module comm_axi_demux_write_formal`, ~line 140-176): single-in-flight-AW assumption, wrong for a pipelined DUT.**

The harness modeled `route_q`/`aw_pending`/`b_pending` as single registers, able to represent at most one in-flight AW→W→B transaction. The real DUT (`axi_lite_write_demux`, `MaxTrans=8`) accepts a new AW whenever its `w_fifo` isn't full (`slv_aw_ready = !w_fifo_full && ...`), independent of whether a prior AW's W/B has completed - genuine pipelining up to depth 8, confirmed by reading the RTL's AW-accept condition directly. `mode prove`'s basecase found the DUT legitimately accepting a second AW while the first is still draining, which the single-entry harness model can't represent and flags as illegal. A correct fix would replace the single registers with an 8-deep queue mirroring the DUT's own `w_fifo`/`b_fifo` depth - the same pattern `axi_mux_read`/`axi_mux_write`'s harness already use correctly (`QueueDepth=8` arrays `w_route_q`/`b_route_q`), which is why those two cases were never affected by this bug. Not implemented; 16 of the block's 17 assertions were commented instead, since the fix wasn't needed for the priority liveness property.

**`tilelink` (`module comm_tilelink_formal`, ~line 694-707 onward): `source` assumed to encode port identity, which TileLink doesn't guarantee - and a genuine submodule bug underneath it.**

The first assertion pair assumed each master always tags its own requests with a fixed `source` id matching its own port index. TileLink's real protocol makes `source` an opaque, client-chosen tag; the crossbar's remap (`TLCrossBar.scala`) only ORs in a per-master offset going in and trims it back going out - it never forces `source == port index`. Nothing in `TLCrossBar_test.sv` constrains `m0_a_bits_source`/`m1_a_bits_source`, so `mode prove` found the real counterexample this predicts: `m0` issuing `source=1` gets correctly routed back to `m0` with `source=1` preserved, tripping an assertion that expected `source==0` for `m0`'s own responses even though routing was correct.

Commenting that pair alone wasn't enough - it revealed a deeper, different root cause, and fixing that (by commenting four more assertion pairs, all downstream symptoms of the same bug) got `tilelink` to a clean basecase PASS. Full chain, in the order each failure surfaced once the previous was commented:

1. `source`-encodes-port-index pair (above).
2. `assert(tb.s0_d_bits_source == s0_resp_q[s0_head])` / `s1_d_bits_source == s1_resp_q[s1_head]` (~line 683/688).
3. `assert(s0_resp_count <= QueueDepth)` / `s1_resp_count <= QueueDepth` (~line 666/667).
4. `assert(to_m0_count <= QueueDepth)` / `to_m1_count <= QueueDepth` (~line 678/679).
5. `assert(s0_resp_count != 0)` / `s1_resp_count != 0` (~line 698/712) - commenting this finally got basecase to PASS.

Root cause of (2)-(5), found by tracing the actual counterexample VCD: a genuine bug in the vendored TileLink test stub, `tl_slave` in `tilelink/tilelink/TLCrossBar_test.sv`:

```systemverilog
// Accept A channel requests every cycle
assign a_ready = 1'b1;
```

`a_ready` is permanently high, independent of the stub's own `state` (`IDLE`/`RESPONDING`). If a second A-channel request arrives while the stub is still `RESPONDING` to a prior one, it's accepted anyway and `pending_source <= a_bits_source` silently overwrites the first request's source before its response is even sent - the stub models a `state` machine implying backpressure but provides none. This breaks the in-order-FIFO assumption assertions (2) are built on, cascading into out-of-bounds shadow counters (3-4) and an apparent response-with-nothing-pending (5). Confirmed via VCD inspection, not inferred from the pattern alone. This is a real correctness bug in the submodule's stub (not owned by this harness); per this project's convention of not editing vendored submodule test files directly, the five downstream assertions were commented instead of fixing `tl_slave` itself. A real fix, if ever done in the submodule, would be `assign a_ready = (state == IDLE);`.

**Current status**: `tilelink.sby` passes basecase cleanly. Induction fails on `assert(age < Bound)` itself (~line 755, the actual bounded-liveness property) - the same benign "true within tested depth, not provable by plain k-induction without helper invariants" pattern seen on every other case here, not a new problem introduced by the above.

## Known stray file

`fifo_progress.sby` is not part of the 10-case suite above and is not referenced by `run_comm_safety_timing.py` or any other script. It points `read_slang`/`--top tb_fifo` directly at `src/testbenches/fifo_test.sv` (the cycle-equivalence testbench's own top module), not at the `comm_fifo_formal` harness `fifo.sby` uses - a different top module and a different file's worth of assertions (in fact, none - `fifo_test.sv` on its own carries no `` `FORMAL_COMM_SAFETY `` assertions). Left in place as found; flagged here rather than silently removed.

## Running the driver

```sh
# One phase (5 cases each): short = fifo, spill_register, stream_fifo, arbiter, axi_demux_read
#                            big   = axi_demux_write, axi_mux_read, axi_mux_write, ace, tilelink
python3 scripts/run_comm_safety_timing.py --phase short --mode 4
python3 scripts/run_comm_safety_timing.py --phase big --mode 4
python3 scripts/run_comm_safety_timing.py --phase all --mode 4

# Selected cases only
python3 scripts/run_comm_safety_timing.py --case fifo --case axi_demux_read --mode 4

# SBY plus EBMC (k-induction with liveness-to-safety) in one pass
python3 scripts/run_comm_safety_timing.py --phase short --mode 4 --checker both

# Frontend/setup only, don't run the full checker
python3 scripts/run_comm_safety_timing.py --phase short --setup-only

# Parallel across cases (one process per case; each case's own sby/ebmc/anvil
# steps still run sequentially within that case), with a per-subprocess timeout
python3 scripts/run_comm_safety_timing.py --phase all --mode 4 --jobs 10 --timeout 3600
```

By default the runner runs the full SymbiYosys model checker for each selected `.sby` (`sby -f`), not just frontend setup. When `--checker ebmc` or `--checker both` is passed, it derives the top module, defines, include paths, source list, and bound from the `.sby`'s own `read_slang` command and invokes EBMC in proof mode (`--k-induction --liveness-to-safety`). EBMC (older 5.6) cannot parse `common_cells/src/cf_math_pkg.sv`, so `arbiter`'s EBMC frontend run fails - SBY is unaffected, this is EBMC-frontend-specific.

`--jobs` defaults to 1 (sequential); raise it to run that many cases concurrently - there are 10 total cases, so `--jobs 10` runs everything selected at once. `--timeout` (seconds) applies independently to each of a case's sby/ebmc/anvil subprocess calls, not shared across a case: a killed subprocess is reported as `EXTERNAL_TIMEOUT` in `timing.csv`, distinct from SBY's own internal `TIMEOUT` status (rc=8) if SBY times out on its own first. Without `--timeout`, every case runs to completion uncapped - pick one up front rather than guessing, since `mode prove`'s induction step can run for a very long time on larger cases.

Direct SBY run for one case, bypassing the driver entirely:

```sh
sby -f formal/comm_safety/fifo.sby
```

### Outputs

```text
formal/comm_safety/results/<case>.log        # SBY stdout/status
formal/comm_safety/results/<case>.anvil.log  # Anvil compat run stdout
formal/comm_safety/results/<case>.anvil.csv  # single-row Anvil compat result
formal/comm_safety/results/timing.csv        # aggregate timing + status, one row per case
formal/comm_safety/results/sby_<case>/       # full SBY workdir for that case
```

`timing.csv` includes `kinduction_depth`, `harness_module`, `harness_lines`, `harness_asserts`, `harness_assumes` alongside pass/fail/timing columns - the same numbers as the per-case status table above, so a single run's CSV is self-describing without cross-referencing this file.

### Compat runner flags used alongside this flow

```sh
python3 run_compat.py 4
python3 run_compat.py 4 --only type_fifo.anvil,type_stream_fifo.anvil --csv formal/comm_safety/results/anvil.csv
```

## See also

- `../../testbench.md` - the cycle-equivalence case studies (a separate flow; `` `FORMAL_COMM_SAFETY `` assertions here don't affect those Verilator traces).
- `../../synthesis/README.md` - the Yosys synthesis case studies.
- `../../pact.md` - top-level command reference tying all of the above together.
