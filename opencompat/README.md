# AXI communication-error cases

Small Pact demonstrations of the cases in the paper's appendix table *Completed AXI communication-error case studies*. Each directory under `originals/` holds:

- the upstream RTL, unmodified;
- `ISSUE.md`, a short description of the issue;
- `type_*.anvil`, Pact types and pools. There are no processes; the cases are checked on types only.

Each case has a pool that reproduces the mismatch, which Pact reports as incompatible, and a control pool that differs only in the order of messages, which Pact reports as compatible.

## Run

```sh
make opencompat                          # all cases, about a second
python3 scripts/run_opencompat.py --case axi_mux
```

Results are written to `results/opencompat_<time>/comparison.md` as `expected / measured`; expected verdicts are in `expected/opencompat.json`. To check one file by hand:

```sh
cd opencompat/originals/axi_mux
../../../scripts/pact -just-check -debug-choice 3 type_axi_mux.anvil
```

A **pairwise** case has both sides of the boundary in the pool. An **open** case leaves some channel ends unconnected; it is incompatible only if no environment on those ends can make it compatible. Pools are checked with the simultaneous check (`-debug-choice 3`).

## Cases

| Paper row | Setting | File | Incompatible | Compatible |
| --- | --- | --- | --- | --- |
| AXI debug BIU | Pairwise | `adbg_axi_biu/type_adbg_axi_biu.anvil` | `adbg_axi_biu_pool` | `adbg_axi_biu_aw_first_pool` |
| AXI test infrastructure | Pairwise | `axi_test/type_axi_test.anvil` | `axi_test_aw_then_w_pool` | `axi_test_fixed_pool` |
| AXI demux | Open | `axi_demux/type_demux_simplified.anvil` | `demux_simplified_w_first_pool` | `demux_simplified_aw_first_pool` |
| AXI per-ID monitor | Open | `axi_test/type_axi_per_id.anvil` | `axi_per_id_reuse_pool` | `axi_per_id_unique_pool` |
| AXI demux/mux pipeline | Open | `axi_mux/type_axi_pipeline.anvil` | `pipeline_w_first_pool` | `pipeline_w_first_stages`, `pipeline_aw_first_pool` |
| AXI mux | Open | `axi_mux/type_axi_mux.anvil` | `mux_w_first_pool` | `mux_aw_first_pool` |

In the pipeline, each stage handles a single channel, so `pipeline_w_first_stages` (the stages without their route FIFOs) accepts a client that sends W first. Adding the FIFOs fixes the order, and the same client is rejected.

The paper's main text also checks the benchmark AXI demux incrementally, with a client that sends W first. `axi_demux/type_axi_demux_stages.anvil` adds the benchmark's router stages one at a time. The client is accepted with 2 and 3 participants (`demux_w_first_2`, `demux_w_first_3`) and rejected with 4 of the router pool's 10 (`demux_w_first_4`).
