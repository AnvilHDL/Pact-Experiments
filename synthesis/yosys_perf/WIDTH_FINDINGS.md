# Yosys Perf Width And Structure Findings

## Current Baseline

The performance flow measures Anvil-generated core modules against SV synthesis tops from `scripts/yosys_perf_manifest.json`. The SV side now uses full Yosys synthesis via:

```text
read_slang --single-unit --top <top> ...
synth -top <top> -flatten
opt -purge
stat -json
```

Generated Anvil SV is sanitized only for synthesis artifacts: simulation `$display`-style debug statements are removed, and reset-only `always_ff` self-holds are made explicit for Yosys. The Anvil source processes themselves are not rewritten by the perf script.

## Width Alignment Status

| Case | Anvil Widths | SV Perf Widths | Status |
| --- | --- | --- | --- |
| FIFO | data `logic[2]`, depth 8 | `fifo_v3` data 2, depth 8 | Matched |
| Stream FIFO | data `logic[8]`, depth 8 | `passthrough_stream_fifo` data 8, depth 8 | Matched |
| Spill register | data `logic[8]` | `spill_register` data 8 | Matched |
| Arbiter | 4 requesters, 1-bit payload, 2-bit priority | `rr_arb_tree` `NumIn=4`, `DataWidth=1`, `LockIn=1` | Matched closely |
| AXI-lite demux/mux | addr 8, data 8, strb 1, select 2 | perf AXI-lite package addr 8, data 8, strb 1, select 2 | Matched |
| AXI-lite demux/mux write | addr 8, data 8, strb 1, prot 1, resp 1; 2 embedded FIFOs each side | perf AXI-lite package addr 8, data 8, strb 1, prot 1, resp 1; `fifo_v3` x2 each side | Matched (no width mismatch — high overhead ratio is genuine, see below) |
| ACE | `byte = logic[8]` for addr/data payloads | perf ACE package addr 8, data 8 | Fixed |
| TileLink | client select 1, data 8, manager/client id 1 | raw generated `TLCrossBar` data 8 | Payload width fixed in Anvil |

## ACE Notes

The original perf ACE package used `AxiAddrWidth = 32`, inherited from the SV testbench/wrapper. The Anvil model uses `byte = logic[8]` for request addresses and data, so the perf package now uses `AxiAddrWidth = 8` and `AxiDataWidth = 8`.

One residual mismatch remains intentional: `ccu_fsm` requires `SlvAxiIDWidth = 1` because it slices `id[SlvAxiIDWidth-1:0]` while constructing writeback IDs. Setting this to zero would require changing the SV DUT logic, not just the perf wrapper. Therefore the SV AXI ID has one extra slave-ID bit plus the 2-bit master index, while the Anvil request source is 2 bits. This is protocol metadata, not data/address width.

After this fix, the big-phase run reports ACE as comparable and passing:

```text
Anvil ace_main:      1228 cells, 179 sequential, 1049 combinational
SV perf_ace_sv:      1418 cells, 168 sequential, 1250 combinational
Anvil/SV cell ratio: 0.866
```

## TileLink Notes

The raw Chisel-generated `TLCrossBar` is a full TileLink module with 16-bit addresses and 8-bit data on A/B/C/D channels. The Anvil model is a reduced communication model: client request select is 1 bit, payload data is now 8 bits, and response routing uses a 1-bit client id.

The TileLink manifest intentionally measures raw `TLCrossBar`; it does not use a compat-width SV wrapper. The payload width fix is in the Anvil code:

- `client_ch`, `client_r_ch`, and `server_r_ch` TileLink pool endpoints now carry `logic[8]`;
- `data_pack_t.data` is now `logic[8]`;
- `test_tilelink.anvil` client/manager data registers and spawned component type arguments now use `logic[8]`.

This fixes the data-width mismatch without modifying or wrapping the SV TileLink design. The Anvil model still abstracts full TileLink address/opcode/param/mask metadata into a route-select protocol, so the TileLink performance number is a comparison against the full raw generated crossbar, not a bit-for-bit interface-equivalent Anvil model.

After widening the Anvil payloads and restoring raw `TLCrossBar`, the TileLink-only perf run reports:

```text
Anvil aggregate:     284 cells, 44 sequential, 240 combinational
SV raw TLCrossBar:   528 cells, 24 sequential, 504 combinational
Anvil/SV cell ratio: 0.538
```

## Structural Findings

The common-cell and AXI-lite width settings were already aligned. The larger Anvil cell counts there mostly come from generated synchronization machinery, such as event state, thread/event counters, and ready/send bookkeeping, rather than from wider payload datapaths.

For the arbiter, the standalone SV wrapper previously used `LockIn=0`. That made the wrapper too stateless for the Anvil protocol shape. It now uses `LockIn=1`, so the SV arbiter stores a selected requester while downstream is stalled. The SV arbiter still remains smaller because `rr_arb_tree` is a compact hand-written implementation and the Anvil output carries endpoint synchronization state.

## AXI Demux/Mux Write: Resolved Failures Were A Tooling Artifact, Not A Design Issue

`axi_demux_write` and `axi_mux_write` previously showed as `TIMEOUT`/`PRECHECK_FAIL` in the summary. This was misdiagnosed — the real cause is that `read_slang --single-unit --top X` only restricts *elaboration*, not whole-file syntax/semantic checking. An unrelated driver/testbench module elsewhere in the same generated file (e.g. `test_demux_write`, which uses SystemVerilog's `.clk_i`-style implicit port shorthand valid only in its own scope) still gets checked and can fail the whole run even though it is never instantiated under `--top`.

The fix (now in both `collect_yosys_perf.py` and `collect_real_synth_perf.py`) extracts each selected module's own `module ... endmodule` text into an isolated per-module file before synthesis, since Anvil's core-pattern modules never instantiate each other. Once isolated, both cases synthesize cleanly with no width or correctness issues:

```text
axi_demux_write anvil (demux_aw_main+demux_w_main+demux_b_main+fifo_0+fifo_1): 1540 cells, 204 seq, 1336 comb
axi_mux_write   anvil (mux_aw_main+mux_w_main+mux_b_main+arbiter_0+fifo_0+fifo_1): 2180 cells, 265 seq, 1915 comb
```

A width mismatch was suspected given how high these ratios run, but a full check (address/data/strb/prot/resp widths, and embedded FIFO instance counts on both sides) found everything matched — see the row added to the width table above. The overhead is genuine, not a data-width artifact.
