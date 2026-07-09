# `wbuart` — full cycle-by-cycle protocol (port-wire view)

One Wishbone subordinate (slave) port (`i_wb_cyc`/`i_wb_stb`/`i_wb_we`/
`i_wb_addr`/`i_wb_data`/`i_wb_sel` in, `o_wb_stall`/`o_wb_ack`/`o_wb_data`
out) plus a UART line pair (`i_uart_rx`/`o_uart_tx`), a flow-control pair
(`i_cts_n`/`o_rts_n`), and four interrupt outputs
(`o_uart_rx_int`/`o_uart_tx_int`/`o_uart_rxfifo_int`/`o_uart_txfifo_int`).
This component is documented in ANNOTATIONS.md as a *correct* Wishbone
peripheral (rows 7 and 8's `FILED`/`CLASS` provenance is about a *different*
component — a litex/migen slave and a width-downconverter respectively —
not a bug in this file); it is retained to show, on the wires, what a
compliant Wishbone slave boundary looks like, against which the documented
buggy peer can be judged. Below, `State` refers only to the two internal
pipeline-delay bits this component's own `o_wb_ack` timing depends on; the
UART/FIFO internals behind the register reads are not part of the Wishbone
boundary contract and are not detailed here.

## Wishbone boundary: request side

- **Every cycle**, `i_wb_cyc` and `i_wb_stb` are sampled combinationally;
  `i_wb_we` selects write vs. read, `i_wb_addr` selects which of four
  registers (`UART_SETUP`, `UART_FIFO`, `UART_RXREG`, `UART_TXREG`), and for
  a write, `i_wb_data`/`i_wb_sel` supply the payload with byte-lane
  granularity (`i_wb_sel[3:0]`, one bit per byte of `i_wb_data`).
- **`o_wb_stall` is permanently tied to 0**, every cycle, unconditionally —
  this component never asks the requester to hold a request steady across
  multiple cycles; whatever `i_wb_stb`/`i_wb_addr`/`i_wb_we`/`i_wb_data`/
  `i_wb_sel` are presented on a given cycle (while `i_wb_cyc=1`) are treated
  as accepted for that cycle, with no retry or wait required from the
  requester's side.
- **This means the requester may present a new `i_wb_stb=1` beat every
  single cycle, back to back, with no gap** — the component is fully
  pipelined and never pushes back on the request side; there is no
  `o_wb_stall`-driven throttling to describe on this boundary.

## Wishbone boundary: response side — fixed 2-cycle pipeline

- **`o_wb_ack` for a given accepted `i_wb_stb=1` beat appears exactly two
  clock cycles later**, unconditionally, as long as `i_wb_cyc` stays
  asserted across those two cycles — one cycle of `State` first records
  "a strobe was accepted last cycle" (this is what feeds `o_wb_ack` the
  cycle after that). If `i_wb_stb=1` beats are presented every cycle
  back-to-back, `o_wb_ack=1` likewise appears every cycle back-to-back,
  two cycles behind — the pipeline has depth exactly 2 and is never
  stalled, so N consecutive strobes produce N consecutive acks, each
  delayed by the same fixed 2 cycles, with no additional gaps or bubbles
  introduced by this component itself.
- **`o_wb_data` is valid on exactly the same cycle `o_wb_ack=1`** — for a
  read, `o_wb_data` reflects the register selected by whichever `i_wb_addr`
  was presented on the *original* strobing cycle (address is itself
  pipelined one cycle internally to line up with the two-cycle ack
  timing), so a read strobe's address must be captured by this component
  before the requester is allowed to change `i_wb_addr` again; on any other
  cycle `o_wb_data`'s value carries no meaning and the requester is
  expected to ignore it.
- **If `i_wb_cyc` drops before the two cycles elapse**, `o_wb_ack` is
  suppressed for that pending beat (the ack computation is gated on
  `i_wb_cyc` being asserted on the ack-producing cycle itself, not just on
  the original strobing cycle) — an aborted bus cycle simply does not
  produce a late ack once the cycle has ended.
- **Net shape on this boundary**: every accepted strobe is guaranteed
  exactly one ack, exactly 2 cycles later (provided `cyc` stays high), with
  unlimited pipelining and no stalls — a slave that always eventually
  responds, on a fixed, non-data-dependent, non-address-dependent, and
  non-conditional-on-buffer-state latency.

