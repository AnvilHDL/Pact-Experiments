# `axi_mux` — full cycle-by-cycle protocol (port-wire view)

`NoSlvPorts` AXI4 subordinate-facing ports in (`slv_reqs_i[k]`/
`slv_resps_o[k]` — each a full `aw_valid`/`ready`, `w_valid`/`ready`,
`b_valid`/`ready`, `ar_valid`/`ready`, `r_valid`/`ready` set, with `id`
fields on `aw`/`ar`/`b`/`r`), one AXI4 manager-facing port out
(`mst_req_o`/`mst_resp_i`, same signal shape, but with wider `id` fields).
Every `aw_id`/`ar_id` value entering from port `k` has `k` prepended to it
before appearing on `mst_req_o.aw.id`/`.ar.id`; every `mst_resp_i.b.id`/
`.r.id` has its top bits stripped back off to decide which port `k` it is
routed back to. Below is only the `NoSlvPorts>1` case — with exactly one
port, everything is wired straight through with no arbitration at all.

An internal `State` (which of the `NoSlvPorts` ports currently "owns" the
write-data channel) governs the W channel; it is named generically here
because only its effect on the wires — which port's `w_valid`/`w_ready` are
live — is externally observable, not any implementation detail of how that
ownership is tracked.

## AW channel wires

- **Every cycle**, each port `k` with `slv_reqs_i[k].aw_valid=1` is a
  candidate. At most one port's `aw_ready` is ever driven high on a given
  cycle — the module picks one candidate (round-robin across cycles: a
  port that was picked but not yet closed keeps being picked over others
  until its `aw_valid`/`aw_ready` actually close together; a port that
  loses one cycle is reconsidered fairly against the others on later
  cycles). No two ports ever see `aw_ready=1` on the same cycle.
- **The moment a port `k` is picked** (whether or not `mst_req_o.aw_ready`
  is high yet) — this is a wire-visible commitment even before `k`'s own
  `aw_ready` fires: from that cycle's decision onward, the identity of
  which port owns the *next* slot on the W channel is fixed to `k`. This
  can happen strictly before `slv_resps_o[k].aw_ready` itself is ever
  observed 1, if `mst_req_o.aw_ready` (the far side accepting) is not yet
  high — the port-selection decision and the actual handshake closing on
  port `k`'s own `aw_ready` wire are two different cycles in that case.
