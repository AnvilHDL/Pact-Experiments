#!/bin/bash

# Determine the workspace root by finding the Anvil-Experiments directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Find workspace root - look for common_cells directory as anchor
find_workspace_root() {
    local dir="$1"
    while [ "$dir" != "/" ]; do
        if [ -d "$dir/common_cells" ] && [ -d "$dir/axi" ]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

WORKSPACE_ROOT=$(find_workspace_root "$SCRIPT_DIR")
if [ -z "$WORKSPACE_ROOT" ]; then
    echo "Error: Could not find workspace root (looking for common_cells and axi directories)"
    exit 1
fi

# Define paths relative to workspace root
COMMON_CELLS_DIR="$WORKSPACE_ROOT/common_cells"
AXI_DIR="$WORKSPACE_ROOT/axi"

if [ -z "$1" ]; then
    echo "Usage: $0 <TESTBENCH_NAME> [TIMEOUT]"
    echo "Example: $0 axi_lite_demux_tb 10000"
    exit 1
fi

TESTBENCH_NAME=$1
TIMEOUT=${2:-10000}

TESTBENCH_PATH_FILE=$(realpath "$TESTBENCH_NAME.sv")
echo "Testbench path file: $TESTBENCH_PATH_FILE"

cat > demux.flist << EOF
+incdir+${COMMON_CELLS_DIR}/include
+incdir+${AXI_DIR}/include
${COMMON_CELLS_DIR}/src/cb_filter_pkg.sv
${COMMON_CELLS_DIR}/src/cc_onehot.sv
${COMMON_CELLS_DIR}/src/cdc_reset_ctrlr_pkg.sv
${COMMON_CELLS_DIR}/src/cf_math_pkg.sv
${COMMON_CELLS_DIR}/src/clk_int_div.sv
${COMMON_CELLS_DIR}/src/credit_counter.sv
${COMMON_CELLS_DIR}/src/delta_counter.sv
${COMMON_CELLS_DIR}/src/ecc_pkg.sv
${COMMON_CELLS_DIR}/src/edge_propagator_tx.sv
${COMMON_CELLS_DIR}/src/exp_backoff.sv
${COMMON_CELLS_DIR}/src/fifo_v3.sv
${COMMON_CELLS_DIR}/src/gray_to_binary.sv
${COMMON_CELLS_DIR}/src/isochronous_4phase_handshake.sv
${COMMON_CELLS_DIR}/src/isochronous_spill_register.sv
${COMMON_CELLS_DIR}/src/lfsr.sv
${COMMON_CELLS_DIR}/src/lfsr_16bit.sv
${COMMON_CELLS_DIR}/src/lfsr_8bit.sv
${COMMON_CELLS_DIR}/src/lossy_valid_to_stream.sv
${COMMON_CELLS_DIR}/src/mv_filter.sv
${COMMON_CELLS_DIR}/src/onehot_to_bin.sv
${COMMON_CELLS_DIR}/src/plru_tree.sv
${COMMON_CELLS_DIR}/src/passthrough_stream_fifo.sv
${COMMON_CELLS_DIR}/src/popcount.sv
${COMMON_CELLS_DIR}/src/rr_arb_tree.sv
${COMMON_CELLS_DIR}/src/rstgen_bypass.sv
${COMMON_CELLS_DIR}/src/serial_deglitch.sv
${COMMON_CELLS_DIR}/src/shift_reg.sv
${COMMON_CELLS_DIR}/src/shift_reg_gated.sv
${COMMON_CELLS_DIR}/src/spill_register.sv
${COMMON_CELLS_DIR}/src/spill_register_flushable.sv
${COMMON_CELLS_DIR}/src/stream_demux.sv
${COMMON_CELLS_DIR}/src/stream_filter.sv
${COMMON_CELLS_DIR}/src/stream_fork.sv
${COMMON_CELLS_DIR}/src/stream_intf.sv
${COMMON_CELLS_DIR}/src/stream_join_dynamic.sv
${COMMON_CELLS_DIR}/src/stream_mux.sv
${COMMON_CELLS_DIR}/src/stream_throttle.sv
${COMMON_CELLS_DIR}/src/sub_per_hash.sv
${COMMON_CELLS_DIR}/src/sync.sv
${COMMON_CELLS_DIR}/src/sync_wedge.sv
${COMMON_CELLS_DIR}/src/unread.sv
${COMMON_CELLS_DIR}/src/read.sv
${COMMON_CELLS_DIR}/src/addr_decode_dync.sv
${COMMON_CELLS_DIR}/src/cdc_2phase.sv
${COMMON_CELLS_DIR}/src/cdc_4phase.sv
${COMMON_CELLS_DIR}/src/clk_int_div_static.sv
${COMMON_CELLS_DIR}/src/addr_decode.sv
${COMMON_CELLS_DIR}/src/addr_decode_napot.sv
${COMMON_CELLS_DIR}/src/multiaddr_decode.sv
${COMMON_CELLS_DIR}/src/lzc.sv
${AXI_DIR}/src/axi_pkg.sv
${AXI_DIR}/src/axi_lite_demux.sv
${TESTBENCH_PATH_FILE}
EOF


ROOT=$(realpath "./")


cat > "$ROOT/sim_main.cpp" << EOF
#include <memory>
#include <iostream>
#include <verilated.h>
#include "V${TESTBENCH_NAME}.h"

double sc_time_stamp() { return 0; }

int main(int argc, char** argv) {
    unsigned timeout = ${TIMEOUT};
    if (argc > 1) {
        timeout = std::atoi(argv[1]);
    }

    std::cout << "Starting ${TESTBENCH_NAME} simulation (timeout: " << timeout << " cycles)" << std::endl;

    Verilated::mkdir("logs");
    const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext};
    contextp->debug(0);
    contextp->randReset(2);
    contextp->traceEverOn(true);
    contextp->commandArgs(argc, argv);

    const std::unique_ptr<V${TESTBENCH_NAME}> top{new V${TESTBENCH_NAME}{contextp.get(), "TOP"}};

    top->clk_i = 0;
    top->rst_ni = 0;

    unsigned time_cnt = 0;

    while (!contextp->gotFinish() && time_cnt < timeout) {
        contextp->timeInc(1);
        top->clk_i = !top->clk_i;

        if (!top->clk_i) {
            if (contextp->time() > 1 && contextp->time() < 10) {
                top->rst_ni = 0;  // Assert reset
            } else {
                top->rst_ni = 1;  // Deassert reset
            }
        }

        top->eval();
        ++time_cnt;
        
        if (time_cnt % 1000 == 0 && time_cnt > 0) {
            std::cout << "Progress: " << time_cnt << "/" << timeout << " cycles" << std::endl;
        }
    }

    top->final();
    
    if (contextp->gotFinish()) {
        std::cout << "Simulation completed with \\\\$finish at cycle " << time_cnt << std::endl;
    } else {
        std::cout << "Simulation reached timeout at cycle " << time_cnt << std::endl;
    }
    
    contextp->statsPrintSummary();
    return 0;
}
EOF

