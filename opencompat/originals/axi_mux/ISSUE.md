# AXI mux

[`axi_mux.sv`](https://github.com/pulp-platform/axi/blob/e55ae2a7ee606ee3cfd4257f63982a971b704407/src/axi_mux.sv#L34-L162) from pulp-platform/axi.

When a client's AW wins arbitration, its index is pushed into a W FIFO (lines 301–303). W is taken only from the client at the head of that FIFO (lines 353–366). A client that sends W before AW is therefore never served.

Types: `type_axi_mux.anvil` (open: the other client and the manager are left out) and `type_axi_pipeline.anvil`, a demux feeding a mux, built one stage at a time.
