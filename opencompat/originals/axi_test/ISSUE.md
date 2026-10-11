# AXI test infrastructure and per-ID monitor

`axi_test.sv` from pulp-platform/axi.

**Test infrastructure** ([changelog v0.15.1](https://github.com/pulp-platform/axi/blob/v0.15.1/CHANGELOG.md)). The earlier random manager sent W only after its AW had been accepted (`send_aw`, `send_w`, lines 80–104). A legal subordinate that raises `aw_ready` only after taking W then deadlocks with it. The fix lets W go before or with AW.
Types: `type_axi_test.anvil` (pairwise).

**Per-ID monitor.** With `UNIQUE_IDS` unset (line 1115), the manager may reuse an ID while a write with that ID is still outstanding. A monitor that assumes one outstanding write per ID cannot accept the second AW before the first B.
Types: `type_axi_per_id.anvil` (open: the subordinate is left out).
