# Cycle equivalence

Each script compiles a tracked RTL testbench and its matching Pact process
model. The simulations emit timestamped events, which the script compares after
normalizing whitespace and event ordering within a cycle. Cycle numbers,
payloads, and event counts must agree. A build failure or trace mismatch returns
a nonzero exit status.

Run all cases with `make equiv`. Run scripts sequentially because they share
`src/compat/obj_dir`.

| Cases | Script | Output directory |
| --- | --- | --- |
| FIFO, stream FIFO, spill register, arbiter | `scripts/run_common_cells_cycle_equiv.sh` | `results/equiv/common_cells/` |
| Read demux | `scripts/run_axi_demux_read_cycle_equiv.sh` | `results/equiv/axi/demux_read_cycle_equiv/` |
| Write demux | `scripts/run_axi_demux_write_cycle_equiv.sh` | `results/equiv/axi/demux_write_cycle_equiv/` |
| Read mux | `scripts/run_axi_mux_read_cycle_equiv.sh` | `results/equiv/axi/mux_read_cycle_equiv/` |
| Write mux | `scripts/run_axi_mux_write_cycle_equiv.sh` | `results/equiv/axi/mux_write_cycle_equiv/` |
| ACE | `scripts/run_ace_cycle_equiv.sh` | `results/equiv/ace/cycle_equiv/` |
| TileLink | `scripts/run_tilelink_cycle_equiv.sh` | `results/equiv/tilelink/tilelink_cycle_equiv/` |

Each directory contains raw logs, normalized `*.logic.log` traces, build logs,
and `logic.diff`. An empty diff with a successful script exit indicates a match.
These directories are reused by later runs, so copy results before rerunning a
comparison that needs to be retained.

## Inputs and checks

The scripts read their DUT and testbench sources from `src/testbenches/`, with
support modules from pinned submodules. TileLink RTL is generated from the
[versioned Scala configuration](src/tilelink_generator/README.md).

Session type checking is enabled by default; compatibility games run separately.
`SV_TIMEOUT` and `PACT_TIMEOUT`, where supported by a script, select simulation
step budgets rather than wall-clock limits. A changed budget must still cover
the same events on both sides.

The AXI tests exercise sequential requests and responses across four endpoints.
The Pact router models use 8-entry bookkeeping FIFOs, as the RTL does
(`MaxTrans = 8`). The supplied traces match the RTL stimuli; this does not
establish equivalence for arbitrary traffic.

ACE uses `ccu_fsm_tb2.sv` with `ACE_TB_DUT_TRACE` and compares independently
simulated DUT and process events. Its formal harness uses `ccu_fsm_tb.sv`, which
is a separate verification configuration.

TileLink uses two clients and two managers with 8-bit data. Its RTL is rebuilt
by `scripts/build_tilelink_rtl.sh` before simulation.
