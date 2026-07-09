# PACT — open-setting analysis of 12 real communicating components

This document accompanies `originals/`, which holds **unmodified upstream RTL**
for each of the 12 table rows. Nothing here is simplified or reconstructed
except where a row is explicitly marked *class-representative* (no single
upstream module exists). For every row we keep the component **open**: its
boundary interface is exposed and the environment is left unspecified — exactly
PACT's *open design* view, where the type states the contract expected *from the
interfacing environment* rather than closing the system with a testbench.

No environment is simulated. The point is not to run the whole SoC to a
deadlock; it is to show, per component, the implicit protocol contract on its
boundary and the inconsistency a PACT open type would expose against a peer.

### Legend

**Provenance**
- `FILED` — a filed upstream issue with the offending code.
- `DOCUMENTED` — a real, named component + a documented protocol rule it can violate.
- `CLASS` — representative of a documented class; no single pinned upstream bug (verify before citing).

**Mismatch kind (taxonomy)**
- `missing` — a required boundary action is never offered.
- `order` — actions are offered, but in an order the peer does not admit.
- `timing` — right actions and order, wrong cycle (stability / same-cycle-vs-delayed).

**Setting**
- `closed-pairwise` — the two interfaces alone decide compatibility; no environment can rescue it.
- `open` — compatibility genuinely depends on the boundary environment (the Player-0 vs Player-1 game of §2.6).

All commits pinned below are the `HEAD` of `master` at fetch time.

| repo | commit |
|------|--------|
| pulp-platform/adv_dbg_if | `c4d7aa177ef96b0fdff8748f81bd15489446c95a` |
| pulp-platform/axi | `e55ae2a7ee606ee3cfd4257f63982a971b704407` |
| ZipCPU/wbuart32 | `f43a6b83c3a70fb2ac0696a45c5545b233fb860b` |
| alexforencich/verilog-axis | `48ff7a7e2ef782cf778d47910cf85835c64b1bce` |
| pulp-platform/ace | `f919f5cabf41961321bf37327ab4eb726dfdbd0c` |
| pulp-platform/culsans | `a3d741600d03bba2f21b795eda4f6faf7124a152` |

---

## Row 1 — Debug BIU: `WVALID` gated on `AWREADY`
- **Retained component:** `originals/adbg_axi_biu.sv` (571 lines), `pulp-platform/adv_dbg_if`.
- **Provenance:** `FILED` — pulpino issue #182. **Kind:** `order`. **Setting:** `closed-pairwise`.
- **Where:** write-response FSM, lines ~509–545. Defaults `axi_master_aw_valid=0; axi_master_w_valid=0` (509–510); the branch `if (wr_reg && axi_master_aw_ready && !axi_master_w_ready)` (535) and the later `axi_master_w_valid = 1'b1; if (axi_master_w_ready) ...` (544–545) sequence the write so that data progress is conditioned on the address handshake state.
- **Open boundary:** `{aw_valid!, aw_ready?, w_valid!, w_ready?, b_valid?, b_ready!}` toward an AXI subordinate that is otherwise unspecified.
- **Implicit contract (buggy side):** "I will not settle `W` until I have observed the `AW` handshake." AMBA forbids exactly this: a manager's `VALID` must not depend on the peer's `READY`.
- **Inconsistent with:** any spec-legal subordinate that waits for `AWVALID && WVALID` before `AWREADY`.
- **PACT open type:** the local type sends `aw!` and can only reach `w!` after the environment supplies `aw?` — i.e. `w!` is guarded by an environment action. The compatibility check asks whether *some* environment offers `aw?` before `w?` is needed; a subordinate whose type requires `w?` first has no such witness, so the open check reports the pair incompatible with **no** residual type. Closed-pairwise: quantifying over environments cannot fix it.

## Row 2 — Verification driver imposes `AW`→`W` acceptance order
- **Retained component:** `originals/axi_test.sv` (2856 lines), `pulp-platform/axi`.
- **Provenance:** `FILED` — pulp-platform/axi issue #21. **Kind:** `order`. **Setting:** `closed-pairwise`.
- **Where:** `task send_aw` (80, 374) contains `while (axi.aw_ready != 1) begin cycle_end(); cycle_start(); end` (88, 391); `task send_w` (96, 409) runs only after `send_aw` returns (see `send_aws`/`send_ws` at 1233–1276). So the driver serialises: accept `AW`, *then* issue `W`.
- **Open boundary:** the driver is the environment for a DUT crossbar; boundary is the AXI write channels.
- **Implicit contract:** the driver *assumes* a DUT that accepts `AW` before `W` is offered. A spec-compliant crossbar may legally wait for `WVALID` before `AWREADY`.
- **Inconsistent with:** correct crossbars — this is a **false negative**: the environment rejects good silicon.
- **PACT open type:** interesting because here the *environment* type is the inconsistent one. PACT types the driver's offered boundary strategy; the check shows no DUT satisfying the standard write-channel type can also satisfy this driver's ordering assumption. Same shape as Row 1, opposite blame — useful for the talk's "the bug can live in the checker's environment model" point.

