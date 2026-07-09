# `ccu_fsm` — full cycle-by-cycle protocol (port-wire view)

Three port groups: the initiator-facing ACE port (`ccu_req_i`/`ccu_resp_o` —
`ar_valid`/`ar_ready`, `aw_valid`/`aw_ready`, `w_valid`/`w_ready`,
`r_valid`/`r_ready`/`r_last`, `b_valid`/`b_ready`), the memory-facing port
(`ccu_req_o`/`ccu_resp_i`, same signal shape), and `NoMstPorts` snoop ports
(`s2m_req_o`/`m2s_resp_i` — `ac_valid`/`ac_ready`, `cr_valid`/`cr_ready`,
`cd_valid`(`m2s_resp_i[*].cd_valid`)/`cd_ready`/`cd_last`, plus the `cr_resp`
payload bits `dataTransfer`, `isShared`, `passDirty`, `error`). One shared
piece of internal `State` (which phase of servicing one request the CCU is
currently in) governs which of these wires can move on any given cycle;
`State` is named generically here because the exact phase names are not
externally observable — only their effect on the wires is.

This module is the flagship **open**-setting example in ANNOTATIONS.md
(rows 9 and 10): everything below describes what the CCU itself commits to
on its wires. Whether that commitment is *safe* is a separate question that
depends on which cores/peers are attached to the snoop ports — that
dependency is spelled out at the end of each row's section, not folded into
the wire description, so the two stay distinguishable.

## Initiator port: accepting one request at a time

- **Cycle by cycle while idle**: `ar_ready` and `aw_ready` are both driven
  low (not simultaneously offered) except in the specific `State` where the
  CCU is ready to latch the *next* request — call it the accepting cycle.
  On an accepting cycle: if `ar_valid=1` is presented (and either
  `aw_valid=0`, or a fairness bit favors read this round), the CCU will
  treat this as the request to service and `ar_ready` pulses 1 one cycle
  later (in the following `State`); symmetrically for `aw_valid` when write
  is favored. Only one of `ar_valid`/`aw_valid` is ever accepted per
  request-service episode — the other, if also asserted, is remembered and
  serviced preferentially next time around (a one-request-deep alternation,
  not a queue).
- **From the accepting cycle until the whole request is fully serviced**
  (which may take many cycles and touch all three port groups, per below),
  `ar_ready` and `aw_ready` both stay low — no second request can be
  accepted while one is in flight.
- **`r_valid`/`r_last`/`r.data` and `b_valid`/`b.resp`** on this port only
  ever move during the response-delivering portion of servicing the current
  request (below); at all other times they are held at their inactive/zero
  value.

## Snoop ports: what goes out and what must come back, per request

