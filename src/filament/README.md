# Pipelined ALU and Systolic Array

This directory contains experiments comparing Anvil and Filament implementations of pipelined designs: a pipelined ALU and a systolic array accelerator.


Ensure the following tools are installed and available in your PATH:
- Anvil
- Verilator

## Source Files

Located in the `src_files/` directory:

- **`Alu.anvil`** - Pipelined ALU implementation in Anvil
- **`Alu_tb.anvil`** - Testbench for the pipelined ALU
- **`SA.anvil`** - Systolic array accelerator implementation in Anvil
- **`SA_tb.anvil`** - Testbench for the systolic array accelerator

## Generated SystemVerilog Files

Located in the `sv_files/` directory:

- **`AluAnvil.sv`** - Generated SystemVerilog testbench for ALU from Anvil backend
- **`SAanvil.sv`** - Generated SystemVerilog testbench for systolic array from Anvil backend
- **`AluFil.sv`** - Filament ALU implementation wrapped with the same testbench
- **`SAfil.sv`** - Filament systolic array implementation wrapped with the same testbench

These pre-generated files are provided for convenience to facilitate direct comparison between Anvil and Filament implementations using identical test scenarios.

## Running the Experiments

Navigate to the SystemVerilog directory and execute the test suite:

```bash
cd sv_files/
make clean
make run all
```

This command sequence will:
1. Clean any previous build artifacts
2. Compile both Anvil and Filament implementations
3. Run all testbenches
4. Display results on the console

## Expected Output

Both testbenches (ALU and systolic array) produce cycle-accurate results for various operations. The output from Anvil and Filament implementations should match exactly, demonstrating functional equivalence.
