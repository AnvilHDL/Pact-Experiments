# `axi_mux` — full cycle-by-cycle protocol

`NoSlvPorts` AXI4 subordinate-facing ports in, one AXI4 manager-facing port
out (naming is from the module's own comment: "multiplexes the AXI4 slave
ports down to one master port" — so "slave ports" here are the ports other
masters attach to, and "master port" is the single upstream/downstream link
to the real subordinate device). Every inbound ID is widened by
`MstIdxBits=$clog2(NoSlvPorts)` bits, prepended with the originating port
index, so responses can be routed back unambiguously — this is what makes
same-slave-port IDs distinguishable from each other on the shared master
port. `NoSlvPorts==1` degenerates to five independent spill registers with no
arbitration at all (lines 72-148); everything below is the `NoSlvPorts>1`
case (`gen_mux`, line 151+).

## ID prepend stage (`axi_id_prepend`, one instance per slave port, lines 211-259)

Purely combinational relabeling per port `i`: every AW/AR beat entering port
`i` gets `switch_id_t'(i)` prepended to its `id` field before being handed to
the shared arbiters; every B/R beat coming back out has that same prefix
stripped (implicitly, by construction — this sub-module is instantiated but
not itself detailed here) before being returned to port `i`'s narrower
`slv_*_chan_t`. This stage does not buffer or stall beyond whatever
`axi_id_prepend` itself does; it is not further traced here since it's a
relabeling shim, not where the row 11/12 hazards live.

## AW channel (lines 261-347) — the arbitration + AW/W decoupling core

- **`i_aw_arbiter`** (`rr_arb_tree`, `LockIn=1`): every cycle, combinationally
  looks at `slv_aw_valids[NoSlvPorts]` (one bit per port with an AW beat
  presented) and picks one (round-robin, and because `LockIn=1`, if it picked
  port `k` last cycle and port `k` is *still* asserting `req_i[k]` but was not
  granted yet, it keeps re-picking `k` rather than moving on — a won
  arbitration is not abandoned mid-transaction). Drives `gnt_o[k]=1` for the
  won port and `req_o=1`/`data_o=mst_aw_chan` (that port's already-ID-prepended
  beat) — but `gnt_o[k]` here is the arbiter's *internal* grant signal, not
  yet `slv_aw_readies[k]`; the actual outward `aw_ready` to the losing/winning
  port is `slv_aw_readies`, driven by this same `gnt_o` output directly wired
  through (line 275) — so a port only sees `aw_ready=1` once it has won
  arbitration AND the downstream logic below accepts it (`gnt_i=aw_ready` from
  line 277, fed back into the arbiter, gates whether the win is actually
  consumed this cycle).
