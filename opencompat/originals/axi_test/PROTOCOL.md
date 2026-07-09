# `axi_test.sv` — full cycle-by-cycle protocol (port-wire view)

This file is a class library of tasks that drive/monitor an AXI4 bus, not one
module — so "port wires" here means the AXI4 signals the driven interface
exposes (`aw_valid`/`aw_ready`/`aw_id`/`aw_addr`, `w_valid`/`w_ready`/
`w_last`, `b_valid`/`b_ready`/`b_id`, `ar_*`, `r_*`), not any variable
internal to the SystemVerilog classes. Two boundaries matter here: row 2 is
about how one driver's AW and W wires relate to each other cycle to cycle;
row 5 is about what values the AW `id` wire is allowed to carry over time,
and it is the file's one genuinely **open** case — whether a given ID reuse
is safe depends on what the environment on the other side of the bus (the
subordinate/interconnect) guarantees about response ordering, not on the
driver's wires alone.

## Row 2 — the AW/W wire relationship

**Each of the AW, W, AR, R, B channels behaves identically and
independently on the wire**: whichever side is producing a channel drives
that channel's payload fields and `*_valid=1`, holds them completely
unchanged for as many cycles as it takes, and only changes them the cycle
immediately after `*_valid=1` and `*_ready=1` are observed together. There
is nothing in any single channel's own wire behavior that references any
other channel — `w_valid` does not depend on `aw_valid`, `aw_ready`, or
`aw_id`, and vice versa, at the level of one channel handshake in isolation.

The AW/W *relationship* this file actually produces on the wires, across a
run of several back-to-back write transactions, is this: for a given
transaction, an `aw_valid=1` beat carrying that transaction's `id`/`addr`
will appear on the AW channel at some point, and one or more `w_valid=1`
beats (the last with `w_last=1`) belonging to that same transaction will
appear on the W channel at some point — but **the wires give no guarantee
about which appears first**. Concretely: it is possible to observe a cycle
where `w_valid=1`/`w_ready=1` closes a W beat for transaction N while
transaction N's AW beat has not yet even been presented (`aw_valid=0` that
whole time) — nothing on these wires prevents that ordering, and this file's
generator does not avoid it. (This corrects an earlier reading of this file
that assumed AW is always fully driven-and-accepted before the matching W
beats are ever presented — the wires this file actually produces do not
uphold that ordering as a hard rule; W-before-AW for the same transaction is
a reachable trace.)

A single `send_aw` (or `send_w`) invocation is a one-shot wire pattern: drive
the payload and `*_valid=1`, hold unchanged cycle after cycle until
`*_ready=1` is seen on the same cycle, then drop `*_valid=0` the next cycle.
Never re-offer a different beat's payload while `*_valid` is still 1 from a
prior beat — one beat fully closes before the next one's payload appears.
The monitor-side wire behavior (used purely to observe what the driver and
DUT put on the bus, never to drive it) is: watch every channel every cycle,
and treat `*_valid=1 && *_ready=1` together as "this beat happened,"
regardless of who is driving which side.

## Row 5 — what the AW `id` wire is allowed to carry, and why it's open

Ignore, for this section, exactly how many cycles pass between beats — the
question is only: across a sequence of AW beats this driver presents on the
wire, what constraints (if any) hold on the sequence of `aw_id` values, and
what does the wire alone tell an outside observer about which `b_id`
response belongs to which `aw_id` request?

- **AXI4's own wire-level guarantee**: for two beats sharing the same `id`,
  the corresponding `b_valid` responses come back on the B channel in the
  same order the `aw_valid` requests were issued (same-ID responses are
  ordered). AXI4 places **no constraint at all** on `id` reuse: nothing
  says an `aw_valid=1` beat may not carry an `id` that a still-outstanding
  earlier beat (whose `b_valid` has not yet been observed) already used.
- **What this driver's own internal bookkeeping does** (call it `State`: a
  per-`id` outstanding-count and, if configured, an in-flight-ATOP flag,
  updated the cycle an `aw_valid&&aw_ready` (or `ar_valid&&ar_ready`) beat is
  observed to close, and again the cycle the matching `b_valid&&b_ready` (or
  final `r_valid&&r_ready&&r_last`) closes): before presenting any AW/AR
  beat's `id` on the wire, this `State` is consulted. If a mode bit
  (`UNIQUE_IDS`) is set, the driver will **never** present an `aw_valid=1`
  beat whose `id` matches any `id` this same `State` still shows as
  outstanding for a write — it withholds `aw_valid` on that `id` (retrying
  with a different `id` every cycle) until `State` shows that `id` free
  again (i.e. until the matching `b_valid` has been observed). With
  `UNIQUE_IDS` unset (the file's default), `State` is still tracked but is
  **not** consulted to block a reuse — an `aw_valid=1` beat carrying an
  already-outstanding `id` is presented on the wire freely.
- **Why this is the open case, not a closed pairwise one**: whether a trace
  where `aw_id=5` is reused while an earlier `id=5` write is still
  outstanding is *safe* depends entirely on what's on the other end of the
  wire. An environment (subordinate/interconnect) that itself guarantees to
  echo `b_id` responses strictly in the order their `aw_valid` beats closed,
  full stop — regardless of `id` — makes the reuse harmless: a receiver
  watching the wire can still attribute each `b_valid` to the right request
  by position. An environment that reorders responses across different IDs
  but preserves only same-ID order (the AXI4 minimum) makes the reuse
  genuinely ambiguous on the wire: two `b_valid` beats with `id=5` arrive,
  and nothing observable on the B channel says which of the two outstanding
  `id=5` writes each one answers. So the wire trace this driver can produce
  with `UNIQUE_IDS` unset is compatible with some environments and not
  others — this is exactly the setting where the verdict depends on a
  quantifier over the environment's behavior, not on this driver's wires
  and one fixed subordinate's wires alone.
- **Passive observers** (the monitor/scoreboard machinery in this file) only
  ever watch `*_valid&&*_ready` on each channel; they do not drive `aw_id`
  and so cannot themselves create or prevent the row-5 hazard — the reuse
  contract lives entirely in whether the *driving* side's `State` (above) is
  consulted before `aw_valid` is raised.
