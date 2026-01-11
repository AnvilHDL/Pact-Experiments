# AXI Lite Routers

This directory contains Anvil implementations of AXI Lite routing components: a multiplexer (mux) router and a demultiplexer (demux) router.

## Prerequisites

- Anvil (available in PATH)
- Verilator (installed and in PATH)
- Python 3
- Baseline AXI repository as git submodule at `../../axi`

---

## AXI Lite Mux Router

### Source Files

Located in `axi/`:

- **`axi_lite_mux.anvil`** - Anvil implementation of AXI Lite Mux
- **`axi_lite_mux_top.anvil`** - Top-level testbench for AXI Lite Mux

### Test Description

Tests communication between 8 slave nodes and a single master node routed through the mux router. Results are printed to the console.

### Running Anvil Implementation

```bash
make clean
make run MODULE_NAME=axi_lite_mux_top
```

### Running SystemVerilog Baseline

```bash
python3 create_testbench.py axi_lite_mux_top axi_lite_mux
cp ../../scripts/run_axi_veri.sh ../../axi/src/
cd ../../axi/src/
bash run_axi_veri.sh axi_lite_mux_top
```

---

## AXI Demux Router

### Source Files

Located in `axi/`:

- **`axi_demux.anvil`** - Anvil implementation of AXI Demux Router
- **`axi_router_top.anvil`** - Top-level testbench for AXI Demux Router

### Test Description

Tests a single slave node selecting among 8 master nodes routed through the demux router. Results are printed to the console.

### Running Anvil Implementation

```bash
make clean
make run MODULE_NAME=axi_router_top
```

### Running SystemVerilog Baseline

```bash
python3 create_testbench.py axi_router_top axi_demux
cp ../../scripts/run_axi_veri.sh ../../axi/src/
cd ../../axi/src/
bash run_axi_veri.sh axi_router_top
```

---

## Expected Output

Both Anvil and SystemVerilog baseline implementations produce identical cycle-accurate traces, demonstrating functional equivalence of the routing logic.