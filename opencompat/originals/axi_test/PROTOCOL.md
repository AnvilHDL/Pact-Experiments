# `axi_test.sv` — full cycle-by-cycle protocol

This file is a UVM-less SystemVerilog *class library*, not one module — it is a
collection of tasks that drive/monitor a virtual `AXI_BUS_DV` interface. Two
independent pieces are relevant to ANNOTATIONS.md rows 2 and 5: the low-level
per-channel driver (`axi_driver`, used identically by every higher-level agent)
and the per-ID in-flight bookkeeping inside the random write master
(`axi_rand_master`). This corrects an earlier draft of this file's type, which
assumed `send_w` is only ever called after `send_aw` returns for a given
transaction — that is not what the code does; see below.

## `axi_driver`'s per-channel primitives (lines 283-680)

Every one of `send_aw`/`send_w`/`send_ar`/`send_r`/`send_b` (and the `recv_*`,
`mon_*` counterparts) follows the identical one-shot shape, independent of any
other channel:

1. Drive all payload fields for the beat non-blocking with a `#TA` stimuli
   application delay, and set that channel's `*_valid <= #TA 1` in the same
   statement group (e.g. `send_aw`, lines 377-389).
2. `cycle_start()` (`#TT`, a test-time delay within the cycle) then loop:
   while the peer's `*_ready` signal reads 0, do `cycle_end()` (`@(posedge
   clk_i)`) followed by `cycle_start()` again — i.e. hold the payload and
   `valid` asserted, unchanged, for as many whole clock cycles as it takes.
3. Once `*_ready` reads 1 (sampled at `TT` into the cycle), do one final
   `cycle_end()` to let that edge complete the handshake, then on the very
   next statement drive all payload fields and `*_valid` back to 0.
4. Net effect: each `send_*` call presents exactly one beat, holds it valid
   until accepted (arbitrarily many wait cycles, minimum zero if `ready` is
   already high), and returns control to its caller only after the accepting
   edge has passed. Nothing else happens on that channel while a `send_*` call
   is in progress — the calling task is blocked for the whole handshake.
5. `recv_*` is the mirror image from the receiving side: raise `*_ready`,
   spin until `*_valid`, capture the payload, drop `*_ready`.
6. `mon_*` is passive: never drives anything, just polls every cycle for
   `*_valid && *_ready` (both already driven by two other agents) and
   captures the beat once that joint condition is true — used only for
   snooping, in `axi_monitor.monitor()` (lines 1893-1926), which forks five
   independent `forever` loops (one per channel: AW, W, B, AR, R) that each
   push every observed beat into its own mailbox. This is a passive tap, not
   a driver — it imposes no ordering of its own.

**Crucially**: `send_aw` and `send_w` are independent primitives. Nothing in
`axi_driver` itself calls one from the other, and nothing in `axi_driver`
serializes AW after W or vice versa — each is a self-contained "present this
one beat on this one channel until it's accepted" loop.

## Where the AW/W ordering actually comes from: `axi_rand_master.run` (lines 682-1319)

`run(n_reads, n_writes)` (line 1298) forks six concurrent processes and
`join`s them (waits for all six to finish):

- `send_ars(n_reads, ax_user)` then sets `ar_done=1'b1` — generates and issues
  `n_reads` read address beats one at a time via `drv.send_ar`.
- `recv_rs(ar_done, aw_done)` — drains R-channel responses as they arrive.
- `create_aws(n_writes, ax_user)` then sets `aw_done=1'b1` (lines 1212-1231):
  for each of `n_writes` iterations, build a random (or exclusive-reused) AW
  beat, block via `rand_wait` while `tot_w_flight_cnt >= MAX_WRITE_TXNS`,
  call `legalize_id` (below) to pick/confirm its ID, then **push the same
  beat object onto two separate queues**: `aw_queue.push_back(aw_beat)` AND
  `w_queue.push_back(aw_beat)` (line 1228-1229). This is the pivot: from this
  point on, the AW beat and its W beats are two independent queue entries.
- `send_aws(aw_done)` (lines 1233-1241) — a **separate forked process** that
  loops: wait until `aw_queue` is non-empty (or done-and-empty, to exit), pop
  the front entry, `rand_wait` a random 0..`AX_MAX_WAIT_CYCLES` gap, then
  `drv.send_aw(aw_beat)` (blocks until that AW handshake completes).
- `send_ws(aw_done)` (lines 1243-1279) — **another separate forked process**,
  running *concurrently* with `send_aws`, not after it: loops on `w_queue`
  independently, pops the front AW-beat object (to learn the burst length/
  address for computing strobes), then for each of that burst's data beats,
  `rand_wait` a random 0..`W_MAX_WAIT_CYCLES` gap and `drv.send_w(w_beat)`.
- `recv_bs(aw_done)` — drains B-channel responses, decrementing in-flight
  counters.

