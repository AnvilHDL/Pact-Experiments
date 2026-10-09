# Pact benchmarks

| File | Contents |
|---|---|
| `type_<benchmark>.anvil` | Interface types and the compatibility pool used for timing |
| `test_<benchmark>.anvil` | Process implementations of every pool member and the simulation stimulus |
| `type_*_2p.anvil`, `test_*_2p.anvil` | Two-party variants of the routers and ACE |
| `test_unified_mux*.anvil` | Combined read and write mux |
| `mux_commons.anvilh` | Shared process definitions of the AXI routers (8-entry FIFO, arbiters) |

Check one pool's compatibility (mode 3: simultaneous product of all members):

```sh
../../scripts/pact -just-check -debug-choice 3 -j 8 type_demux_read.anvil
```

Compile and simulate one benchmark:

```sh
make -B run MODULE_NAME=test_demux_read LTOFF=1 COMPATOFF=1 SILENT=1
```

`PACT_OPT` selects the optimization level (default 3), `COMPATOFF=1` skips the compatibility check during compilation, and `LTOFF=1` disables lifetime checks. `PACT_DIR` selects the compiler checkout (default `../../../Pact`).
