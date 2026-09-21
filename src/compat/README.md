# Protocols and processes

`type_*.anvil` defines interfaces and compatibility pools. `test_*.anvil` adds
process implementations and simulation stimuli. `complexity/` contains
additional protocol-size and topology inputs.

From the repository root:

```sh
make check
python3 run_compat.py 3 --only type_fifo,type_demux_read_2p --jobs 2
```

To compile and simulate one process model:

```sh
make -B -C src/compat run MODULE_NAME=test_demux_read LTOFF=1 COMPATOFF=1 SILENT=1 TIMEOUT=200
```

`LTOFF=1` disables lifetime checks. `COMPATOFF=1` skips compatibility games during
code generation; session type checking remains enabled. Run compatibility
separately with `run_compat.py`. `PACT_DIR` selects the compiler checkout.

The four-endpoint AXI models use combined master/slave interfaces. Their shared
`mux_commons.anvilh` implementation contains a one-entry FIFO: it starts empty,
accepts a push, and waits for a pop before accepting another entry.
The protocol also includes a neither-full-nor-empty branch; the concrete FIFO
implements the full branch after a push.

The two-endpoint router files are standalone protocol models. The unified mux
combines the read and write process models over shared memory. Its trace can be
checked against a saved run; the repository has no separate unified-mux RTL
reference test.

See [cycle equivalence](../../testbench.md) for the RTL comparison commands.