- **`mst_req_o.aw_valid`** is driven 1 from the cycle a port is picked,
  holding that port's (index-prepended) address payload unchanged, until
  `mst_resp_i.aw_ready=1` closes it — at which point, same cycle,
  `slv_resps_o[k].aw_ready` (the picked port's own ready) also pulses 1.

## W channel wires — ownership handed off from the AW pick, not from the AW close

- **From the cycle a port `k` is picked on AW** (see above — this can be
  before `slv_resps_o[k].aw_ready` itself fires), port `k` becomes the
  *only* port whose W channel is live: `mst_req_o.w_valid` is driven
  directly from `slv_reqs_i[k].w_valid`, `slv_resps_o[k].w_ready` directly
  from `mst_resp_i.w_ready`, and every other port's `w_ready` is held at 0
  regardless of that port's own `w_valid`. So a port whose W beats are
  ready to go can start moving through this channel even while that same
  port's own `aw_ready` has not yet been observed — the two channels are
  decoupled on the wire from the moment of the arbitration pick onward, not
  from the moment AW itself closes.
- **This ownership persists across possibly many W beats**: it is not
  released back to "pick a new port" until a beat closes
  (`w_valid&&w_ready` together) on the owning port's W channel with
  `w.last=1` on that beat. Until then, every other port's `w_ready` stays 0
  even if that port's own `aw_valid` was already accepted (queued) in the
  meantime — at most one port's W beats are ever visible on
  `mst_req_o.w_valid`/`w.data` at a time, in the order those ports were
  picked on AW, one full burst (ending in `w.last`) before the next.
- **If no port has yet been picked and is still owed its W burst**,
  `mst_req_o.w_valid=0` and no port's `w_ready` is asserted at all — the
  W channel is simply idle.

## B channel wires

- **`mst_resp_i.b_valid`/`b.id`/`b.resp`** are broadcast identically toward
  every port's `slv_resps_o[k].b_valid` input logic, but only the one port
  `k` whose index is encoded in `b.id`'s top bits ever actually sees
  `slv_resps_o[k].b_valid=1` — every other port's `b_valid` is held 0 that
  cycle. `mst_req_o.b_ready` is driven from whichever single port `k`
  matches that cycle's `b.id` — i.e. `b_ready` toward the far side depends
  on the `b.id`-selected port's own `b_ready`, not on any other port's.
  Only one B beat is visible on this whole channel at a time (a beat holds
  until the addressed port's `b_ready` closes it).

## AR / R channel wires

- **AR**: identical shape to AW's own selection wires (one port picked per
  cycle among those asserting `ar_valid`, at most one `ar_ready` high per
  cycle, round-robin-fair across cycles) — but with **no companion data
  channel to decouple**, since AR has no R-side ownership handoff the way
  AW hands off W ownership: the picked port's `ar_valid`/address are simply
  held until `mst_req_o.ar_ready` fires, same-cycle closing that one port's
  own `ar_ready`.
- **R**: exactly the same shape as B — `mst_resp_i.r_valid`/`r.id`/`r.data`/
  `r.last` broadcast, only the `r.id`-selected port ever sees `r_valid=1`,
  that same port's own `r_ready` is the only one that can close it. One R
  beat visible at a time; a multi-beat burst is delivered to whichever port
  its `id` selects, beat by beat, for as many beats as `r.last` takes to
  appear.

## Row 11 — response reorder/drop, and why it is open

**What this module's own wires commit to**: B and R beats are routed purely
by the index bits already embedded in `b.id`/`r.id` — this module does not
itself reorder anything relative to what arrives on `mst_resp_i`; it is a
transparent, same-cycle demultiplexer keyed on those bits. It also never
drops a beat on its own initiative: every `mst_resp_i.b_valid`/`r_valid`
beat is presented to exactly the one port its `id` selects and held there
until that port's own `ready` closes it.

**Where the openness comes from**: whether a manager-side observer ever
actually sees a beat "reordered" or "dropped" is not decided by this
module's wires alone — it is decided by what the attached subordinate (on
`mst_req_o`/`mst_resp_i`) does with the `id`-prepended requests this module
forwards. If that subordinate returns `b_id`/`r_id` values that do not
correspond to any request this module actually forwarded with that id-prefix
(or silently never returns a response for some accepted request), the
mismatch shows up as this module apparently "losing" or "misrouting" a
beat, even though its own routing logic is a faithful function of whatever
`id` arrives. The correctness of the whole path is therefore a property of
this mux **together with** whichever subordinate is attached — a
well-behaved subordinate that always eventually answers every accepted
request exactly once, with the same `id` it was given, composes safely;
one that does not exposes exactly this row's hazard, and no change to this
module's own wire behavior can locally rule that out.

## Row 12 — same-ID in-order delivery causing a wait cycle, and why it is open

**What this module's own wires commit to**: for two ports whose B (or R)
beats are simultaneously pending with the *same* prepended `id` region —
which cannot actually happen here directly, since this module prepends a
distinct port index to every `id`, so two different ports' beats can never
collide on `b.id`/`r.id` at this module's own boundary. The in-order
constraint this row is about therefore is not something this module's wires
enforce between its own ports; it is a constraint the module *assumes* the
attached subordinate already upholds for whatever original (pre-prepend)
`id` values reach it from a single port, and the module's own B/R
broadcast-and-select wires simply pass that ordering through unchanged
(same-`id` beats from `mst_resp_i` are presented to the selected port in
the order they arrive on `mst_resp_i`, with no reordering buffer of any
kind on this side).

**Where the openness comes from**: the hazard is upstream of this module's
own boundary — in whatever produced the traffic on the port that shares an
`id` across multiple outstanding transactions to the same subordinate. If a
fast-completing transaction's B/R beat is, from the subordinate's own
internal view, held back behind a same-`id` transaction that is slow to
complete, and that slow transaction's own completion depends (through some
resource shared with the requester, e.g. limited buffering or credit) on
the fast transaction's beat having already been drained — a dependency this
module's own wires have no visibility into — the ordering rule the
subordinate upholds can itself become the reason nothing on the shared W
or R channel ever moves again. This module's wires do not create that
dependency, but they also do nothing to break it: they simply present
whatever order the subordinate produces, unchanged, to the one port that
`id` selects. Whether the overall system deadlocks is therefore a property
of this mux **together with** the specific subordinate and requester
behavior on the other two boundaries, not of this module's own port-level
routing in isolation — the same open, environment-dependent shape as row 11,
but driven by a resource cycle rather than a mis-set `id`.
