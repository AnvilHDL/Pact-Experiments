# Communication-Safety Yosys Timing Plan

## Goal

Time bounded SV communication-safety proofs against Anvil `run_compat.py` for the case-study set.
All new SV assertions are enabled only by `FORMAL_COMM_SAFETY`; cycle-equivalence Verilator traces are unchanged.

## Commands

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

Run SBY plus EBMC proof mode:

```sh
python3 scripts/run_comm_safety_timing.py --phase short --mode 4 --checker both
```

By default the runner runs the full SymbiYosys model checker for each selected `.sby` file with `sby -f`; it is not just doing setup/elaboration. For frontend-only debugging there is an explicit opt-in `--setup-only` flag.

When `--checker ebmc` or `--checker both` is selected, the runner derives the top module, defines, include paths, source list, and bound from the `.sby` `read_slang` command and invokes EBMC in proof mode with `--k-induction --liveness-to-safety`.

The runner emits per-case SBY logs in `formal/comm_safety/results/<case>.log`, per-case Anvil logs in `formal/comm_safety/results/<case>.anvil.log`, and aggregate timing in `formal/comm_safety/results/timing.csv`.

## Phase 1: Short Cases

| Case | SV Harness | SBY | Anvil Type | Status |
| --- | --- | --- | --- | --- |
| FIFO | `comm_fifo_formal` | `fifo.sby` | `type_fifo.anvil` | Implemented; SBY PASS at depth 16 |
| Spill register | `comm_spill_formal` | `spill_register.sby` | `type_spill_reg.anvil` | Implemented; SBY PASS at depth 16 |
| Stream FIFO | `comm_stream_fifo_formal` | `stream_fifo.sby` | `type_stream_fifo.anvil` | Implemented; validation interrupted before result |
| Arbiter | `comm_arbiter_formal` | `arbiter.sby` | `type_arbiter.anvil` | Implemented; SBY PASS at depth 16; EBMC frontend fails on `cf_math_pkg.sv` |
| AXI demux read | `comm_axi_demux_read_formal` | `axi_demux_read.sby` | `type_demux_read.anvil` | Implemented; SBY PASS at depth 48 |

## Phase 2: Bigger Cases

| Case | SV Harness | SBY | Anvil Type | Status |
| --- | --- | --- | --- | --- |
| AXI demux write | `comm_axi_demux_write_formal` | `axi_demux_write.sby` | `type_demux_write.anvil` | Implemented |
| AXI mux read | `comm_axi_mux_read_formal` | `axi_mux_read.sby` | `type_mux_read_simplified.anvil` | Implemented |
| AXI mux write | `comm_axi_mux_write_formal` | `axi_mux_write.sby` | `type_mux_write_simplified.anvil` | Implemented |
| ACE | `comm_ace_formal` | `ace.sby` | `type_ace.anvil` | Implemented |
| TileLink | `comm_tilelink_formal` | `tilelink.sby` | `type_tilelink.anvil` | Implemented |

## Current Validation Snapshot

Completed checks:

- `python3 -m py_compile run_compat.py scripts/run_comm_safety_timing.py` passed.
- `sby -f -d formal/comm_safety/results/sby_fifo_check formal/comm_safety/fifo.sby` passed with `yices`, depth 16, about 30 seconds.
- `sby -f -d formal/comm_safety/results/sby_spill_check formal/comm_safety/spill_register.sby` passed with `yices`, depth 16, about 2 seconds.
- `sby -f -d formal/comm_safety/results/sby_axi_demux_read_check formal/comm_safety/axi_demux_read.sby` passed with `yices`, depth 48, about 1 second.
- `python3 scripts/run_comm_safety_timing.py --phase short --case fifo --skip-anvil` passed the Yosys side and wrote `formal/comm_safety/results/timing.csv`.
- `python3 scripts/run_comm_safety_timing.py --phase short --case arbiter --skip-anvil --checker both` ran full SBY plus EBMC. SBY passed; EBMC ran in proof mode and failed during frontend parsing of `cf_math_pkg.sv`.
- `python3 run_compat.py 4 --only type_fifo.anvil --csv /tmp/compat_fifo.csv` exercised the new CSV path. Under sandbox it reports `Error` because Dune cannot write `_build/log`; with escalation it completes and records the current `type_fifo.anvil` result as `Incompatible`.

