# `adbg_axi_biu` — full cycle-by-cycle protocol (port-wire view)

Two independent clock domains, bridged internally so that a request on one
side reliably produces a response on the other. Described separately below,
purely in terms of what each side's own port wires do cycle to cycle — no
internal register names.

## Debug-host boundary (`tck_i` domain)

Ports: `data_i`, `addr_i`, `strobe_i`, `rd_wrn_i`, `word_size_i` in;
`data_o`, `rdy_o`, `err_o` out.

- **Reset**: `rdy_o=1`. The host sees the BIU as immediately ready to accept
  a request.
- **A cycle where `strobe_i=1` while `rdy_o=1`** is the only cycle a request
  is actually accepted: the host must present `addr_i`, `rd_wrn_i`,
  `word_size_i` (and `data_i` for a write) valid on that same cycle. The very
  next cycle, `rdy_o` drops to 0.
- **Every cycle while `rdy_o=0`**: `strobe_i` is ignored no matter how the
  host drives it — a second request cannot be accepted, queued, or merged
  with the first. The host must simply wait.
- **`rdy_o` stays 0 for an unspecified number of cycles** — as many as the
  AXI4 side (below) takes to complete one full exchange with whatever
  subordinate is attached. Nothing on the debug-host wires moves during this
  time.
- **The cycle `rdy_o` returns to 1**: `data_o` (valid only after a read) and
  `err_o` are valid and stable from this cycle onward, until overwritten by
  the *next* accepted request's result. The host may now read them and/or
  drive a new `strobe_i=1`.
- **Net shape on this boundary**: strictly one request in flight at a time —
  pulse `strobe_i` with payload while `rdy_o=1`, wait with `rdy_o=0`, read
  `data_o`/`err_o` once `rdy_o=1` again, repeat. No pipelining, no drop, no
  reorder — a clean single-outstanding request/reply port.

## AXI4 manager boundary (`axi_aclk` domain) — this is where the row-1 bug lives

Ports: `axi_master_aw_valid`/`_ready` (+ `aw_addr`, `aw_id`, etc., all fixed
to a single untagged single-beat burst — `aw_len=0`, `aw_burst=INCR`
effectively, `aw_id=0` always), `axi_master_ar_valid`/`_ready`,
`axi_master_w_valid`/`_ready`/`w_data`/`w_last` (`w_last` is wired
permanently to 1 — every write is exactly one W beat), `axi_master_b_valid`/
`_ready`, `axi_master_r_valid`/`_ready`/`r_data`. The BIU is the AXI
**manager** on this port; the environment is whatever AXI **subordinate** is
attached. `axi_master_aw_id`/`ar_id`/`aw_user`/`ar_user`/`w_user` are tied to
0, `aw_prot`/`aw_cache`/`aw_qos`/`aw_region`/`aw_burst`/`aw_lock` similarly
tied to fixed/zero values (same for the AR side) — none of those fields ever
vary beat to beat, so they carry no protocol information here.

Internally the manager tracks one piece of `State` recording which phase of
one AXI exchange it is in — address phase, data phase, or response phase —
because that's the only way to explain, from the wires alone, why (for
example) `aw_valid` can be observed high on one cycle and low on the next
with nothing on the bus having changed except time passing. The wire-level
behavior in each phase:

- **Idle phase**: `aw_valid=ar_valid=w_valid=b_ready=r_ready=0` every cycle.
  The manager is waiting on the debug-host side (above); nothing on this
  boundary moves. Transitions out only in response to the debug-host side
  accepting a request internally — not observable on these wires directly.
- **Address phase, write**: `aw_valid=1` AND `w_valid=1` are asserted
  *together*, every cycle this phase lasts, with `aw_addr`/`w_data` held at
  the constant value chosen for this transaction. Three things can happen,
  cycle by cycle, depending purely on what the subordinate drives back:
  - `aw_ready=1` and `w_ready=0` this cycle: next cycle, `aw_valid` drops to
    0 and stays 0 for the rest of this transaction; `w_valid` stays 1 (data
    phase, below).
  - `aw_ready=1` and `w_ready=1` this cycle (both close together): next
    cycle, both `aw_valid` and `w_valid` drop to 0 (response phase, below).
  - `aw_ready=0` this cycle — **regardless of what `w_ready` is doing,
    including `w_ready=1`**: next cycle, `aw_valid=1` and `w_valid=1` are
    both re-asserted with the *same* address/data as before, unchanged. If
    the subordinate had raised `w_ready=1` on this stalled cycle (a
    legal AXI4 subordinate is free to do so — accepting `W` before `AW`),
    that acceptance is not reflected in what the manager drives next cycle:
    `w_valid=1` is presented again on the same channel, as if nothing had
    been accepted. There is no wire-observable difference between "W has
    never been offered yet" and "W was already accepted while AW was still
    stalled" — both look identical from the manager's outputs on the
    following cycle.
- **Data phase** (only reached via the first branch above, i.e. only after
  `aw_ready` has already been seen with `w_ready` still 0 that same cycle):
  `w_valid=1` every cycle, `aw_valid=0` throughout (by construction of how
  this phase is entered, `AW` cannot be re-offered here), until `w_ready=1`,
  at which point `w_valid` drops to 0 next cycle and the exchange moves to
  the response phase.
- **Address phase, read**: only `ar_valid=1` is asserted (constant `ar_addr`
  held), every cycle, until `ar_ready=1`; then `ar_valid` drops to 0 next
  cycle and the exchange moves to the response phase.
- **Response phase, write**: `b_ready=1` every cycle until `b_valid=1`; that
  same cycle, `b_resp` is captured (feeding `err_o` on the debug-host side)
  and the exchange ends — `b_ready` drops next cycle and the manager returns
  to the idle phase, at which point the debug-host side's `rdy_o` returns to
  1.
- **Response phase, read**: symmetric — `r_ready=1` every cycle until
  `r_valid=1`; `r_data`/`r_resp` are captured that cycle (feeding `data_o`/
  `err_o`), then back to idle and `rdy_o` returns to 1.
- **Net shape on this boundary**: one full AXI4 exchange at a time — the
  idle phase is not re-entered (so no new exchange can start) until the
  current one's response phase completes. Within the write address phase,
  `aw_valid` and `w_valid` are always *offered* on the same cycle as each
  other, every cycle of that phase, but the only wire condition that reliably
  advances the manager past that phase is `aw_ready=1` — a subordinate whose
  `w_ready` arrives (and is taken) before `aw_ready` leaves the manager
  re-driving `w_valid=1` on an already-accepted beat, cycle after cycle,
  until `aw_ready` finally arrives too.

## Where row 1 (ANNOTATIONS.md) sits in this

AMBA AXI4 explicitly permits a subordinate to accept `W` before `AW`
(`WVALID`/`WREADY` must not depend on `AWVALID`/`AWREADY`, and vice versa for
a compliant manager). The write address phase above is exactly the
violation: the manager's only wire-observable path out of that phase requires
seeing `aw_ready=1`; a legal subordinate that raises `w_ready=1` first (and,
having done so, is done with W for that beat) meets a manager that keeps
re-driving `w_valid=1` regardless, with nothing on the manager's own output
wires ever distinguishing "W not yet offered" from "W already accepted, still
being re-offered." This is pulpino issue #182 (FILED, see
`../../ANNOTATIONS.md` row 1).
