# AnvilHDL Evaluation Artefacts

This repository contains the experimental artefacts for evaluating [Anvil](https://github.com/jasonyu1996/anvil), organised into eight distinct experiments that demonstrate the functionality and correctness of designs written in Anvil compared to their SystemVerilog counterparts.

> **Note** : The minimum prerequisites for this artefact are a working [Docker](https://docs.docker.com/engine/install/) or [Podman](https://podman.io/docs/installation) installation and access to a Unix shell (bash is preferred to avoid syntax issues).

## Artefacts Overview

1. **FIFO Queue**
2. **Spill Register**
3. **Stream FIFO Buffer**
4. **AXI Lite Mux Router**
5. **AXI Demux Router**
6. **AES Cipher Core**
7. **Pipelined Designs**
   - Pipeline ALU
   - Pipelined Systolic Array
8. **CVA6 MMU (TLB and PTW)**

Each experiment includes test harnesses that verify functional correctness, cycle-accurate equivalence with baseline SystemVerilog implementations.


> The synthesis reports for the designs evaluated in these experiments can be found in the [`synthesis_reports/`](synthesis_reports/) directory. 

## Quick Start

The simplest way to reproduce all experiments is to use the provided push-button script:

```bash
bash run.sh <-r>
```

The optional `-r` flag forces a rebuild of the container image, otherwise if image does not exist, it will be built automatically.

This script runs all experiments sequentially and saves results to the `out/` directory, it actually runs the `run_artefact.py` script inside a container.

## Building and Running with Docker/Podman

The container image provides a pre-configured environment with all dependencies installed.
Below we assume you are using Docker. Replace `docker` with `podman` in the command if you are using Podman.

### Build the Container Image

From the root directory, run:

```bash
docker build -t anvil_experiments .
```

### Run All Experiments

Create an output directory and run the container:

```bash
mkdir -p out
docker run -it -v $(pwd)/out:/workspace/Anvil-Experiments/out anvil_experiments
```

### Interactive Shell

To explore the experiments interactively:

```bash
docker run -it -v $(pwd)/out:/workspace/Anvil-Experiments/out anvil_experiments /bin/bash
```

Once inside the container, you can run individual experiments or use the push-button script.

## Local Installation

If you prefer to run experiments without containerization, follow these steps:

### Prerequisites

1. **Install Anvil:**
   Follow the instructions at [Anvil Installation](https://project-starch.github.io/Anvil-Docs/installation.html)

2. **Install Verilator:**
   ```bash
   bash scripts/install_verilator.sh
   ```

3. **Initialize Submodules:**
   ```bash
   git submodule update --init --recursive
   ```

4. **Install Additional Dependencies:**
   Follow the installation instructions in each submodule's directory as needed.

### Run Experiments

Execute the main script from the root directory:

```bash
python3 run_artefact.py
```

Results will be saved to the `out/` directory.

## Individual Experiments

Each experiment can be run independently. Detailed instructions are provided in the following directories:

- **FIFO Queue, Spill Register, Stream FIFO Buffer:** [`src/common_cells/`](src/common_cells/)
- **Pipelined Designs:** [`src/filament/`](src/filament/)
- **AXI Lite Mux Router, AXI Demux Router:** [`src/axi/`](src/axi/)
- **AES Cipher Core:** [`src/aes/`](src/aes/)
- **CVA6 TLB and PTW:** [`src/cva6/`](src/cva6/)

## Experiment Descriptions

### 1. FIFO Queue
Tests push and pop operations, including overflow and underflow conditions. Verifies cycle-accurate equivalence between Anvil and SystemVerilog implementations.

### 2. Spill Register
Validates spill and fill operations with cycle-accurate output comparison.

### 3. Stream FIFO Buffer
Tests concurrent push and pop operations, as well as individual operations, ensuring identical behavior between implementations.

### 4. Pipelined Designs
Evaluates pipelined ALU and systolic array designs, comparing Anvil implementations against Filament baseline designs, on arithmetic operations and systolic array computations.

### 5. AXI Lite Mux Router
Simulates eight slave nodes communicating with a single master node via the AXI Lite protocol. Cycle-accurate traces confirm equivalence with the SystemVerilog reference.

### 6. AXI Demux Router
Tests a single slave node selecting between eight master nodes. Includes cycle-accurate trace comparison with the reference design.

### 7. AES Cipher Core
Performs encryption and decryption using AES-128 and AES-256 keys. Validates that decrypted output matches the original plaintext and provides cycle-accurate trace comparison.

### 8. CVA6 TLB and PTW
Runs RISC-V compliance tests on the CVA6 core with MMU enabled, comparing results from baseline SystemVerilog TLB/PTW against Anvil implementations. Validates equivalence between Verilator and Spike simulations.

## Expected Results

All experiments produce cycle-accurate output that matches between Anvil and baseline implementations. Results are saved in the `out/` directory with detailed logs for each test.


Sample output files are included in the `sample_out/` directory for reference.

### Summary of Validation

- **Experiments 1-3, 5-7:** Cycle-accurate output prints match exactly between Anvil and SystemVerilog.
- **Experiment 4:** Cycle-accurate output prints match exactly between Anvil and Filament.
- **Experiment 8:** RISC-V compliance test results match between SystemVerilog and Anvil implementations with equivalent cycle traces during regression tests between Spike and Verilator
## Resource Estimates


**Time Estimates:**

1. Container Build: ~60 minutes (one-time)
2. Running All Experiments: ~10 minutes

**Disk Space Estimates:** : Container Image: ~23 GB

**Expected Memory Usage During Simulation:**: <12 GB RAM


