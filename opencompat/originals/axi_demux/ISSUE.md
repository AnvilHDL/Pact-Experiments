# AXI demux

[`axi_demux.sv`](https://github.com/pulp-platform/axi/blob/e55ae2a7ee606ee3cfd4257f63982a971b704407/src/axi_demux.sv#L56-L92) from pulp-platform/axi, lines 56–92.

The demux routes W by the select it takes with AW (`slv_aw_select_i`), recorded in a FIFO. A W beat that arrives before its AW has no route yet, so the demux accepts W only after AW. AXI allows a manager to send W first.

Types: `type_demux_simplified.anvil` (open: the masters are left out) and `type_axi_demux_stages.anvil`, which adds the benchmark's router stages one at a time.