Known open items:

- EBMC support is scripted, but older EBMC 5.6 does not parse at least `common_cells/src/cf_math_pkg.sv`; either add EBMC-friendly source shims for affected cases or restrict EBMC runs to cases its frontend can parse.
- `stream_fifo.sby` was running when the last validation attempt was interrupted; rerun after the arbiter SBY source fix.
- Phase 2 SBY files are implemented but not yet validated. ACE may need a small `FORMAL_COMM_SAFETY` guard around testbench `$finish` if Slang/Yosys rejects it during elaboration.
- Full Anvil timing through `scripts/run_comm_safety_timing.py` needs escalation or an environment where `./run_anvil` can write Dune `_build` outputs.

## Assertion Scope

Bounded liveness is encoded with shadow pending state and age counters. For unconstrained producer/consumer tests, the harness constrains illegal push/pop attempts where the SV module expects command-style control rather than a fully decoupled ready/valid environment.

Primary communication-safety intent: when one side treats a peer wire value as a newly accepted input, the peer side must be synchronized for that exact exchange in the same cycle. The route/order queues are secondary bookkeeping used to compare the values that crossed those synchronized handshakes later.

Deadlock freedom is treated as liveness: every recorded pending exchange has a bounded age counter, and EBMC proof mode can also be used with liveness-to-safety translation. The bounded age assertions are the common denominator for SBY BMC and EBMC k-induction.

Safety coverage:

- FIFO and stream FIFO: no underflow/overflow on legal transfers, data order, bounded drain.
- Spill register: accepted input appears once at output, occupancy never exceeds two, bounded drain.
- Arbiter: grant implies request, one-hot grant, persistent request eventually served within the bounded window.
- AXI demux/mux: accepted route/source is queued and checked on response return; response without a recorded request is rejected.
- ACE: request/response ID matching for CCU-facing traffic, memory response matching, snoop CR/CD matching.
- TileLink: A-channel target accounting, D-channel source routing back to the initiating client.

## Compatibility Runner Changes

`run_compat.py` keeps the existing form:

```sh
python3 run_compat.py 4
```

New optional flags:

```sh
python3 run_compat.py 4 --only type_fifo.anvil,type_stream_fifo.anvil --csv formal/comm_safety/results/anvil.csv
```

## Equivalence Scripts To Keep Green

The case-study cycle-equivalence scripts currently live in the root `scripts/` directory:

- `scripts/run_ace_cycle_equiv.sh`
- `scripts/run_axi_demux_read_cycle_equiv.sh`
- `scripts/run_axi_demux_write_cycle_equiv.sh`
- `scripts/run_axi_mux_read_cycle_equiv.sh`
- `scripts/run_axi_mux_write_cycle_equiv.sh`
- `scripts/run_tilelink_cycle_equiv.sh`

`opentitan/ci/scripts` was not the location of these root case-study runners in this checkout.

## Timing Log

Fill this table after each timing run.

| Date | Phase | Command | Result CSV | Notes |
| --- | --- | --- | --- | --- |
| 2026-07-07 | FIFO Yosys smoke | `python3 scripts/run_comm_safety_timing.py --phase short --case fifo --skip-anvil` | `formal/comm_safety/results/timing.csv` | PASS; Anvil skipped |
| 2026-07-07 | Manual short checks | FIFO, spill register, AXI demux read SBY commands above | Per-case SBY workdirs in `formal/comm_safety/results/` | PASS for those three; arbiter source-list issue found |
| 2026-07-07 | Arbiter backend smoke | `python3 scripts/run_comm_safety_timing.py --phase short --case arbiter --skip-anvil --checker both` | `formal/comm_safety/results/timing.csv` | SBY PASS; EBMC frontend FAIL on `cf_math_pkg.sv` |