# Set up Verilator flags properly
VERILATOR_FLAGS=(
    -Wno-fatal
    --cc
    --exe
    --build
    --timing
    --top
    "$TESTBENCH_NAME"
    -j
    4
    -Wall
    -Wno-PINCONNECTEMPTY
    -Wno-ASSIGNDLY
    -Wno-DECLFILENAME
    -Wno-UNUSED
    -Wno-UNDRIVEN
    -Wno-UNOPTFLAT
    -Wno-WIDTHCONCAT
    -Wno-WIDTHEXPAND
    -Wno-VARHIDDEN
    -Wno-EOFNEWLINE
    -Wno-GENUNNAMED
    -Wno-SYNCASYNCNET
    -Wwarn-UNSUPPORTED
    -Wno-LITENDIAN
    -Wno-UNPACKED
    -Wno-STMTDLY
    -I"$ROOT/include"
)

# Check if required files exist
if [ ! -f "axi_pkg.sv" ]; then
    echo "Error: axi_pkg.sv not found in current directory"
    exit 1
fi

if [ ! -f "axi_lite_demux.sv" ]; then
    echo "Error: axi_lite_demux.sv not found in current directory"
    exit 1
fi

# Run Verilator
echo "Running Verilator with testbench: $TESTBENCH_NAME"
echo "Timeout set to: $TIMEOUT cycles"

# Check if testbench file exists
if [ ! -f "${TESTBENCH_NAME}.sv" ]; then
    echo "Error: ${TESTBENCH_NAME}.sv not found in current directory"
    exit 1
fi

verilator -f demux.flist "${VERILATOR_FLAGS[@]}" -top "$TESTBENCH_NAME" "$ROOT/sim_main.cpp"




if [ $? -eq 0 ]; then
    echo "Compilation successful. Running simulation..."
    ./obj_dir/V${TESTBENCH_NAME} $TIMEOUT
else
    echo "Compilation failed!"
    exit 1
fi