## Row 3 — Demux must realign `AW`/`W`; early `W` has nowhere to go
- **Retained component:** `originals/axi_demux.sv` (302 lines), `pulp-platform/axi`.
- **Provenance:** `DOCUMENTED` (AMBA realign rule; habr/vlsiverify). **Kind:** `order`. **Setting:** `open`.
- **Where:** `slv_aw_select_i` (70) chooses the destination from the **AW** stream; `SpillAw=1` vs `SpillW=0` (56–57) and the AW spill register (89–92) mean W is routed by the *decoded AW select*. If `W` arrives before its `AW` is decoded, there is no select yet.
- **Open boundary:** one subordinate-side write pair in, `N` manager-side pairs out; the select is a boundary input.
- **Implicit contract (component assumes):** "the environment presents `AW` (so I can compute the route) no later than `W`." A manager is legally allowed to present `W` first.
- **Inconsistent with:** a manager whose type emits `w!` before `aw!`.
- **PACT open type:** this one *needs* the open setting. The demux's local type consumes `aw?` to fix an internal select, then consumes `w?`. Whether the composition is safe depends on the environment's ordering of `aw!`/`w!` — a boundary strategy that always presents `aw` first is a winning witness; one that may present `w` first is not. That's precisely the environment-quantifier the game decides, and the residual type records the realignment obligation.

## Row 4 — AXI-Stream `TLAST`/framing under backpressure
- **Retained component:** `originals/axis_fifo.v` (566 lines), `alexforencich/verilog-axis`.
- **Provenance:** `DOCUMENTED` (zipcpu; Xilinx AXIS template / Ethernet-Lite). **Kind:** `timing`. **Setting:** `closed-pairwise`.
- **Where:** "Propagate tlast" (47), `GEN_FRAME`/`FRAME_FIFO` handling, `s_axis_tready` derivation (217), `m_axis_tlast` (116), `m_axis_tvalid` pipeline (197, 233). This module is *correct*; it is retained to expose the exact boundary where the documented template bug (letting `TLAST`/pointer change while `TVALID && !TREADY`) manifests.
- **Open boundary:** `{s_axis_tvalid?, s_axis_tready!, s_axis_tlast?, ...}` on the sink side; `{m_axis_tvalid!, m_axis_tready?, m_axis_tlast!}` on the source side.
- **Implicit contract:** "nothing changes unless `!TVALID || TREADY`." A source that advances framing during a stall breaks it.
- **Inconsistent with:** a source whose `tlast!`/data moves on a stalled cycle.
- **PACT open type:** a `timing` mismatch — the type must pin `tlast!` to the same clock step as the accepted beat. The stability obligation is a same-cycle constraint on the boundary; PACT's clock-cycle-explicit types capture "held during stall" that untyped RTL leaves implicit.

## Row 5 — `AWID` reused before prior `B` response
- **Retained component:** `originals/axi_test.sv` (manager + monitor), `pulp-platform/axi`.
- **Provenance:** `CLASS` (AMBA ordering rule; vlsiverification). **Kind:** `order`. **Setting:** `open`.
- **Where:** the random manager and the `axi_monitor`/scoreboard logic in `axi_test.sv` track per-ID outstanding transactions; the hazard is a manager reusing an in-flight `AWID` before its `B` completes. No single filed bug — retained as the real component that *defines and checks* the per-ID ordering contract.
- **Open boundary:** write-issue side, with `awid` as part of each `aw!`.
- **Implicit contract:** "all transactions with a given `ID` complete in order." Reusing an ID mid-flight makes the response↔request mapping ambiguous.
- **Inconsistent with:** a subordinate/interconnect that assumes at most one outstanding transaction per ID.
- **PACT open type:** the ID becomes part of the message label; the type tracks at-most-one-outstanding-per-label as a boundary obligation. Open because whether reuse is safe depends on the environment's response-ordering guarantees.

