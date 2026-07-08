# PACT Experiment Runbook

This file is the quick entry point for running the different parts of the Anvil/SV case-study experiment.

## Prerequisites

Run commands from the repository root:

```sh
cd /home/aditya/Workspace/Anvil-Experiments
```

Expected tools on `PATH`:

- `anvil`
- `verilator`
- `yosys` with the `slang` plugin
- `sby` for SymbiYosys checks
- `ebmc` for optional EBMC proof runs
- `make`, `python3`

Most generated artifacts are intentionally ignored under:

```text
formal/comm_safety/results/
synthesis_reports/yosys_perf_results/
```

## Cycle Equivalence

These scripts run the SV testbench and the matching Anvil compat test back to back, then compare cycle-level behavior.

Run all common-cell cases:

```sh
./scripts/run_common_cells_cycle_equiv.sh
```

Run individual larger cases:

```sh
./scripts/run_axi_demux_read_cycle_equiv.sh
./scripts/run_axi_demux_write_cycle_equiv.sh
./scripts/run_axi_mux_read_cycle_equiv.sh
./scripts/run_axi_mux_write_cycle_equiv.sh
./scripts/run_ace_cycle_equiv.sh
./scripts/run_tilelink_cycle_equiv.sh
```

The Anvil side of these scripts uses files in:

```text
src/compat/
```

## Direct Anvil Compat Runs

Use `run_compat.py` for type/compat timing across Anvil files.

Default comparison mode:

```sh
python3 run_compat.py 4
```

Run selected files only:

```sh
python3 run_compat.py 4 --only type_fifo.anvil,type_stream_fifo.anvil,type_arbiter.anvil
```

Write a timing CSV:

```sh
python3 run_compat.py 4 --csv formal/comm_safety/results/anvil_compat.csv
```

Direct single-test Anvil type/session check:

```sh
./run_anvil -jc src/compat/test_tilelink.anvil
```

For the original compat Makefile flow, run from `src/compat`:

```sh
cd src/compat
make run MODULE_NAME=test_ace LTOFF=1 COMPAT=1
```

## Communication Safety And Liveness

The communication-safety work is under:

```text
formal/comm_safety/
```

The timing driver runs model checking and Anvil compat timing in one command.

Short phase:

```sh
python3 scripts/run_comm_safety_timing.py --phase short --mode 4
```

Big phase:

```sh
python3 scripts/run_comm_safety_timing.py --phase big --mode 4
```

All cases:

```sh
python3 scripts/run_comm_safety_timing.py --phase all --mode 4
```

Run only selected cases:

```sh
python3 scripts/run_comm_safety_timing.py --case fifo --case axi_demux_read --mode 4
```

Use EBMC instead of SymbiYosys, or both:

```sh
python3 scripts/run_comm_safety_timing.py --phase short --checker ebmc
python3 scripts/run_comm_safety_timing.py --phase short --checker both
```

Set up SBY workdirs without running the full checker:

```sh
python3 scripts/run_comm_safety_timing.py --phase short --setup-only
```

Direct SBY run for one case:

```sh
sby -f formal/comm_safety/fifo.sby
```

Outputs:

```text
formal/comm_safety/results/<case>.log
formal/comm_safety/results/timing.csv
formal/comm_safety/results/sby_<case>/
```

## Yosys Performance Collection

The performance collection flow compares Anvil-generated core modules against SV core components using Yosys synthesis statistics. It reports cell/area proxy metrics, not real activity-based power.

Smoke test:

```sh
python3 scripts/collect_yosys_perf.py --case fifo --variant both --strict
```

Short phase:

```sh
python3 scripts/collect_yosys_perf.py --phase short --variant both
```

Big phase:

```sh
python3 scripts/collect_yosys_perf.py --phase big --variant both
```

All cases:

```sh
python3 scripts/collect_yosys_perf.py --phase all --variant both
```

Selected case and variant:

```sh
python3 scripts/collect_yosys_perf.py --case tilelink --variant both
python3 scripts/collect_yosys_perf.py --case ace --variant sv
```

Include normally ignored test actors/neighbors:

```sh
python3 scripts/collect_yosys_perf.py --phase short --include-neighbors
```

Use a longer timeout for slow Anvil codegen:

```sh
python3 scripts/collect_yosys_perf.py --phase big --variant both --timeout-seconds 240
```

Outputs:

```text
synthesis_reports/yosys_perf_results/generated/<case>/
synthesis_reports/yosys_perf_results/logs/<case>/<variant>/
synthesis_reports/yosys_perf_results/json/<case>/<variant>/
synthesis_reports/yosys_perf_results/summary.csv
synthesis_reports/yosys_perf_results/summary.json
synthesis_reports/yosys_perf_results/summary.md
```

The manifest for case mappings and ignored-neighbor patterns is:

```text
scripts/yosys_perf_manifest.json
```

Width and structure notes for the current perf setup are in:

```text
synthesis/yosys_perf/WIDTH_FINDINGS.md
```

## Phase Split

Short cases:

```text
fifo
spill_register
stream_fifo
arbiter
axi_demux_read
```

Big cases:

```text
axi_demux_write
axi_mux_read
axi_mux_write
ace
tilelink
```

## Useful Cleanup

Most result files are ignored. To manually remove generated reports:

```sh
rm -rf formal/comm_safety/results synthesis_reports/yosys_perf_results
```

Use the cleanup command only when you do not need the current logs or summaries.
