# `ccu_fsm` — full cycle-by-cycle protocol

Three boundaries, all serviced by one shared 18-state FSM (`state_q`/`state_d`),
so only one of them makes progress at a time: (1) the initiator-facing ACE
port (`ccu_req_i`/`ccu_resp_o` — the core(s) issuing the request this CCU
instance is currently servicing), (2) the memory-facing AXI-like port
(`ccu_req_o`/`ccu_resp_i` — writeback + fill target), (3) the `NoMstPorts`-wide
snoop fan-out (`s2m_req_o`/`m2s_resp_i` — one port per coherent core,
including the initiator itself). Everything is single-threaded: the CCU
services exactly one initiator request end-to-end (through however many
snoop/writeback/memory sub-phases it needs) before returning to `IDLE` and
picking up the next one.

## `IDLE` — request acceptance and read/write priority

Every cycle in `IDLE`: `initiator_d='0`, `prio_d='0` by default (lines
128-129), then re-evaluated combinationally:
- If (`ar_valid && !aw_valid`) OR (`ar_valid && prio_q.waiting_r`) OR
  (`ar_valid && !prio_q.waiting_w`) → accept the read: `state_d=DECODE_R`,
  latch `initiator_d[core index from ar.id] = 1`, and if a write was
  *simultaneously* pending (`aw_valid`), remember it via
  `prio_d.waiting_w=1` so it isn't starved next round.
- Else if (`aw_valid && !ar_valid`) OR (`aw_valid && prio_q.waiting_w`) →
  accept the write symmetrically, `state_d=DECODE_W`,
  `prio_d.waiting_r = ar_valid`.
- Else stay `IDLE`.
This is a 1-bit round-robin-ish priority latch, not a queue: only ever tracks
"the other direction was pending last time I chose," so it alternates when
both directions request every cycle, but has no memory beyond one round.
Same cycle, a *separate* always_ff block (lines 522-538) — gated on the exact
same `state_q==IDLE` + accept condition — latches the actual beat
(`ccu_req_holder.ar`/`.aw` and validity/`r_ready`) into a holding register;
everything from `DECODE_R`/`DECODE_W` onward reads from `ccu_req_holder`, not
`ccu_req_i` directly (except in `WRITE_MEM`/`READ_MEM`'s pass-through phases,
see below). `ccu_resp_o.ar_ready`/`.aw_ready` are pulsed exactly one cycle
later, in `DECODE_R`/`DECODE_W` (lines 356, 462) — not in `IDLE` itself.

## Read branch

- **`DECODE_R`**: combinationally, same cycle: `ccu_resp_o.ar_ready=1`
  (accepting `ccu_req_holder`'s already-latched beat is really just a
  formality here — the actual capture already happened in `IDLE`). Route:
  `CLEAN_UNIQUE` snoop type or `ar.lock` (an atomic LR) → `SEND_INVALID_R`;
  otherwise → `SEND_READ`.
- **`SEND_INVALID_R`** (invalidate path, one shot): every cycle, drive
  `s2m_req_o[n].ac_valid = !ac_ready[n]` for all `n` (holding each snoop
  port's AC valid up until that specific port's `ac_ready` has been latched
  — see the `ac_ready` always_ff below), with `ac.snoop=CLEAN_INVALID`. Stay
  in this state until `ac_ready=='1` (all `NoMstPorts` bits set), then
  advance to `WAIT_INVALID_R`.
