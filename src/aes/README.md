# AES Cipher Core

This directory contains an Anvil implementation of the AES Cipher Core, validated against the baseline SystemVerilog implementation from the OpenTitan IP library.

## Prerequisites

- Anvil (available in PATH)
- Verilator (installed and in PATH)
- Python 3
- OpenTitan repository as git submodule at `../../opentitan`

## Source Files

- **`aes_cipher_core.anvil`** - Anvil implementation of AES Cipher Core
- **`aes_helper_pkg.sv`** - SystemVerilog wrapper for AES Cipher Core
- **`aes_cipher_core_tb.anvil`** - Testbench for encryption and decryption

## Test Description

The testbench validates AES encryption and decryption operations using both AES-128 and AES-256 key sizes. The test encrypts plaintext and then decrypts the ciphertext, verifying that the output matches the original input.

## Running Anvil Implementation

```bash
make clean
make run MODULE_NAME=aes_cipher_core_tb
```

## Running SystemVerilog Baseline

To compare against the OpenTitan baseline implementation:

```bash
python3 create_testbench.py aes_cipher_core_tb aes_cipher_core --cleanup
cp ../../scripts/run_testbench.sh ../../opentitan/hw/ip/aes/rtl/
cd ../../opentitan/hw/ip/aes/rtl/
bash run_testbench.sh aes_cipher_core_tb
```

## Expected Output

Both Anvil and OpenTitan baseline implementations produce identical cycle-accurate results, demonstrating functional equivalence. The decrypted output should match the original plaintext for both AES-128 and AES-256 test cases.