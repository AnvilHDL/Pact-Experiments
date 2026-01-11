# CVA6 MMU

This directory contains Anvil implementations of the CVA6 Memory Management Unit (MMU) components: the Translation Lookaside Buffer (TLB) and Page Table Walker (PTW).

## Source Files

Located in `src/cva6/`:

- **`anvil_ptw.anvil`** - Anvil implementation of Page Table Walker
- **`anvil_tlb.anvil`** - Anvil implementation of TLB
- **`cva6_anvil_ptw.sv`** - SystemVerilog wrapper for Anvil PTW
- **`cva6_anvil_tlb.sv`** - Default CVA6 TLB wrapper

## Setup

Run the CVA6 setup script to configure the repository with all required dependencies:

```bash
# assuming you are in root directory of the repo (../../)
bash scripts/setup-cva6.sh
```

This script generates `scripts/env-cva6.sh`, which sets up environment variables for CVA6 simulations.

## Running Tests

### Baseline (SystemVerilog TLB/PTW)

Run CVA6 regression tests with the default SystemVerilog implementations:

```bash
# assuming you are in root directory of the repo (../../)
bash scripts/run-cva6-tests.sh
```

### Anvil Implementation

Run CVA6 regression tests with Anvil TLB and PTW:

```bash
# assuming you are in root directory of the repo (../../)
bash scripts/run-cva6-tests.sh --anvil
```

## Results

Test results are saved in the CVA6 repository at:

```
verif/sim/out_<date>/iss_regr.log
```

This log file contains regression test results comparing Verilator simulation outputs against the Spike ISS (Instruction Set Simulator). Both baseline and Anvil implementations should produce identical results, demonstrating functional equivalence with cycle-accurate behaviour.
