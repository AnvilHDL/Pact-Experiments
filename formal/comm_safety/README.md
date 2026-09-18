# Communication-Safety Model Checking

SymbiYosys (SBY) harnesses that check the two halves of *communication safety*
from the Pact paper (synchronization safety and liveness) on the ten case
studies, driven by `scripts/run_comm_safety_timing.py` alongside the Anvil
`run_compat.py` timing. Everything new lives behind `` `FORMAL_COMM_SAFETY ``
so the cycle-equivalence Verilator runs (see `../../testbench.md`) are
unaffected.

## What is checked, and what is not

The properties are written against the **full cycle-equivalence testbench** of
every case (the DUT together with the master/slave stubs that drive it, from
`src/testbenches/`), not against the DUT alone with free inputs. That makes the
verified object the same closed composition of participants that the Pact
types describe, and it makes every failure a real trace of that composition.

The paper defines communication safety for a closed composition
`Q0 = P1 ||_I1 ... ||_In-1 Pn` as the conjunction of

- **Synchronization safety**: no reachable residual is *stuck*. A participant
  that commits to a message action must complete it with its peer in that
  same cycle; a blocked prefix at a clock boundary is a stuck state.
- **Liveness**: the clock keeps ticking and every progress marker recurs on
  fair executions.

The SystemVerilog encoding used here, per case, is:

| Family | Property | SV encoding |
| --- | --- | --- |
| **S** | A committed action completes this cycle | `assert(!commit || fire)` on the wire (e.g. `push_i -> !full_o`, `ready_i -> valid_o`) |
| **S** | Both sides agree on which exchanges happened (no dropped, phantom or duplicated handshake) | each participant reports its own view (`f_*` signals derived from its FSM); `assert(f_view == valid && ready)`; DUT-side views come from the DUT's own internal handshake enables (`r_fifo_push`, `load_data`, `a_fill`, ...) |
| **S** | Fire-and-forget stubs deliver exactly one handshake per attempt | attempt windows: count wire handshakes between consecutive FSM attempt starts; `== 1` when the next attempt begins, `<= 1` always, none outside an attempt |
| **S** | Routers hand every message over in the same cycle on exactly one port of the other side, matching their own bookkeeping | `assert(slv_fire == \|mst_fire)`, one-hot, `assert(fifo_push == fire)` |
| **S** | A request accepted by a server is answered exactly once | response counter per transaction (ACE CCU); outstanding-request counter per client (TileLink) |
| **L** | Every started exchange finishes | `age` counts cycles while a participant is in flight (`f_busy`), while a router has outstanding transactions, or while a message is offered but not taken (`valid && !ready`); `assert(age < Bound)` |

Ages are counted only while an obligation is open. The stubs deliberately idle
for growing stretches (they issue on powers of two), so an unconditional
"progress recurs within N cycles" bound would be false for every N; a bound
on *open* obligations is the faithful bounded form of the paper's liveness.
Bounds are derived from the stubs' periods and stated with their reasoning at
the top of each harness. The only `assume` is the reset guard (reset low for
the first real cycle, high afterwards), which stops k-induction from starting
in an unreachable state; a closed composition has no environment to assume
honesty of.

Deliberately **not** checked, because they are functional rather than
communication properties: data ordering and values, occupancy/usage counts,
status-flag arithmetic (`full_o == (count == Depth)`), response codes
(`resp == OKAY`), ID/route bookkeeping against the address, queue capacity
limits. These were all present in the previous harness and were removed.

## Mechanics

- **Participant self-reports.** Each stub module in `src/testbenches/*.sv`
  carries a small `` `ifdef FORMAL_COMM_SAFETY `` block that exports plain
  booleans (`f_ar_snd`, `f_r_rcv`, `f_busy`, `f_attempt`, ...): the condition
  under which that FSM treats a message as done, or is in flight. The harness
  reads them hierarchically (`tb.gen_masters[i].master.f_ar_rcv`) and
  compares them with the wire-level handshake. Where a stub commits on one
  side of the handshake only (the AXI demux masters transition on `aw_valid`
  without looking at their own `aw_ready`; the ACE snoop FSM samples
  `ac_valid` a cycle before it raises `ac_ready`; the TileLink manager has
  `a_ready` tied high), this comparison is a genuine check.
- **DUT views** are read from the vendored DUTs' internal enables via
  hierarchical references; no vendored source is edited. The FIFO case keeps
  the ports the FIFO example added to its local `fifo_v3` copy.
- **Plain `always_ff` assertions only.** yosys-slang rejects all SVA. It also
  rejects hierarchical references to enum *members* (`tb.slave.WAIT_R`),
  which is why state decoding lives inside the stubs, and why the ACE
  harness mirrors `ccu_fsm`'s state encoding in localparams.
- **Per-case guards.** The four common-cells harnesses are each guarded by
  their own define (`FORMAL_COMM_FIFO_FULL_DESIGN`, `..._STREAM_FIFO_...`,
  `..._SPILL_...`, `..._ARBITER_...`, set in the `.sby`), because the FIFO
  and stream-FIFO testbenches both name their top `tb_fifo`.
- All `assert`s live in the `module comm_<case>_formal` blocks, so the
  per-case counts that `run_comm_safety_timing.py` writes to `timing.csv`
  (`harness_asserts`) remain accurate; the stubs only define signals.

## Per-case summary

| Case | Testbench top (`src/testbenches/`) | Harness module | `.sby` | Participants checked | `assert`s | Bounds (cycles) | Status |
| --- | --- | --- | --- | --- | ---: | --- | --- |
| FIFO | `tb_fifo` (`fifo_test.sv`) | `comm_fifo_formal` | `fifo.sby` | push master, `fifo_v3`, pop slave | 18 | attempt 16, drain 64, progress 64 | elaborates |
| Stream FIFO | `tb_fifo` (`stream_fifo_test.sv`) | `comm_stream_fifo_formal` | `stream_fifo.sby` | valid/ready master, `passthrough_stream_fifo`, slave | 13 | attempt 16, drain 64, progress 32 | elaborates |
| Spill register | `tb_spill` | `comm_spill_formal` | `spill_register.sby` | master, `spill_register_flushable`, slave | 10 | attempt/drain/progress 24 | elaborates |
| Arbiter | `tb_arbiter` | `comm_arbiter_formal` | `arbiter.sby` | 4 requesters, `rr_arb_tree`, granting master | 9 | grant 32, request 8 | elaborates |
| AXI demux read | `tb_axi_read_demux` | `comm_axi_demux_read_formal` | `axi_demux_read.sby` | slave, `axi_lite_read_demux`, 4 masters | 17 | 32 | elaborates |
| AXI demux write | `tb_axi_write_demux` | `comm_axi_demux_write_formal` | `axi_demux_write.sby` | slave, `axi_lite_write_demux`, 4 masters | 23 | 32 | elaborates |
| AXI mux read | `tb_axi_read_mux` | `comm_axi_mux_read_formal` | `axi_mux_read.sby` | 4 slaves, `axi_lite_read_mux`, master | 17 | 48 | elaborates |
| AXI mux write | `tb_axi_write_mux` | `comm_axi_mux_write_formal` | `axi_mux_write.sby` | 4 slaves, `axi_lite_write_mux`, master | 23 | 64 | elaborates |
| ACE | `ccu_fsm_tb` | `comm_ace_formal` | `ace.sby` | 4 clients (request + snoop FSM each), tb arbiter, `ccu_fsm`, memory | 54 | txn 160, snoop 32, mem 32, chan 32 | elaborates |
| TileLink | `tb_tlcrossbar` | `comm_tilelink_formal` | `tilelink.sby` | 2 clients, `TLCrossBar`, 2 managers | 24 | 32 | elaborates against a port stand-in only (see below) |

"Elaborates" means `yosys` + `read_slang` + `prep` on the `.sby`'s script
completes with the assertion cells present. **The `mode prove` runs
(basecase to depth 500 plus k-induction) have not been re-run with this
harness**; the previous results in this file (basecase PASS, induction
UNKNOWN on every case) were for the old DUT-only properties and no longer
apply. Expect the bounds to need adjusting on the first full run if a stub's
timing was mis-estimated; each bound's reasoning is in the harness.

Every `assume` count is 2 (the reset guard).

### Expected findings on the first run

- **TileLink** was expected to fail because the manager stub `tl_slave` had
  `assign a_ready = 1'b1;` and dropped requests arriving mid-response. That
  stub is fixed in the tracked copy (`a_ready = (state == IDLE)`, 2026-09-18),
  so `assert(s0_a_rcv == s0_a_fire)` and the per-client outstanding-request
  age are now expected to pass. Two consequences: the untracked
  `tilelink/tilelink/TLCrossBar_test.sv` on the authoring machine must get the
  same one-line change, or `scripts/refresh_testbench.sh` copies the bug back
  over the tracked file; and the paper's table row that marks the SV TileLink
  safety check as failing describes the stub before this fix.
- **Stream FIFO and spill register** stubs decide to push/pop one cycle before
  they raise `valid`/`ready`; when such an attempt has to wait, `valid` can
  stay high for one cycle after the FSM believes it is done, so a second
  handshake is possible if the peer is ready. The attempt-window assertions
  detect exactly that (two handshakes in one attempt). Whether it is
  reachable under the deterministic stimulus is for the run to decide.
- **AXI demux masters** transition to their receive state on `aw_valid` /
  `ar_valid` alone in the first cycle after returning to IDLE, when their own
  `ready` is still low. Under this stimulus the round-robin selection makes
  that unreachable, but `assert(mst_aw_rcv[i] == mst_aw_fire[i])` is the
  property that would catch it.

## Findings carried over from the previous harness

Two blocks of the previous DUT-only harness were commented out after
root-causing them. They are gone with the rewrite, but the underlying facts
still matter:

**`axi_demux_write`: single-in-flight assumption.** The old harness modelled
at most one in-flight AW; the DUT (`MaxTrans=8`) pipelines AWs whenever its
`w_fifo` is not full. The new harness has no such model: it checks the relay
property per channel and bounds the DUT's own outstanding records
(`!w_fifo_empty || !b_fifo_empty || lock_aw_valid_q`).

**`tilelink`: `source` is client-chosen, and `tl_slave` did not apply
back-pressure.** The old harness assumed `source == port index`; TileLink's
crossbar only ORs in a per-client offset going in and trims it going out. The
new harness is independent of the source mapping (it counts requests and
responses per client). The stub bug that the old harness had to work around
was, in `src/testbenches/TLCrossBar_test.sv`, module `tl_slave`:

```systemverilog
assign a_ready = 1'b1;   // accepted a request while RESPONDING, overwriting pending_source
```

It is fixed there as of 2026-09-18:

```systemverilog
assign a_ready = (state == IDLE);
```

The Anvil model `src/compat/test_tilelink.anvil` was made cycle-equivalent to
the stub before the fix; the manager's back-pressure may need mirroring there
for the cycle-equivalence diff to stay clean.

## Files

- `sv/comm_safety_common.sv`: FIFO, stream FIFO, spill register, arbiter.
- `sv/comm_safety_tb_wrappers.sv`: AXI demux read/write, AXI mux read/write,
  ACE, TileLink.
- `src/testbenches/*.sv`: `` `ifdef FORMAL_COMM_SAFETY `` self-report blocks
  in every stub module (both `ccu_fsm_tb.sv` and `ccu_fsm_tb2.sv` carry them;
  `ace.sby` uses `ccu_fsm_tb.sv`). Generated and re-applied by
  `scripts/instrument_comm_safety.py`.
- `fifo_progress.sby`: the inline variant of the FIFO check (`tb_fifo` as top
  with `FIFO_TB_INLINE_FORMAL`, the block inside `fifo_test.sv` itself). It is
  not part of the driver's ten cases; `fifo.sby` is.

### Source locations and a hazard

All `.sby` files read the testbenches (and, for AXI, the DUT copies) from
`src/testbenches/`, the tracked location. The `axi/`, `ace/` and `tilelink/`
submodules do not carry those files in their history, so the previous
`axi/src/...`, `ace/src/...` and `tilelink/...` paths only existed on the
machine that authored them. Packages and common cells are still read from the
submodules, which therefore have to be initialised (`git submodule update
--init common_cells axi ace`; the SSH URLs can be rewritten with
`git -c url."https://github.com/".insteadOf="git@github.com:"`).

**Refresh without loss.** The six cycle-equivalence scripts used to `cp` the
submodule working-tree copies over `src/testbenches/` unconditionally, which
would have stripped these blocks (and aborted on any clone where the
submodule copies are absent, since they are untracked). They now go through
`scripts/refresh_testbench.sh`, which copies when the submodule copy exists
and then re-runs `scripts/instrument_comm_safety.py` (idempotent) on the
result, and otherwise builds from the tracked copy. Run
`python3 scripts/instrument_comm_safety.py --check` to confirm every tracked
copy still carries its blocks.

**TileLink generated SV.** `tilelink.sby` expects the CIRCT/firtool output
(`TLCrossBar.sv`, `TLArbiter*.sv`) under `src/testbenches/`, where
`run_tilelink_cycle_equiv.sh` copies it from `tilelink/debug_output/`. That
output is not in any repository and needs the Chisel toolchain to regenerate;
it was absent on the machine this harness was written on, so the TileLink
harness was elaborated against a port-compatible stand-in of `TLCrossBar`
only.

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

# Parallel across cases, with a per-subprocess timeout
python3 scripts/run_comm_safety_timing.py --phase all --mode 4 --jobs 10 --timeout 3600
```

`--skip-anvil` skips the `run_compat.py` half when the Anvil compiler is not
installed. Every `.sby` uses `mode prove` with `depth 500`; a `basecase` PASS
with `induction` UNKNOWN means the properties hold to that depth but plain
k-induction has not closed them (the stubs' 32-bit cycle counters make that
the expected outcome). Direct run for one case:

```sh
sby -f formal/comm_safety/fifo.sby
```

Elaboration-only check of one case (what "elaborates" above means):

```sh
yosys -p "$(awk '/^\[script\]/{f=1;next} /^\[/{f=0} f' formal/comm_safety/fifo.sby | sed '/^$/d;s/$/; /' | tr -d '\n') stat"
```

### Outputs

```text
formal/comm_safety/results/<case>.log        # SBY stdout/status
formal/comm_safety/results/<case>.anvil.log  # Anvil compat run stdout
formal/comm_safety/results/<case>.anvil.csv  # single-row Anvil compat result
formal/comm_safety/results/timing.csv        # aggregate timing + status, one row per case
formal/comm_safety/results/sby_<case>/       # full SBY workdir for that case
```

`timing.csv` includes `kinduction_depth`, `harness_module`, `harness_lines`,
`harness_asserts`, `harness_assumes` alongside pass/fail/timing columns.

## See also

- `../../testbench.md`: the cycle-equivalence case studies and the copy
  behaviour of their scripts.
- `../../synthesis/README.md`: the Yosys synthesis case studies.