- **AW control block** (lines 284-313), the actual per-cycle FSM, with one
  bit of state, `lock_aw_valid_q`:
  - **Not locked** (`lock_aw_valid_q=0`, the common case): if the `w_fifo`
    (below) is not full and the arbiter currently has a winner
    (`aw_valid=1`), drive `mst_aw_valid=1` and `w_fifo_push=1` (push this
    winner's low `MstIdxBits` — i.e. which original port it came from — into
    the W-routing FIFO) THIS SAME CYCLE, regardless of whether the downstream
    spill register accepts it yet. If `mst_aw_ready` (the downstream accepts)
    is high this same cycle, immediately signal `aw_ready=1` back to the
    arbiter (closing the AW handshake with the winning port in one cycle).
    If `mst_aw_ready` is low this cycle, don't close the handshake yet —
    instead latch `lock_aw_valid_d=1` (go locked next cycle) so the *same*
    already-pushed decision is held.
  - **Locked** (`lock_aw_valid_q=1`): keep driving `mst_aw_valid=1` with the
    same latched beat every cycle (the arbiter is not re-consulted while
    locked) until `mst_aw_ready=1`, at which point `aw_ready=1` fires (closing
    the handshake with the winning port, now possibly several cycles after
    the win) and `lock_aw_valid_d=0` (unlock).
  - **Key point**: `w_fifo_push` only ever fires in the *not-locked* branch,
    the very first cycle a given arbitration winner is seen — so the
    write-side routing decision (which original port's W beats come next) is
    committed to the FIFO exactly once per won arbitration, independent of
    how many additional cycles it then takes for `mst_aw_ready` to actually
    close that AW handshake downstream.
- **`w_fifo`** (`fifo_v3`, depth `MaxWTrans`): a queue of `switch_id_t`
  (which original slave port each pushed AW belongs to, in push order — i.e.
  in AW-arbitration-win order, not AW-handshake-completion order, since the
  push happens before the handshake necessarily closes per the point above).
  This is the mechanism the module's own comment (line 176-177) calls "This
  FF removes AW to W dependency": the W side (below) does not need to wait
  for a given AW's handshake to fully complete before knowing which port's W
  beats to route next — it only needs the FIFO to be non-empty.
- **AW output spill register**: buffers `mst_aw_chan`/`mst_aw_valid` one more
  cycle (bypassed if `SpillAw=0`) before presenting to `mst_req_o.aw`.

## W channel (lines 349-381)

Every cycle: if `w_fifo` is non-empty, read (peek, not pop) its front entry
`w_fifo_data` (the oldest still-unrouted port index), mux
`mst_w_chan=slv_w_chans[w_fifo_data]` and connect that one port's W
handshake straight through: `mst_w_valid=slv_w_valids[w_fifo_data]`,
`slv_w_readies[w_fifo_data]=mst_w_ready`. **All other slave ports' `w_ready`
stay deasserted this cycle** — only the port at the head of `w_fifo` can ever
drive a W beat through, one full burst at a time. Pop the FIFO
(`w_fifo_pop=1`) exactly on the cycle a beat closes (`valid&&ready`) AND that
beat's `w.last=1` — i.e. the FIFO only advances to the next port once the
current port's entire W burst (however many beats, ending in `last`) has
been fully drained. If `w_fifo` is empty, `mst_w_valid=0` and no port's
`w_ready` is asserted — W is entirely idle regardless of what any slave port
is offering. Output spill register as with AW.

## B channel (lines 383-404)

Purely combinational fan-out based on the ID: `slv_b_chans` broadcasts the
(spill-registered) `mst_b_chan` to all ports identically; `switch_b_id`
extracts the prepended index bits from that beat's `id`; only
`slv_b_valids[switch_b_id]` is asserted (one-hot, driven by which port the ID
says it belongs to) — `slv_b_readies[switch_b_id]` gates the spill register's
own `ready_i`, so a B beat sits in the spill register until the specific
port it's addressed to asserts its `b_ready`. Only one B beat is in flight
through this whole channel at a time (the spill register holds at most one).

## AR / R channels (lines 406-463)

Structurally identical to AW/AW-routing but *without* the FIFO decoupling —
because AR has no follow-on data-phase channel the way AW has W, there is no
`ar_fifo` equivalent. `i_ar_arbiter` (same `rr_arb_tree`, `LockIn=1`)
round-robins AR winners directly into the AR spill register: same
lock-on-stall shape is handled *inside* the spill register itself (a spill
register inherently holds a beat until accepted), so there is no separate
`lock_ar_valid` bit needed here the way there is for AW+w_fifo — the arbiter
simply re-arbitrates each cycle among ports whose AR is still valid (with
`LockIn` preferring to keep the same in-progress winner). R channel is the
exact mirror of B: broadcast + one-hot ready-select by `switch_r_id`, one
beat in flight through the shared R spill register at a time.

## Net per-cycle shape, summarized

- Any number of slave ports can have AW/AR beats pending simultaneously;
  the round-robin arbiters pick at most one AW winner and (independently)
  at most one AR winner per cycle to advance toward the master port.
- Once an AW winner is chosen, its routing index is committed to `w_fifo`
  immediately (same cycle, before the AW handshake even necessarily closes),
  decoupling "who won AW arbitration" from "whose W beats are currently
  allowed through" — but only one port's W beats are ever active at a time,
  strictly in `w_fifo` push order, one full burst (`w.last`-terminated)
  before the next.
- B and R responses are demultiplexed purely by the ID's prepended index
  bits, broadcast to all ports but handshake-gated to exactly the one whose
  index matches — one B beat and one R beat in flight through the shared
  channel at a time (bounded by the single shared spill register each), even
  though many transactions from different ports may be simultaneously
  outstanding upstream of the mux (bounded by `MaxWTrans` for writes via the
  `w_fifo` depth; unbounded/subordinate-dependent for reads, since there's no
  equivalent tracking FIFO on the AR/R side).