- **`WAIT_INVALID_R`**: drive `s2m_req_o[n].cr_ready = !cr_valid[n]` for all
  `n` every cycle (same per-port latch-until-seen pattern via the `cr_valid`
  always_ff). Once `cr_valid=='1` (all cores answered) AND
  (`ccu_req_i.r_ready` OR it's a lock/AMO) — note: gated on the *live*
  `ccu_req_i.r_ready`, not the latched holder — branch: if any responding
  core had `data_available` and no `response_error`, go get that data back
  via writeback (`SEND_AXI_REQ_WRITE_BACK_R`); else if this was a lock, go
  read fresh from memory (`SEND_AXI_REQ_R`); else (plain CleanUnique, no
  data owed) go straight to `IDLE`. Also same cycle: if all CR responses in
  and not an AMO lock, this state drives the read response directly —
  `ccu_resp_o.r_valid=1`, `.r.last=1`, `.r.id=ccu_req_holder.ar.id` (lines
  386-391) — a zero-data-beat response for a plain CleanUnique invalidate.
- **`SEND_READ`** (non-invalidate snoop path): every cycle, drive
  `s2m_req_o[n].ac_valid=!ac_ready[n]` for all `n`, `ac.snoop =
  ccu_req_holder.ar.snoop` (the original request's snoop type, e.g.
  READ_SHARED/READ_UNIQUE/READ_NO_SNOOP), `ac.addr = ar.addr`. Stay until
  `ac_ready=='1`, then `WAIT_RESP_R`.
- **`WAIT_RESP_R`**: drive `cr_ready=!cr_valid[n]` every cycle for all `n`
  until `cr_valid=='1`; then, same cycle, branch: any responder with
  `data_available && !response_error` → `READ_SNP_DATA` (serve from the
  snooping peer's cache); else → `SEND_AXI_REQ_R` (go to memory).
- **`READ_SNP_DATA`** (serving data streamed in from the first core that
  had it — `first_responder`, latched by the CR always_ff the cycle the
  first `dataTransfer&&!error` response is seen): every cycle drives
  `s2m_req_o[n].cd_ready = !cd_last[n] & data_available[n]` for all `n`
  (only the responders that actually have data are asked for CD beats).
  Concurrently drives `ccu_resp_o.r` from a small internal buffer
  (`cd_data[]`, `stored_cd_data` — an up/down counter tracking how many CD
  beats have been received from `first_responder` but not yet drained to
  the initiator's `r` channel) — for a single-word request
  (`ar.len==0`), waits for `stored_cd_data` to reach exactly
  `ar_addr_offset+1` before asserting `r_valid&&r_last` with the matching
  word; for a full cache-line request, streams `cd_data[r_last]` with
  `r_valid = |stored_cd_data` (i.e. valid whenever the buffer is
  non-empty), alternating `r_last` 0→1 as each of the (fixed,
  `DcacheLineWords==2`-hardcoded, see the `a_dcache_line_words` assertion at
  line 697) two words is drained. `resp[3]`/`resp[2]` (shared/dirty) are
  OR-reduced across all responders' latched `shared`/`dirty` bits. Exits to
  `IDLE` once `cd_last==data_available` (every port that had data has sent
  its last CD beat) AND either `r_eot` is already latched or this cycle
  both `ccu_req_i.r_ready` and the internal `r_last` toggle line up on the
  final beat.
- **`SEND_AXI_REQ_WRITE_BACK_R`**: drives `ccu_req_o.aw_valid=1` every cycle
  with a synthesized writeback AW beat (`aw.addr` = the original request's
  cache-line-aligned address, `aw.len=DcacheLineWords-1`,
  `aw.id={first_responder, original id low bits}`, `aw.snoop=3'b011`,
  `aw.domain=2'b00`) until `ccu_resp_i.aw_ready=1`, then `WRITE_BACK_MEM_R`.
- **`WRITE_BACK_MEM_R`**: every cycle, continues driving `s2m_req_o[*].cd_ready`
  for the still-streaming source core, and drives `ccu_req_o.w_valid =
  |stored_cd_data`, `.w.data = cd_data[w_last]`, `.b_ready=1` — streaming the
  same snooped cache line out to the memory-facing AW/W channel that was just
  granted. Stays until `ccu_resp_i.b_valid && ccu_req_o.b_ready`, at which
  point: if this was an AMO lock, go read the now-updated line from memory
  (`SEND_AXI_REQ_R`); otherwise done, → `IDLE` (the CD data already served the
  initiator directly in a state visited earlier via `READ_SNP_DATA`, so no
  further read-back from memory is needed for a plain read hit).
- **`SEND_AXI_REQ_R`** (miss / AMO-lock path — actually fetch from memory):
  drives `ccu_req_o.ar_valid=1`, `.ar = ccu_req_holder.ar` (the ORIGINAL
  request forwarded verbatim), `.r_ready = ccu_req_holder.r_ready` every
  cycle until `ccu_resp_i.ar_ready=1`, then `READ_MEM`.
- **`READ_MEM`**: every cycle, pure pass-through: `ccu_req_o.r_ready =
  ccu_req_i.r_ready` (live, not latched), `ccu_resp_o.r = ccu_resp_i.r`,
  `ccu_resp_o.r_valid = ccu_resp_i.r_valid` — the memory's R channel is
  wired straight through to the initiator's R channel, beat for beat. Stays
  until a cycle where `ccu_resp_i.r_valid && ccu_req_i.r_ready && r.last`,
  then → `IDLE`.

## Write branch (structurally the mirror of the read branch, no data-serve-from-cache step)

- **`DECODE_W`**: unconditionally `state_d=SEND_INVALID_W` (a write always
  invalidates all peers first — there is no "no snoop needed" branch on the
  write side the way `SEND_READ` exists for reads). Same cycle,
  `ccu_resp_o.aw_ready=1`.
- **`SEND_INVALID_W`**: identical shape to `SEND_INVALID_R` but sourced from
  `ccu_req_holder.aw.addr`/`.prot`, `ac.snoop=CLEAN_INVALID`; waits for
  `ac_ready=='1`, then `WAIT_INVALID_W`.
- **`WAIT_INVALID_W`**: drives `cr_ready` (shared output-block case with
  `WAIT_RESP_R`, line 377) until `cr_valid=='1`; branches on
  `data_available & ~response_error`: any hit → `SEND_AXI_REQ_WRITE_BACK_W`
  (flush the dirty line out first); no hit → `SEND_AXI_REQ_W` (straight
  write, nothing to flush).
- **`SEND_AXI_REQ_WRITE_BACK_W`**: same synthesized-writeback-AW shape as
  the R-branch version, sourced from `ccu_req_holder.aw.addr`, waits for
  `ccu_resp_i.aw_ready`, then `WRITE_BACK_MEM_W`.
- **`WRITE_BACK_MEM_W`**: streams the flushed line out (`w_valid =
  |stored_cd_data`, gated additionally on `!r_eot` at line 493 — reuses the
  same eot flag, effectively meaning "only while the CD stream isn't
  already exhausted") until `ccu_resp_i.b_valid && ccu_req_o.b_ready`, then
  unconditionally → `SEND_AXI_REQ_W` (no AMO branch on the write side).
- **`SEND_AXI_REQ_W`**: drives `ccu_req_o.aw_valid=1`, `.aw =
  ccu_req_holder.aw` (original write beat forwarded verbatim) until
  `ccu_resp_i.aw_ready=1`, then `WRITE_MEM`.
- **`WRITE_MEM`**: pure pass-through both directions: `ccu_req_o.w =
  ccu_req_i.w`, `.w_valid = ccu_req_i.w_valid`, `.b_ready = ccu_req_i.b_ready`
  (initiator's W channel wired straight to memory's W channel) and
  `ccu_resp_o.b = ccu_resp_i.b`, `.b_valid = ccu_resp_i.b_valid`,
  `.w_ready = ccu_resp_i.w_ready` (memory's B/W-ready wired back to
  initiator) every cycle. Exits once `ccu_resp_i.b_valid && ccu_req_i.b_ready`:
  if the original request was an ATOP with a read-response bit set
  (`ccu_req_holder.aw.atop[5]`), continue into `READ_MEM` (an atomic
  read-modify-write's read-back phase, reusing the read branch's terminal
  state); otherwise → `IDLE`.

## Cross-cutting per-port latch state (all `NoMstPorts`-wide, all reset in `IDLE`)

- **`ac_ready`/`ac_valid`** (lines 542-557): captured to `initiator_q` on
  entry to `DECODE_R`/`DECODE_W` (so only the ports belonging to the
  initiator's own request start unset — actually this latches `ac_ready <=
  initiator_q`, i.e. the *initiator's own port* starts as if already
  ready/skip-able, since the CCU doesn't snoop the requester's own cache);
  during `SEND_READ`/`SEND_INVALID_R`/`SEND_INVALID_W`, each port
  latches `ac_ready[i] |= (m2s_resp_i[i].ac_ready & s2m_req_o[i].ac_valid)`
  — sticky, once seen ready stays ready for the rest of this transaction.
  Any other state resets both to 0 (defensive; should only be reached via
  `IDLE`).
- **`cr_valid`/`data_available`/`shared`/`dirty`/`response_error`/
  `first_responder`** (lines 560-600): `cr_valid` seeded from
  `initiator_q` on entering `SEND_READ`/`SEND_INVALID_R`/`SEND_INVALID_W`
  (same self-skip logic as AC); thereafter, each port's CR response is
  latched sticky the cycle `m2s_resp_i[i].cr_valid && s2m_req_o[i].cr_ready`
  is seen. `first_responder` latches (once, via `snoop_resp_found`) the
  index of the first port whose CR response had both `dataTransfer` and no
  `error` — this is the one core CD data gets pulled from; a data-bearing
  response from a later-indexed core is ignored if an earlier one already
  qualified.
- **`data_received`/`cd_last`/`cd_data`/`stored_cd_data`** (lines 602-660):
  active during `READ_SNP_DATA` or `WRITE_BACK_MEM_R`/`WRITE_BACK_MEM_W`
  only, and only meaningfully driven from `first_responder`'s CD stream
  (the loop iterates all `i` for `data_received`/`cd_last` bookkeeping, but
  the actual `cd_data` capture and the `stored_cd_data` counter only look
  at `m2s_resp_i[first_responder]`). `stored_cd_data` increments when a CD
  beat is accepted from `first_responder` but not simultaneously drained
  out (to `r` or `w`), decrements the opposite way, unchanged if both or
  neither happen the same cycle — a small elastic buffer, capacity bounded
  by `DcacheLineWords` (2) in practice.
- **`r_last`/`r_eot`** and **`w_last`/`w_eot`** (lines 662-692): each is a
  1-bit toggle-per-accepted-beat plus a sticky "did we just send/receive
  the final beat" flag, reset only on returning to `IDLE`.