Because `send_aws` and `send_ws` are separate forked tasks each pulling from
their own independent queue with their own independent random wait, **there is
no code-level guarantee that a given transaction's AW beat is driven before
its W beat(s)** — `send_ws` could pop `w_queue`'s matching entry and start
driving W before `send_aws` has gotten around to popping the corresponding
`aw_queue` entry and driving AW, purely depending on the two processes'
relative random wait draws. In practice, across many random transactions
queued back-to-back, AW for transaction N might still complete before W for
transaction N in the common case, but the driver places no explicit
sequencing constraint that forces it — the true contract is closer to "AW and
W for the same transaction are each eventually offered, independently timed,"
not "AW strictly precedes W."　(ANNOTATIONS.md row 2's characterization of a
hard `send_aw`-then-`send_w` call chain describes a simpler, single-threaded
mental model of the driver; the actual `axi_rand_master` is already
concurrent by construction.)

## Per-ID in-flight tracking: `legalize_id` / `id_is_legal` (lines 1103-1166) — row 5

State: `r_flight_cnt[id]`, `w_flight_cnt[id]` (per-ID outstanding counts),
`tot_r_flight_cnt`, `tot_w_flight_cnt` (aggregate counts), `atop_resp_b[id]`,
`atop_resp_r[id]` (bitmaps: does an in-flight ATOP on this ID still owe a B/R
response), all protected by a binary semaphore `cnt_sem`.

Cycle-by-cycle behavior of `legalize_id(is_read, beat)`, called once per
transaction from `create_aws` (write) or `send_ars` (read) before that
transaction's beat is queued/sent:

1. Acquire `cnt_sem` (line 1133) — this task is itself only ever entered by
   one of the two sequential single-threaded generator loops
   (`create_aws`/`send_ars`), so the semaphore here guards against `recv_bs`/
   `recv_rs` concurrently decrementing counts mid-check, not against another
   `legalize_id` call (those are not themselves forked in parallel).
2. Check `id_is_legal`: if `AXI_ATOPS` and this ID already owes an ATOP
   response (`atop_resp_b`/`atop_resp_r` set) → illegal. If this beat *starts*
   a non-read ATOP and that ID already has ANY outstanding read or write
   (`r_flight_cnt`/`w_flight_cnt` != 0) → illegal. If `UNIQUE_IDS` is set and
   this ID already has an outstanding transaction *in the same direction*
   (`r_flight_cnt[id]!=0` for a read, `w_flight_cnt[id]!=0` for a write) →
   illegal. Otherwise legal.
3. If legal: fall through, release semaphore (line 1165) at the end, having
   incremented `w_flight_cnt[id]`/`tot_w_flight_cnt` (write) or
   `r_flight_cnt[id]`/`tot_r_flight_cnt` (read) — line 1149-1163 — and, for a
   non-zero-length ATOP, marked `atop_resp_b[id]` (and `atop_resp_r[id]` if
   the ATOP type also returns read data).
4. If illegal: release the semaphore, `rand_wait(1,1)` (block exactly one
   cycle), then — unless this is a locked/exclusive transfer whose ID must
   not change — draw a fresh random ID and loop back to step 1 with the new
   ID. This repeats every cycle until some ID is found legal.
5. The *release* side, symmetric and cycle-driven from the response tasks:
   `recv_bs` (write) decrements `w_flight_cnt[b_beat.b_id]`/
   `tot_w_flight_cnt` the cycle a B beat with that ID is received (lines
   1286-1292); `recv_rs` (read) decrements `r_flight_cnt[r_beat.r_id]`/
   `tot_r_flight_cnt` the cycle an R beat with `r_last` and that ID is
   received (lines 1195-1204). Both also take `cnt_sem` for the update.

**Net contract this enforces on the ID an `axi_rand_master` itself will ever
place on the bus**: with `UNIQUE_IDS=1`, this master will never present a new
AW (or AR) beat carrying an ID that already has an outstanding transaction of
the same direction in flight — it stalls (drawing new random IDs, one retry
per cycle) until a free ID becomes available or the current ID's prior
transaction completes. Without `UNIQUE_IDS` (the default, line 710), IDs may
be reused freely across in-flight write transactions of the same ID, which is
the row-5 hazard: a same-ID B response can no longer be unambiguously
attributed to a specific one of the (possibly several) outstanding writes
sharing that ID, since AXI only guarantees *same-ID responses return in
issue order*, not that a scoreboard watching from outside can tell which
logical write instance a given B belongs to when more than one is in flight
under one ID. The `axi_monitor`/`axi_scoreboard` classes (lines 1856+,
1951+) are pure passive observers/checkers of what actually appeared on the
bus — they do not themselves impose or relax this ID-reuse contract; the
contract lives entirely in `legalize_id`'s use (or non-use) of `UNIQUE_IDS`
inside the master that generates the traffic.
