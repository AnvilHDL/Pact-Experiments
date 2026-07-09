# `axi_demux` — full cycle-by-cycle protocol (port-wire view)

One AXI4+ATOP subordinate-facing port in (`slv_req_i`/`slv_resp_o`, plus two
extra input wires `slv_aw_select_i`/`slv_ar_select_i` that are not part of
AXI4 itself), `NoMstPorts` AXI4+ATOP manager-facing ports out
(`mst_reqs_o[k]`/`mst_resps_i[k]`). This top-level file is a thin wrapper —
one spill register per channel plus a matching spill register on each
`select` wire — around a routing core (`axi_demux_simple`) that is not
itself present in this retained copy; what follows describes the
wire-level contract this wrapper file itself establishes and depends on,
which is also exactly the contract stated in the module's own doc comment
(lines 26-41): W beats are routed according to the `select` recorded
alongside the AW beat they belong to, and B/R responses are multiplexed
back onto the one subordinate port from whichever manager port produced
them.

## AW channel and its `select` side-wire — the two are latched together, not independently

- **`slv_aw_select_i` must be held stable on every cycle `slv_req_i.aw_valid`
  is asserted** — this is a documented requirement on the environment (the
  wrapper interface comment: "has to be stable, when aw_valid"), not
  something enforced by any handshake signal.
- **Every cycle**, the AW payload (`slv_req_i.aw`) and the `select` value
  (`slv_aw_select_i`) each pass through their own spill register, but the
  two spill registers are driven from the *same* `valid_i`
  (`slv_req_i.aw_valid`, wired identically into both) and the *same*
  `ready_i` (`slv_resp_cut.aw_ready`, the routing core's own AW-accept
  wire, wired identically into both). Consequently, the two spill
  registers always advance together, cycle for cycle — there is no cycle
  where one has captured a new beat and the other has not.
- **The combined outward `aw_ready`** (`slv_resp_o.aw_ready`) is the AND of
  both spill registers' own `ready_o` — so a stall internal to either the
  channel-payload path or the select path (e.g. either spill register still
  holding an unconsumed prior beat) holds `aw_ready` low for both together.
- **The combined `aw_valid` reaching the routing core**
  (`slv_req_cut.aw_valid`) is likewise the AND of both spill registers'
  `valid_o` — the routing core never sees an AW beat's payload without
  simultaneously seeing its matching `select` value on `slv_aw_select`, and
  vice versa. From the routing core's perspective, "an AW beat with a
  select" is a single atomic unit on the wire, not two independently timed
  signals.
- **Net effect on this boundary's wires**: whatever cycle `slv_resp_o.aw_ready=1`
  is observed together with `slv_req_i.aw_valid=1`, the environment's
  `slv_aw_select_i` value on that exact cycle is the one that will
  determine, downstream, which manager port's W channel is fed the
  following W beats for this transaction (per the AR/AW-select contract
  the routing core is documented to implement — not itself traceable on
  these wires, since the routing core's internals are not in this file).

## AR channel and its `select` side-wire

Structurally identical to AW: `slv_ar_select_i` must be held stable
whenever `slv_req_i.ar_valid=1`; the AR-payload spill register and the
AR-select spill register share the same `valid_i`/`ready_i` pair
(`slv_req_i.ar_valid` / `slv_resp_cut.ar_ready`), so they always advance
together and the combined `slv_resp_o.ar_ready` only ever fires when both
have room.

## W channel — routed on the far side of this wrapper, not visible here

`slv_req_i.w_valid`/`slv_resp_o.w_ready` pass through one more spill
register (`slv_req_cut.w_valid`/`slv_resp_cut.w_ready`) into the routing
core exactly as-is, with no `select` companion wire of its own — per the
documented contract, the routing core is expected to already know, from
the AW-and-select pair it received earlier (in AW-beat order), which
manager port each subsequent W beat belongs to. Nothing on this wrapper's
own W-channel wires carries or re-asserts a `select` value; the ordering
dependency ("the routing core must have already seen this transaction's AW
beat, together with its select, before this transaction's W beats arrive")
is a contract on the environment presenting `slv_req_i`, not something this
wrapper's wires check or enforce.

## B / R channels — multiplexed back from whichever manager port answers

`slv_resp_cut.b_valid`/`b`/`slv_req_cut.b_ready` (already multiplexed down
to one stream by the routing core, from whichever of the `NoMstPorts`
manager ports the core selected) pass through one more spill register
before appearing on `slv_resp_o.b_valid`/`b`, gated by the environment's
own `slv_req_i.b_ready`. R is the exact mirror. Nothing about *which*
manager port a given B or R beat originated from is visible on these two
wires or on any signal this wrapper exposes — that demultiplexing (and
whatever id/order bookkeeping it requires) happens entirely inside the
routing core, upstream of these two spill registers.

## Row 3 — AW/W realignment, and why it is open

**What this wrapper's own wires commit to**: nothing prevents the
environment from presenting `slv_req_i.w_valid=1` beats before that
transaction's `slv_req_i.aw_valid`/`slv_aw_select_i` pair has even been
accepted — the W-channel spill register chain here has no dependency on
the AW/select chain's state, and will happily forward whatever `w_valid`
the environment offers, cycle for cycle, regardless of AW's progress. The
*routing core* downstream is documented (design-overview comment) to rely
on the opposite: that W bursts arrive in the same order as their AW beats,
so it can determine which manager port to route a W beat to purely from
having already recorded that transaction's `select`. Nothing on this
wrapper's boundary wires enforces that assumption; it is not visible at
all whether a given `w_valid` beat's transaction has already had its AW
beat accepted.

**Where the openness comes from**: whether presenting W before its
matching AW is actually safe is entirely a property of what the
environment on the `slv_req_i` side chooses to do. An environment (a
manager, or the composition of an upstream mux/arbiter feeding this
demux) that always completes an AW handshake before ever asserting the
matching W beat composes safely with the documented routing assumption.
An environment that is free to present `w_valid=1` first — which AXI4
itself permits, since AW and W are independently handshaked channels with
no ordering requirement between them — exposes exactly the row-3 hazard:
the routing core has no recorded `select` yet to route that early W beat
to. This wrapper's own wires make no commitment either way; whether the
whole system is safe depends on which kind of environment is attached to
`slv_req_i`, which is exactly the environment-quantifier the open setting
is about.