## UART/flow-control side (not part of the Wishbone contract, but observably tied to it)

- **`o_rts_n`** is driven from a threshold comparison on the receive
  FIFO's fill level, re-evaluated every cycle — asserted (request-to-send
  de-asserted, i.e. "stop sending to me") once the FIFO is within 2 slots
  of full, purely a function of receive-side fill state, with no relation
  to the Wishbone request/response cycle timing above except that FIFO
  reads happen via that same Wishbone `UART_RXREG` address.
- **Reading `UART_RXREG`** (`i_wb_stb=1`, `i_wb_addr=UART_RXREG`,
  `i_wb_we=0`) is the only Wishbone-side action with a side effect beyond
  producing `o_wb_data`: it also advances the receive FIFO's own internal
  read pointer, one cycle after the strobe (mirroring the same
  strobe-then-one-cycle-later shape used throughout this file) — so two
  back-to-back reads of `UART_RXREG` return two *different* FIFO entries in
  order, not the same entry twice, even though both still individually
  obey the fixed 2-cycle ack timing above.
- **Writing `UART_TXREG`** similarly has a side effect: it pushes the
  written byte into the transmit FIFO, again one cycle after the strobe,
  independent of and not blocking the fixed 2-cycle ack for that same
  write beat — the ack timing on the Wishbone boundary is identical
  whether or not the write's side effect (the FIFO push) succeeds or the
  FIFO happens to be full (this component does not stall or NAK a write to
  a full transmit FIFO on this boundary; the ack still arrives on schedule).

## Row 7 — "ACK never asserted," and why this file is the correct reference, not the bug

**What this component's own wires guarantee**: as stated above, every
accepted `(i_wb_cyc && i_wb_stb)` beat is answered by `o_wb_ack=1` exactly
2 cycles later, unconditionally — there is no wire-reachable condition
under which a strobe is accepted and no ack ever follows. The documented
bug (litex issue #572, a *different* slave, not present in this file) is a
slave whose internal state machine can reach a self-loop from which no
path to asserting `ack` exists — i.e. `(cyc && stb)` is observed, but the
slave's own `State` has no transition that ever raises `ack` again. This
file is retained specifically because it is the same kind of component
(a Wishbone peripheral slave) implementing the *opposite*, correct
discipline: every `State` this component can reach following an accepted
strobe leads, deterministically and within a fixed 2 cycles, to `ack`. The
open Wishbone boundary contract this exposes — "every accepted request is
eventually (here, in fact promptly and deterministically) acknowledged" —
is the same boundary the buggy litex slave violates; this file is the
positive witness, not the counterexample.

## Row 8 — byte-lane ordering on a narrow Wishbone slave, and why this file stands in for the boundary

**What this component's own wires show**: `i_wb_sel[3:0]` selects which
bytes of `i_wb_data` a write actually updates, per register, in a fixed,
documented mapping — for example, `UART_SETUP` writes use
`i_wb_sel[0]`→`uart_setup[7:0]`, `i_wb_sel[1]`→`[15:8]`,
`i_wb_sel[2]`→`[23:16]`, `i_wb_sel[3]`→`[30:24]` (with a fixed bit-31
convention baked in), and `UART_TXREG`/`UART_RXREG` writes/reads
consistently use `i_wb_sel[1]` for the control/error bits at
`[12]`/`[9]`/`[10]` and `i_wb_sel[0]` for the data byte at `[7:0]` — i.e.
this component has one single, fixed, self-consistent byte-lane-to-field
mapping across every register it exposes, on both read and write. Row 8's
documented hazard is a separate component (a 32-to-8-bit Wishbone width
downconverter, upstream of a narrow slave, itself Python/migen and not
retained here) whose sub-beat-to-byte-lane sequencing can disagree with
whatever fixed mapping the narrow slave downstream actually expects. This
file is retained as a concrete, real narrow-side Wishbone boundary — with
its own fixed, internally-consistent `i_wb_sel` convention laid out above —
to stand in for "the slave side of that boundary," since the actual
upstream converter artifact is not SystemVerilog/Verilog. Composed with a
converter whose beat/lane sequence does not match this component's
documented `i_wb_sel` mapping, specific byte lanes of the values this
component's registers actually hold would be written to (or read from) the
wrong bit range — the row-8 hazard — even though this component's own
wire-level mapping is fixed, documented, and internally consistent.
