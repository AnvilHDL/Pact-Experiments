# AXI debug BIU

[pulpino #182](https://github.com/pulp-platform/pulpino/issues/182), `adbg_axi_biu.sv` lines 527–541.

In `S_AXIADDR` the manager drives `aw_valid` and `w_valid`, but leaves the state only when `aw_ready` is high. A W handshake that completes before AW is not recorded, so W is effectively sent only after AW. AXI allows a subordinate to accept W before AW; such a subordinate and this manager wait on each other.

Types: `type_adbg_axi_biu.anvil` (pairwise).