## Row 6 — Crossbar: circular wait across the fabric
- **Retained component:** `originals/axi_xbar.sv` (252 lines), `pulp-platform/axi`.
- **Provenance:** `DOCUMENTED` (Xilinx/fpgaemu reorder deadlock; mirrors **paper Fig. 2**). **Kind:** `order`. **Setting:** `open`.
- **Where:** the xbar wires `NoMst × NoSlv` demux/mux instances; the deadlock is emergent from per-ID in-order response coupling across managers, not a single line.
- **Open boundary:** all manager and subordinate ports; the "environment" is the set of attached masters/slaves and their acquisition order.
- **Implicit contract:** each path is locally fine; globally, opposite acquisition orders + in-order response coupling create a cycle.
- **Inconsistent with:** itself, under an environment that drives the crossed request pattern — the exact liveness failure of the paper's Worker/Arbiter example.
- **PACT open type:** the flagship **liveness** case that *needs* the game. No stuck handshake exists; the type-level check must ask whether some boundary schedule keeps all progress markers live under every internal resolution. Closed model checkers hit state explosion here (this is your RQ2 story).

## Row 7 — Wishbone: `ACK` never asserted (FSM self-loop)
- **Retained component:** `originals/wbuart.v` (537 lines), `ZipCPU/wbuart32`.
- **Provenance:** `FILED` (litex #572 self-loop repro) + real component `wbuart.v`. **Kind:** `missing`. **Setting:** `closed-pairwise`.
- **Where:** Wishbone slave boundary `i_wb_cyc` (61), `i_wb_stb` (62), `o_wb_stall` (66), `o_wb_ack` (67). `wbuart` is a *correct* slave (it always eventually acks); retained to expose the open Wishbone boundary against which litex #572's slave (which loops in `transfer_state` and never asserts `ack`) is inconsistent.
- **Open boundary:** `{cyc?, stb?, we?, adr?, ack!, stall!, dat!}`.
- **Implicit contract:** "every accepted `(cyc & stb)` is eventually answered by `ack!`."
- **Inconsistent with:** a slave FSM that receives `cyc/stb` but whose type has no path to `ack!` — a *missing* boundary action.
- **PACT open type:** the local type must offer `ack!` on every branch reachable after `cyc?&stb?`; a type with an `ack`-free loop fails satisfiability. Non-AXI, showing the approach is protocol-agnostic.

## Row 8 — Wishbone 32→8 downconverter: byte-lane ordering
- **Retained component:** `originals/wbuart.v` (as the 8-bit-style WB peripheral boundary), `ZipCPU/wbuart32`.
- **Provenance:** `CLASS` (litex #572 downconverter symptom). **Kind:** `order`. **Setting:** `closed-pairwise`.
- **Where:** the byte-lane/`sel` handling on the Wishbone boundary; the documented symptom is a converter that assembles sub-word beats in a lane order the slave does not use ("upper three bytes read zero").
- **Open boundary:** the narrow-side `{stb?, sel?, adr?, dat?, ack!}`.
- **Implicit contract:** "the N sub-beats map to byte lanes in the agreed order."
- **Inconsistent with:** a width converter whose beat/lane sequence differs from the slave's.
- **PACT open type:** the lane index is part of the message label; an ordering mismatch is a label-sequence mismatch the type check catches. (Representative — the upstream artifact is Python/migen, so `wbuart.v` stands in for the real narrow-side boundary.)

## Row 9 — ACE CCU: snoop responses reordered vs. FIFO assumption
- **Retained component:** `originals/ccu_fsm.sv` (705 lines) + `ace_intf.sv`, `snoop_intf.sv`, `ace_pkg.sv`, `snoop_pkg.sv`, `pulp-platform/ace`; instantiated by `originals/culsans_top.sv` (`ace_ccu_top_intf i_ccu`, lines ~683–690).
- **Provenance:** `DOCUMENTED` (Culsans, arXiv 2407.19895). **Kind:** `order`. **Setting:** `open` (multi-party).
- **Where:** `ccu_fsm.sv` snoop ports `s2m_req_o`/`m2s_resp_i` (29–30), `cr_valid` (59), states incl. `WAIT_RESP_R` (44). The paper notes snoop channels carry **no transaction ID**, so a FIFO preserves initiator order; if `CR`/`CD` come back in another order, attribution breaks.
- **Open boundary:** `AC` (snoop request out), `CR`/`CD` (snoop response in) per core, plus the initiator `R` channel.
- **Implicit contract:** "`CR` responses arrive in the order `AC` requests were issued." No ID means order *is* the identity.
- **Inconsistent with:** a core (or interconnect) whose type emits `cr!` out of issue order.
- **PACT open type:** the ordering FIFO is exactly a residual-type obligation on an ID-less channel; the open check asks whether some environment keeps `cr?` in FIFO order under all internal snoop resolutions. Closest match to a real benchmark you already evaluate (ACE).

## Row 10 — Coherent master: writeback vs. incoming snoop race
- **Retained component:** `originals/ccu_fsm.sv` (+ `ace_intf.sv`), `pulp-platform/ace`.
- **Provenance:** `CLASS` (deadlock-avoiding coherent interconnect, US9372808; coherence literature). **Kind:** `order`/race. **Setting:** `open`.
- **Where:** the CCU FSM's interleaving of memory-unit writeback handling and snoop-unit response; the documented hazard is a master issuing a writeback for line X as a snoop for X arrives, each waiting on the other absent a non-blocking channel.
- **Open boundary:** writeback path (`W`/`B` toward memory) and snoop path (`AC`/`CR`/`CD`) for the same line.
- **Implicit contract:** "a writeback in flight must not block a snoop response, and vice versa."
- **Inconsistent with:** a peer whose type makes `cr!` (snoop response) wait on the writeback's completion while the writeback waits on the snoop.
- **PACT open type:** a two-channel cyclic dependency; the open check must find a boundary strategy that interleaves the two channels without a cycle — the residual type is the "needs a non-blocking channel" obligation the patent adds by construction.

## Row 11 — AXI IP vs. interconnect: reorder/drop/silent-fail (eXpect)
- **Retained components:** `originals/axi_demux.sv`, `originals/axi_mux.sv`, `pulp-platform/axi` (the PULP AXI IPs eXpect tested).
- **Provenance:** `CLASS`/aggregate — eXpect, ICCAD'24 (135 violations across 7 IPs incl. AMD Xilinx + RISC-V PULP). **Kind:** `order`. **Setting:** `open`.
- **Where:** response-path arbitration in `axi_mux.sv` (`slv_r_chans`/`slv_b_chans` muxing, ~160–162) and select steering in `axi_demux.sv`; eXpect's exploitable cases are stalling / dropping / **reordering** responses.
- **Open boundary:** manager-side and subordinate-side channels of a real interconnect IP.
- **Implicit contract:** "every response is delivered, once, with the ID/order the manager expects."
- **Inconsistent with:** a subordinate/manager whose type reorders or drops a labelled response.
- **PACT open type:** `RID`/`BID` as labels; reorder = label-order mismatch, drop = a `missing` boundary action. Representative of the *aggregate* eXpect findings rather than one pinned bug — flagged for provenance.

## Row 12 — AXI same-ID in-order response → cyclic deadlock
- **Retained component:** `originals/axi_mux.sv` (598 lines), `pulp-platform/axi`.
- **Provenance:** `DOCUMENTED` (deadlock-freedom thesis, diva-portal:1510046). **Kind:** `order`. **Setting:** `open`.
- **Where:** the mux serialises responses and must preserve per-ID order across subordinates (B/R channel arbiters, ~34–39, 100–162). The thesis shows IDs/slaves blocking each other in a "non-trivial waiting cycle."
- **Open boundary:** several subordinate response streams in, one ordered manager stream out.
- **Implicit contract:** "same-`ID` responses leave in issue order." A fast subordinate's response is held behind a slow one; if the slow one's completion depends (via shared buffering/credit) on the held response being consumed, the order rule *creates* the cycle.
- **Inconsistent with:** an environment where the in-order constraint and the resource dependency close a loop.
- **PACT open type:** the ordering constraint is a type-level sequencing of labelled responses; the open check decides whether some boundary schedule satisfies both the ordering and progress. Distinct from Row 6 in that the cycle is induced by the *ID-ordering rule itself*, not by resource holding.

---

## How to use these

- Each `originals/<component>/<component>.sv|.v` is the **real, open** component —
  drop it into a linter/elaborator (Verilator `--lint-only`, or `iverilog -g2012 -y`
  with the repo's include path) to confirm it is the genuine article; do **not**
  close it with a driving testbench (that defeats the open-setting point).
- The PACT-side artifact per row is the pair (local type of this component,
  environment type it requires). Rows 3, 5, 6, 9, 10, 11, 12 are the ones that
  exercise the environment quantifier / game; rows 1, 2, 4, 7, 8 are decided
  pairwise and showcase modular local checking. Four components
  (`adbg_axi_biu`, `axi_test`, `ccu_fsm`, `axi_mux`) currently carry a
  hand-authored `type_<component>.anvil` alongside the source, in the same
  syntax as `src/compat/type_*.anvil` — see `README.md`'s "PACT `.anvil` types"
  section for which rows each one encodes.