For **every** accepted request — read or write, regardless of whether the
initiating core's own snoop port is meant to be skipped — the CCU drives
`ac_valid` toward some subset of the `NoMstPorts` snoop ports (in practice,
every port except the one belonging to the request's own initiator) and
will not proceed past that phase until `ac_ready` has been observed high on
every port it addressed — held individually per port (once a given port's
`ac_ready` is seen, the CCU stops re-driving `ac_valid` to that one port,
but keeps driving it to the others until they too respond). Only once every
addressed port has acknowledged `ac_valid`/`ac_ready` does the CCU move to
waiting on `cr_valid` from those same ports — again held per port: a port
whose `cr_valid` has been seen is not re-polled, but the CCU does not leave
this phase until every addressed port has presented `cr_valid=1` at least
once. Each `cr_valid` beat carries `dataTransfer`, `isShared`, `passDirty`,
`error` — these are latched per port as they arrive.

If, once all `cr_valid` responses are in, **any** port's latched response
had `dataTransfer=1` and `error=0`, the CCU will subsequently drive
`cd_ready=1` toward exactly one of those qualifying ports — whichever one
was first observed to satisfy `dataTransfer&&!error` among the `cr_valid`
beats as they arrived — and pull a stream of `cd_valid`/`cd.data`/`cd.last`
beats from that one port only, until `cd.last=1` has been seen from it.
No other port's `cd_valid` is ever consulted for this request, even if
multiple ports reported `dataTransfer=1`.

## Read request: what appears on the wires after the snoop phase, in words

- If the snoop responses showed no `dataTransfer` anywhere (a clean miss) —
  or this was a "clean unique" / atomic-lock request that only needed the
  invalidate round-trip — the CCU either answers the initiator directly
  (a same-cycle zero-payload `r_valid=1`/`r_last=1` for a plain
  invalidate-only request) or proceeds to the memory port: `ar_valid=1`
  toward memory carrying the *original* request's address/attributes,
  held until `ar_ready=1` from memory, after which `r_ready` toward memory
  is driven directly from the initiator's own `r_ready`, and every
  `r_valid`/`r.data`/`r.last` beat memory produces is copied, same cycle,
  onto the initiator's own `r_valid`/`r.data`/`r.last` — a direct pass
  through, beat for beat, until `r.last=1` closes it.
- If a snoop response did show `dataTransfer=1` (a hit in a peer's cache):
  the CCU streams that peer's `cd_valid` beats (per the snoop-port
  paragraph above) and, **concurrently**, presents those same beats outward
  on the initiator's own `r_valid`/`r.data`/`r.last` — a beat pulled in on
  `cd_valid` does not have to be immediately re-presented on `r_valid` the
  same cycle (a small amount of buffering is allowed to absorb the two
  sides' independent handshake timing), but every beat pulled in is
  eventually presented outward, in the same order, until both sides have
  seen every beat of the line. Once fully drained to the initiator, if this
  was a lock/atomic read, the CCU additionally issues a full writeback
  (`aw_valid` toward memory carrying the whole snooped line, `w_valid`
  streaming the same data, waiting on `b_valid`) before issuing a *fresh*
  `ar_valid`/read to memory to obtain the up-to-date line for the atomic's
  read-modify-write; for a plain (non-lock) hit, no memory traffic happens
  at all — the response is served entirely from the snoop.

## Write request: what appears on the wires after the snoop phase

A write always runs the invalidate round-trip on every addressed snoop
port first (there is no "skip snoop" branch for writes the way there is for
reads). Once all `cr_valid` responses are in: if any port reported
`dataTransfer=1`, the CCU drains that one port's `cd_valid` stream (as
above) and pushes it out on the memory port as a full writeback
(`aw_valid`+`w_valid` sequence, waiting on `aw_ready` then `b_valid`)
*before* proceeding; if no port had data, this writeback is skipped
entirely. Either way, the CCU then issues the original write itself to
memory: `aw_valid` carrying the initiator's own original write address/
attributes, held until `aw_ready`; then, cycle by cycle, `w_valid`/`w.data`/
`w.last` are driven as a direct pass-through of the initiator's own
`w_valid`/`w.data`/`w.last` (and `b_ready` toward memory as a pass-through
of the initiator's own `b_ready`), until memory's `b_valid` closes; `b_valid`/
`b.resp` are then copied back onto the initiator's own `b_valid`/`b.resp`
the same cycle. If the original request was an atomic write with a
read-response component, the CCU continues on into the same memory-read
pass-through behavior described for reads above, before finally returning
to the accepting cycle; otherwise it returns to the accepting cycle
immediately after the write response.

## Row 9 — snoop response order, and why it is open

**What the CCU's own wires commit to**: nothing. The CCU treats whichever
snoop port is first observed to present `cr_valid=1` with `dataTransfer=1
&& error=0` as the data source, purely by *arrival order on the wire that
cycle*, not by any port-index priority or request-issue-order bookkeeping.
The snoop request/response channels (`ac_*`, `cr_*`) carry no transaction-ID
field distinguishing which outstanding request a given response is
answering — there is only ever one request outstanding on these ports at a
time from the CCU's own side (per the "one request at a time" section
above), so from the CCU's perspective there is no ambiguity about which
request a `cr_valid` belongs to.

**Where the openness comes from**: the hazard this row documents lives on
the *other* side of the snoop wires — inside whatever core is attached to
each snoop port. If a core's own internal handling of back-to-back snoop
requests (across multiple different CCU instances, or across a single core
being snooped by requests that themselves raced with that core's own
outbound requests) can present its `cr_valid` responses out of the order
the corresponding `ac_valid` requests reached it, then two different
observers (or two different CCU instances) relying on "the response order
matches the request order" can each build an inconsistent picture of who
has the data. This CCU's own wires make no promise either way about
request-to-response ordering across separate snoop episodes, because it
only ever has one episode outstanding — so whether the overall system is
safe depends entirely on an environment-side guarantee (each core answers
snoop requests in the order it received them) that is not visible on, or
enforced by, any wire this file drives. That is exactly the open
dependency: compatibility is a property of the CCU **together with** a
particular class of well-behaved cores on the snoop ports, not of the CCU's
wires in isolation.

## Row 10 — writeback vs. incoming snoop race, and why it is open

**What the CCU's own wires commit to**: within one request-service episode,
the writeback-to-memory phase (`aw_valid`/`w_valid` toward the memory port,
draining a snooped or to-be-flushed line) and the snoop-request phase
(`ac_valid`/`cr_valid`/`cd_valid` toward the `NoMstPorts` ports) are
strictly sequenced by the shared `State` — the CCU does not simultaneously
run a writeback for one line while also running a fresh snoop invalidate
round for a *different* incoming request, because (per the "one request at
a time" section) it will not even accept a new `ar_valid`/`aw_valid` until
the current episode's writeback and response phases are both complete.

**Where the openness comes from**: this internal seriality is exactly the
hazard from the other direction. Suppose a peer core, itself mid-writeback
of some line X toward *its own* memory path, receives an `ac_valid` snoop
request for that same line X from this CCU (because some other initiator
just requested X). If that peer core's own internal design will not present
`cr_valid` on its snoop-response port until its own in-flight writeback has
fully drained — and this CCU, symmetrically, will not proceed past its
snoop-wait phase (so will not free up to service anything else) until that
same `cr_valid` arrives — the two sides are waiting on each other with
nothing on either side's wires able to break the tie. This CCU's own wire
protocol offers no separate, non-blocking channel that would let a
`cr_valid` response be serviced independently of an in-flight writeback on
the requester side; whether that omission is actually a deadlock depends
entirely on whether the attached peer core's own writeback-vs-snoop
handling has the same non-preemptible seriality or instead keeps its
snoop-response path independent of its own writeback state. Again, the
verdict is a property of this CCU's wires **together with** whatever is
attached to the snoop ports, not of this file alone — the open dependency
the game-theoretic PACT check is meant to resolve.
