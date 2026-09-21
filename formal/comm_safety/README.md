# Communication-safety checks

The SymbiYosys harnesses check closed RTL compositions: a DUT and its modeled
participants. Assertions cover handshake agreement, transaction accounting,
and bounded completion of open obligations. Each harness defines its own
properties, bounds, and reset assumptions.

The bounds turn progress obligations into safety assertions. These checks are
not a proof of the compiler's unbounded fairness semantics, and a completed
simulation trace is not a formal proof.

## Run

Install Yosys with the `slang` plugin, SymbiYosys, and Yices. EBMC is optional.
Initialize the dependencies described in the [root setup](../../README.md).
Before checking TileLink, generate its RTL:

```sh
bash scripts/build_tilelink_rtl.sh
```

Run a selected RTL check alongside its PACT compatibility check:

```sh
python3 scripts/run_comm_safety_timing.py --case fifo --mode 3 --timeout 300
```

Run only the RTL checks, or select multiple cases:

```sh
python3 scripts/run_comm_safety_timing.py --case fifo --skip-pact --timeout 300
python3 scripts/run_comm_safety_timing.py --phase all --mode 3 --jobs 4 --timeout 3600
```

`--checker both` also runs EBMC. `--setup-only --skip-pact` prepares SBY
work directories without proving the properties. `--timeout` applies separately
to each subprocess; omitting it leaves the run unbounded in wall-clock time.

## Results

Each run writes logs and `timing.csv` to a timestamped directory under
`formal/comm_safety/results/`. `--results-dir` selects an explicit directory.

`SETUP` means the work directory was prepared without running a proof.
`PASS` means the configured proof completed. `FAIL`, `UNKNOWN`, `TIMEOUT`,
`EXTERNAL_TIMEOUT`, and `ERROR` are distinct outcomes. In particular, an
unfinished induction step is not a successful proof.

The `.sby` files use `mode prove`; `depth` controls the bounded base case and
induction search. Inspect each case's source and solver output when interpreting
its result. Instrumentation guarded by `FORMAL_COMM_SAFETY` is inactive during
normal simulation.

The formal and simulation configurations can use different stimuli or bounds.
ACE's formal harness uses `ccu_fsm_tb.sv`; cycle equivalence uses
`ccu_fsm_tb2.sv`. Preserve this distinction when comparing measurements.
