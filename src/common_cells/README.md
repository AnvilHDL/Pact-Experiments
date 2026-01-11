# Common Cells

This directory contains Anvil implementations of common hardware building blocks, validated against baseline SystemVerilog implementations from the common_cells IP library.

## Prerequisites

- Verilator (installed and in PATH)
- Anvil (available in PATH)

## FIFO: First In First Out Queue

### Source Files

Located in `common_cells/`:

- **`fifo_wrapper.sv`** - Baseline FIFO from common_cells IP
- **`fifo.anvil`** - Anvil implementation of FIFO
- **`fifo_top.anvil`** - Top-level testbench for both implementations

### Test Sequence

The testbench validates the following operations:

1. Push data into FIFO
2. Attempt FIFO overflow
3. Pop data from FIFO
4. Attempt FIFO underflow

Both the baseline and Anvil FIFOs are tested identically, with cycle-accurate results printed to the console.

### Running the Test

```bash
make clean
make run MODULE_NAME=fifo_top
```

---

## Spill Register

### Source Files

Located in `common_cells/`:

- **`spill_reg.sv`** - Baseline Spill Register from common_cells IP
- **`spill_reg.anvil`** - Anvil implementation of Spill Register
- **`spill_reg_top.anvil`** - Top-level testbench for both implementations

### Test Sequence

The testbench validates the following operations:

1. Send data to Spill Register
2. Receive data from Spill Register
3. Test overflow condition
4. Test underflow condition

Both the baseline and Anvil Spill Registers are tested identically, with cycle-accurate results printed to the console.

### Running the Test

```bash
make clean
make run MODULE_NAME=spill_reg_top
```

---

## Stream FIFO

### Source Files

Located in `common_cells/`:

- **`passthrough_stream_fifo.anvil`** - Anvil passthrough Stream FIFO implementation
- **`stream_fifo.anvil`** - Anvil Stream FIFO implementation
- **`stream_fifo_top.anvil`** - Top-level testbench for Stream FIFO

### Test Sequence

The testbench validates the following operations:

1. Push data into Stream FIFO
2. Test concurrent read/write when FIFO is full
3. Pop data from Stream FIFO

Both the baseline and Anvil Stream FIFOs are tested identically, with cycle-accurate results printed to the console.

### Running the Test

```bash
make clean
make run MODULE_NAME=stream_fifo_top
```

---

## Expected Output

All tests produce cycle-accurate output that demonstrates functional equivalence between the baseline common_cells implementations and their Anvil counterparts. Results are displayed on the console during test execution.