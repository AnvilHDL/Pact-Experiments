# `axis_fifo` — full cycle-by-cycle protocol (port-wire view)

Two independent AXI-Stream boundaries on the same shared clock: a sink side
(`s_axis_*` in, `s_axis_tready` out) and a source side (`m_axis_*` out,
`m_axis_tready` in), plus a `pause_req`/`pause_ack` side-channel and
free-running `status_*` outputs. This component is documented in
ANNOTATIONS.md as *correct* (row 4's `DOCUMENTED` provenance is the general
AXI-Stream backpressure template rule this component satisfies, not a bug in
this file itself) — the point of retaining it is to show the wire-level
discipline a *stable* AXI-Stream source/sink must follow, against which a
buggy source (elsewhere) can be judged. An internal `State` — how many
words are currently buffered, tracked as a pointer/pointer-difference — is
referred to below only where the wires' behavior can't be explained without
it; the exact storage mechanism is not otherwise part of the boundary
contract.

## Sink side wires: `s_axis_tdata`/`tkeep`/`tlast`/`tid`/`tdest`/`tuser`/`tvalid` in, `s_axis_tready` out

- **`s_axis_tready`** is driven combinationally, every cycle, from whether
  `State` currently has room for one more word (not FRAME_FIFO mode) — it is
  not itself latched or held; it can go from 1 to 0 or 0 to 1 on any cycle
  purely as a function of how full the internal storage is.
- **A beat is accepted on any cycle where `s_axis_tvalid=1` AND
  `s_axis_tready=1` are observed together** — on exactly that cycle, the
  environment's `s_axis_tdata`/`tkeep`/`tlast`/`tid`/`tdest`/`tuser` values
  are captured into `State`; no other cycle captures anything, regardless
  of what `s_axis_tvalid` or the payload wires are doing.
- **On every cycle where `s_axis_tvalid=1` but `s_axis_tready=0`** (this
  component is stalling the sink), nothing is captured — the environment on
  this side is expected to hold `s_axis_tdata`/`tkeep`/`tlast`/`tid`/
  `tdest`/`tuser` unchanged until `s_axis_tready` returns to 1 (this is the
  standard AXI-Stream source-side stability rule the whole file exists to
  exhibit correctly — see below); this component's own sink-side wires
  neither check nor depend on the environment actually doing so, they
  simply do not consume anything on a stalled cycle.
- **`s_axis_tready` can be 1 with no `s_axis_tvalid`**: no beat is accepted
  that cycle, and no state changes on the sink side.

## Source side wires: `m_axis_tdata`/`tkeep`/`tlast`/`tid`/`tdest`/`tuser`/`tvalid` out, `m_axis_tready` in

- **This is the stability-critical side.** Once `m_axis_tvalid=1` is
  presented on some cycle with a specific payload
  (`tdata`/`tkeep`/`tlast`/`tid`/`tdest`/`tuser`), that exact payload is
  held completely unchanged, cycle after cycle, for as long as
  `m_axis_tvalid=1 && m_axis_tready=0` continues — the payload only ever
  changes on the cycle immediately *after* a cycle where
  `m_axis_tvalid=1 && m_axis_tready=1` was observed together (a beat
  closed). There is no cycle where `m_axis_tvalid` stays 1 but the payload
  changes without a preceding accepted handshake — this is the "nothing
  moves while stalled" discipline row 4 is about.
- **`m_axis_tvalid` itself can only fall on the same cycle a beat closes**
  (`tready` was 1 that cycle) or on reset — it never falls while a beat is
  being held for lack of `m_axis_tready`.
- **After a beat closes**, the next cycle either presents the next buffered
  word (if `State` has one ready) with `m_axis_tvalid=1` again, or drops
  `m_axis_tvalid=0` if nothing is buffered (a bubble) — a bubble cycle
  itself may present stale/don't-care payload wires, since `tvalid=0`
  means the environment must not sample them.
- **`m_axis_tready`** is driven entirely by the environment on this side;
  this component places no constraint on how it varies cycle to cycle
  (may go 1↔0 freely, including while `m_axis_tvalid=0`).

## Pause side-channel

- **`pause_ack`** mirrors an internal pause latch that, when driven by
  `pause_req`, forces `m_axis_tready_out`/`m_axis_tvalid` toward 0 on the
  source side regardless of what would otherwise be presented — with
  `FRAME_PAUSE` set, the pause latch will not actually take effect
  mid-frame: once a source-side beat has been presented
  (`m_axis_tvalid_out=1`) without yet reaching one with `tlast=1` accepted,
  the pause request is held off, cycle by cycle, until that frame's closing
  `tlast` beat has been accepted; only then does `pause_ack` reflect a
  currently-asserted `pause_req`. Without `FRAME_PAUSE`, `pause_ack` simply
  tracks `pause_req` one cycle later, with no regard for frame boundaries.

## Status outputs

`status_depth`/`status_depth_commit` are free-running, combinationally
derived every cycle from the same `State` (word counts); `status_overflow`/
`status_bad_frame`/`status_good_frame` are each single-cycle pulses,
asserted for exactly one cycle whenever the corresponding sink-side
condition (buffer full and a frame is dropped / a bad frame's `tlast` is
accepted while configured to detect it / a good frame's `tlast` is
accepted) occurs, and forced back to 0 every other cycle regardless of what
caused the pulse.

## Row 4 — the documented bug class this boundary exposes, and why it's about timing, not order

**What this component's own wires guarantee**, restated as the two rules a
compliant peer on either side must also follow: (1) a sink must not let
`s_axis_tready` retroactively invalidate a beat it already accepted — not
applicable to *this* component's own inputs, but the shape a downstream
sink must match; (2) **a source must hold `tvalid` and every payload wire
completely unchanged across any cycle where its beat was offered but not
accepted** — this component itself upholds rule (2) on its own `m_axis_*`
port, exactly as described above.

**The documented bug (elsewhere, not in this file)**: a source that instead
advances its internal read pointer, or re-samples `tlast`/data from a
changing internal state, on a cycle where `m_axis_tvalid=1 &&
m_axis_tready=0` — i.e. presents beat A on one stalled cycle and a
different beat A′ (different `tdata` and/or `tlast`) on the very next
stalled cycle of what the receiver believes is still the *same*
unaccepted handshake. Composed with a receiving sink like this file's own
sink side — which only ever samples payload wires on the cycle it actually
asserts `tready=1`, and otherwise assumes whatever is being held is
unchanged — that receiver can silently consume the *later* payload while
believing it accepted the *earlier* one (or mis-detect a frame boundary if
`tlast` itself flipped between the two presented cycles). Both the buggy
source and this file's sink demand the same *sequence* of actions
(`tvalid` then eventually `tvalid&&tready`) in the same *order* — the
mismatch is purely about whether the payload is allowed to change on an
intermediate stalled cycle, i.e. a same-cycle stability/timing obligation,
not an ordering obligation between different named actions. That is why
ANNOTATIONS.md classifies this row's mismatch kind as `timing` rather than
`order`, and why it is `closed-pairwise`: no environment can make a
retroactively-changing source safe to compose with a sink that samples once
per accepted beat — the fix has to be local to the source's own per-cycle
discipline, matching what this file's own `m_axis_*` side already does
correctly.
