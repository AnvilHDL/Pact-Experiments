#!/bin/bash

# General OpenTitan Testbench Runner
# Usage: ./run_testbench.sh <testbench_name> [timeout_cycles]

set -e

# Configuration
DEFAULT_TIMEOUT=10000


RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'


log_info() { echo -e "[INFO] $1"; }
log_success() { echo -e "[SUCCESS] $1"; }
log_warning() { echo -e "[WARNING] $1"; }
log_error() { echo -e "[ERROR] $1"; }

show_usage() {
    echo "Usage: $0 <testbench_name> [options]"
    echo ""
    echo "Options:"
    echo "  -d <deps>         Comma-separated list of additional dependency files"
    echo "  -in <file>        Input testbench file (overrides default search)"
    echo "  -t <cycles>       Timeout in cycles (default: $DEFAULT_TIMEOUT)"
    echo "  -f <files>        Comma-separated list of additional source files"
    echo "  -I <dirs>         Comma-separated list of include directories"
    echo "  -D <defines>      Comma-separated list of defines (format: NAME or NAME=VALUE)"
    echo "  --vflags <flags>  Additional Verilator flags (quoted string)"
    echo "  --trace           Enable VCD tracing"
    echo "  --coverage        Enable coverage collection"
    echo "  -h, --help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 my_testbench"
    echo "  $0 -d aes_core.sv,aes_cipher.sv -t 50000 my_testbench"
    echo "  $0 -f extra1.sv,extra2.sv -I ../include,../common my_testbench"
    echo "  $0 -D DEBUG=1,VERBOSE --trace my_testbench"
    echo "  $0 --vflags '--timing --threads 8' my_testbench"
}


if [[ $# -lt 1 ]]; then
    log_error "Missing testbench name"
    show_usage
    exit 1
fi

TESTBENCH_NAME=""
TIMEOUT="$DEFAULT_TIMEOUT"
ADDITIONAL_FILES=()
INCLUDE_DIRS=()
DEFINES=()
ADDITIONAL_VFLAGS=""
ENABLE_TRACE=false
ENABLE_COVERAGE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            show_usage
            exit 0
            ;;
        -d)
            shift
            if [[ $# -lt 1 ]]; then
                log_error "Missing dependencies argument"
                show_usage
                exit 1
            fi
            AES_DEPS_IN="$1"
            IFS=',' read -r -a AES_DEPS_LIST <<< "$AES_DEPS_IN"
            shift
            ;;
        -in)
            shift
            if [[ $# -lt 1 ]]; then
                log_error "Missing input file argument"
                show_usage
                exit 1
            fi
            TESTBENCH_FILE="$1"
            shift
            ;;
        -t)
            shift
            if [[ $# -lt 1 ]]; then
                log_error "Missing timeout argument"
                show_usage
                exit 1
            fi
            TIMEOUT="$1"
            shift
            ;;
        -f)
            shift
            if [[ $# -lt 1 ]]; then
                log_error "Missing files argument"
                show_usage
                exit 1
            fi
            IFS=',' read -r -a FILE_LIST <<< "$1"
            ADDITIONAL_FILES+=("${FILE_LIST[@]}")
            shift
            ;;
        -I)
            shift
            if [[ $# -lt 1 ]]; then
                log_error "Missing include directories argument"
                show_usage
                exit 1
            fi
            IFS=',' read -r -a INCLUDE_LIST <<< "$1"
            INCLUDE_DIRS+=("${INCLUDE_LIST[@]}")
            shift
            ;;
        -D)
            shift
            if [[ $# -lt 1 ]]; then
                log_error "Missing defines argument"
                show_usage
                exit 1
            fi
            IFS=',' read -r -a DEFINE_LIST <<< "$1"
            DEFINES+=("${DEFINE_LIST[@]}")
            shift
            ;;
        --vflags)
            shift
            if [[ $# -lt 1 ]]; then
                log_error "Missing Verilator flags argument"
                show_usage
                exit 1
            fi
            ADDITIONAL_VFLAGS="$1"
            shift
            ;;
        --trace)
            ENABLE_TRACE=true
            shift
            ;;
        --coverage)
            ENABLE_COVERAGE=true
            shift
            ;;
        *)
            if [[ -z "$TESTBENCH_NAME" ]]; then
                TESTBENCH_NAME="$1"
            else
                TIMEOUT="$1"
            fi
            shift
            ;;
    esac
done


if [[ -z "$TESTBENCH_NAME" ]]; then
    log_error "Missing testbench name"
    show_usage
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RTL_DIR="$SCRIPT_DIR"



log_info "OpenTitan Testbench Runner"
log_info "Testbench: $TESTBENCH_NAME"
log_info "Timeout: $TIMEOUT cycles"

# Find testbench file
TESTBENCH_FILE=${TESTBENCH_NAME}.sv
# for ext in ".sv" ".anvil.sv" "_tb.sv" "_tb.anvil.sv"; do
#     if [[ -f "$RTL_DIR/${TESTBENCH_NAME}${ext}" ]]; then
#         TESTBENCH_FILE="$RTL_DIR/${TESTBENCH_NAME}${ext}"
#         break
#     fi
# done

# cp ../../../../../src/aes/"$TESTBENCH_FILE" "$RTL_DIR"
if [[ -z "$TESTBENCH_FILE" ]]; then
    log_error "Could not find testbench file for '$TESTBENCH_NAME'"
    exit 1
fi

log_success "Found testbench: $(basename "$TESTBENCH_FILE")"


BUILD_DIR="$RTL_DIR/build_${TESTBENCH_NAME}"
mkdir -p "$BUILD_DIR"


create_stubs() {
    log_info "Using existing primitive IPs from OpenTitan repository..."
}

# Add OpenTitan primitive paths
OPENTITAN_ROOT="$RTL_DIR/../../.."
PRIM_IP_DIR="$OPENTITAN_ROOT/ip/prim"
PRIM_RTL_DIR="$PRIM_IP_DIR/rtl"
PRIM_GENERIC_DIR="$OPENTITAN_ROOT/ip/prim_generic/rtl"
EDN_IP_DIR="$OPENTITAN_ROOT/ip/edn"
EDN_RTL_DIR="$EDN_IP_DIR/rtl"
ENTROPY_SRC_IP_DIR="$OPENTITAN_ROOT/ip/entropy_src"
ENTROPY_SRC_RTL_DIR="$ENTROPY_SRC_IP_DIR/rtl"
CSRNG_IP_DIR="$OPENTITAN_ROOT/ip/csrng"
CSRNG_RTL_DIR="$CSRNG_IP_DIR/rtl"

# Add primitive include directories
INCLUDE_DIRS+=("$PRIM_RTL_DIR")
INCLUDE_DIRS+=("$PRIM_GENERIC_DIR")
INCLUDE_DIRS+=("$EDN_RTL_DIR")
INCLUDE_DIRS+=("$ENTROPY_SRC_RTL_DIR")
INCLUDE_DIRS+=("$CSRNG_RTL_DIR")

log_info "Added primitive include directories:"
log_info "  $PRIM_RTL_DIR"
log_info "  $PRIM_GENERIC_DIR"
log_info "  $EDN_RTL_DIR"
log_info "  $ENTROPY_SRC_RTL_DIR"
log_info "  $CSRNG_RTL_DIR"

create_stubs


SV_FILES=()
VERILATOR_WAIVERS=()

# Parse aes.core file for dependencies and files
parse_core_file() {
    local core_file="$RTL_DIR/../aes.core"
    if [[ -f "$core_file" ]]; then
        # log_info "Parsing aes.core file for dependencies..."
        
        # Define dependency order - packages first, then implementation files
        local ORDERED_AES_FILES=(
            # Packages must come first
            "aes_reg_pkg.sv"
            "aes_pkg.sv"
            "aes_sbox_canright_pkg.sv"
            
            # Low-level components (no dependencies on other AES modules)
            "aes_sel_buf_chk.sv"
            "aes_sbox_lut.sv"
            "aes_sbox_canright.sv"
            "aes_sbox_canright_masked_noreuse.sv"
            "aes_sbox_canright_masked.sv"
            "aes_sbox_dom.sv"
            "aes_sbox.sv"
            "aes_shift_rows.sv"
            "aes_mix_single_column.sv"
            "aes_mix_columns.sv"
            "aes_key_expand.sv"
            "aes_prng_clearing.sv"
            "aes_prng_masking.sv"
            
            # Sub-components that depend on low-level modules
            "aes_sub_bytes.sv"
            
            # FSM components
            "aes_cipher_control_fsm_p.sv"
            "aes_cipher_control_fsm_n.sv"
            "aes_cipher_control_fsm.sv"
            # "aes_control_fsm_p.sv"
            # "aes_control_fsm_n.sv"
            # "aes_control_fsm.sv"
            # "aes_ctr_fsm_p.sv"
            # "aes_ctr_fsm_n.sv"
            # "aes_ctr_fsm.sv"
            
            # Control modules that use FSMs
            "aes_cipher_control.sv"
            # "aes_control.sv"
            # "aes_ctr.sv"
            
            # Core modules that use control modules
            "aes_cipher_core.sv"
            # "aes_reg_status.sv"
            # "aes_ctrl_reg_shadowed.sv"
            # "aes_reg_top.sv"
            # "aes_core.sv"
            
            # # Top-level module (must be last)
            # "aes.sv"
        )
        
        # Add files in dependency order
        for filename in "${ORDERED_AES_FILES[@]}"; do
            local full_path="$RTL_DIR/$filename"
            if [[ -f "$full_path" ]]; then
                SV_FILES+=("$full_path")
                # log_info "Added from core (ordered): $filename"
            else
                log_warning "File from core not found: $filename"
            fi
        done
        
        # Also look for waiver files
        local waiver_file="$RTL_DIR/../lint/aes.vlt"
        if [[ -f "$waiver_file" ]]; then
            VERILATOR_WAIVERS+=("$waiver_file")
            log_info "Added waiver: aes.vlt"
        fi
        
        log_success "Parsed $(echo "${SV_FILES[@]}" | wc -w) files and $(echo "${VERILATOR_WAIVERS[@]}" | wc -w) waivers from aes.core"
    else
        log_warning "aes.core file not found at $core_file, using manual dependencies"
        
        # Fallback to manual AES dependencies in proper order
        if grep -q "aes_" "$TESTBENCH_FILE"; then
            log_info "Detected AES testbench, adding manual AES dependencies..."
            
            AES_DEPS=(
                "aes_pkg.sv"
                "aes_sbox_canright_pkg.sv"
                "aes_sel_buf_chk.sv" 
                "aes_sbox_lut.sv"
                "aes_sbox_canright.sv"
                "aes_sbox.sv"
            )
            AES_DEPS+=("${AES_DEPS_LIST[@]}")
            
            for dep in "${AES_DEPS[@]}"; do
                if [[ -f "$RTL_DIR/$dep" ]]; then
                    SV_FILES+=("$RTL_DIR/$dep")
                    # log_info "Added: $dep"
                fi
            done
        fi
    fi
}

# Call the core file parser
parse_core_file

# Add essential primitive files needed for AES (in dependency order)
PKG_FILES=(
    "$ENTROPY_SRC_RTL_DIR/entropy_src_reg_pkg.sv"  # Entropy source reg package (dependency)
    "$ENTROPY_SRC_RTL_DIR/entropy_src_pkg.sv"      # Entropy source package
    "$CSRNG_RTL_DIR/csrng_reg_pkg.sv"              # CSRNG reg package (dependency for csrng_pkg)
    "$CSRNG_RTL_DIR/csrng_pkg.sv"                  # CSRNG package  
    "$EDN_RTL_DIR/edn_reg_pkg.sv"                  # EDN reg package (dependency)
    "$EDN_RTL_DIR/edn_pkg.sv"                      # EDN package
)

PRIM_FILES=(
    "$PRIM_RTL_DIR/prim_assert_dummy_macros.svh" # Dummy macros for assertions
    "$PRIM_RTL_DIR/prim_assert.sv"          # Must be first - defines assertion macros
    "$PRIM_RTL_DIR/prim_util_pkg.sv"        # Utility package
    "$PRIM_RTL_DIR/prim_pkg.sv"             # Main primitive package
    "$PRIM_RTL_DIR/prim_cipher_pkg.sv"      # Cipher package (for PRINCE S-box)
    "$PRIM_RTL_DIR/prim_trivium_pkg.sv"     # Trivium package
    "$PRIM_RTL_DIR/prim_flop_macros.sv"     # Flop macros
    "$PRIM_GENERIC_DIR/prim_flop.sv"        # Generic flop implementation
    "$PRIM_GENERIC_DIR/prim_buf.sv"         # Generic buffer implementation
    "$PRIM_RTL_DIR/prim_sec_anchor_buf.sv"  # Security anchor buffer
    "$PRIM_RTL_DIR/prim_sparse_fsm_flop.sv" # Sparse FSM flop
)

# Start with a fresh SV_FILES array in proper order
ORDERED_SV_FILES=()

log_info "Adding essential primitive files..."
for prim_file in "${PRIM_FILES[@]}"; do
    if [[ -f "$prim_file" ]]; then
        ORDERED_SV_FILES+=("$prim_file")
        # log_info "Added primitive: $(basename "$prim_file")"
    else
        log_warning "Primitive file not found: $prim_file"
    fi
done

# log_info "Adding essential package files..."
for pkg_file in "${PKG_FILES[@]}"; do
    if [[ -f "$pkg_file" ]]; then
        ORDERED_SV_FILES+=("$pkg_file")
        # log_info "Added package: $(basename "$pkg_file")"
    else
        log_warning "Package file not found: $pkg_file"
    fi
done

# Now add the AES files that were collected in dependency order
ORDERED_SV_FILES+=("${SV_FILES[@]}")

# Replace SV_FILES with the properly ordered array
SV_FILES=("${ORDERED_SV_FILES[@]}")

# Add additional files specified via -f argument
if [[ ${#ADDITIONAL_FILES[@]} -gt 0 ]]; then
    log_info "Adding ${#ADDITIONAL_FILES[@]} additional source files..."
    for file in "${ADDITIONAL_FILES[@]}"; do
        # Check if file is absolute path or relative to RTL_DIR
        if [[ -f "$file" ]]; then
            SV_FILES+=("$file")
            log_info "Added: $(basename "$file")"
        elif [[ -f "$RTL_DIR/$file" ]]; then
            SV_FILES+=("$RTL_DIR/$file")
            log_info "Added: $file"
        else
            log_warning "File not found: $file"
        fi
    done
fi

SV_FILES+=("$TESTBENCH_FILE")  
log_info "Added: $(basename "$TESTBENCH_FILE")"

log_success "Found ${#SV_FILES[@]} files to compile"

log_info "Creating Verilator file list..."
FLIST_FILE="$RTL_DIR/aes.flist"

cat > "$FLIST_FILE" << EOF
EOF

for sv_file in "${SV_FILES[@]}"; do
    echo "$sv_file" >> "$FLIST_FILE"
done

log_info "Creating C++ simulation driver..."
cat > "$BUILD_DIR/sim_main.cpp" << EOF
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
        std::cout << "Simulation completed with \$finish at cycle " << time_cnt << std::endl;
    } else {
        std::cout << "Simulation reached timeout at cycle " << time_cnt << std::endl;
    }
    
    contextp->statsPrintSummary();
    return 0;
}
EOF


log_info "Compiling with Verilator..."
cd "$BUILD_DIR"

VFLAGS="--cc --exe --build --top $TESTBENCH_NAME -j 4"
VFLAGS="$VFLAGS -Wall -Wno-PINCONNECTEMPTY -Wno-ASSIGNDLY -Wno-DECLFILENAME"
VFLAGS="$VFLAGS -Wno-UNUSED -Wno-UNDRIVEN -Wno-UNOPTFLAT -Wno-WIDTHCONCAT -Wno-WIDTHEXPAND"
VFLAGS="$VFLAGS -Wno-LITENDIAN -Wno-UNPACKED -Wno-WIDTHTRUNC -I$RTL_DIR"


for include_dir in "${INCLUDE_DIRS[@]}"; do
    VFLAGS="$VFLAGS -I$include_dir"
done


for define in "${DEFINES[@]}"; do
    VFLAGS="$VFLAGS -D$define"
done


for waiver in "${VERILATOR_WAIVERS[@]}"; do
    VFLAGS="$VFLAGS $waiver"
done


if [[ -n "$ADDITIONAL_VFLAGS" ]]; then
    VFLAGS="$VFLAGS $ADDITIONAL_VFLAGS"
fi


if [[ "$ENABLE_TRACE" == true ]]; then
    VFLAGS="$VFLAGS --trace"
fi


if [[ "$ENABLE_COVERAGE" == true ]]; then
    VFLAGS="$VFLAGS --coverage"
fi

# log_info "Verilator flags: $VFLAGS"

if verilator $VFLAGS "${SV_FILES[@]}" sim_main.cpp; then
    log_success "Compilation successful!"
else
    log_error "Compilation failed!"
    exit 1
fi


EXECUTABLE="$BUILD_DIR/obj_dir/V${TESTBENCH_NAME}"
if [[ -f "$EXECUTABLE" ]]; then
    log_info "Running simulation..."
    echo "=================================="
    if "$EXECUTABLE" "$TIMEOUT"; then
        echo "=================================="
        log_success "Simulation completed!"
    else
        echo "=================================="
        log_warning "Simulation completed with warnings"
    fi
else
    log_error "Executable not found!"
    exit 1
fi

log_info "Build directory: $BUILD_DIR"
log_info "To re-run: $EXECUTABLE [$TIMEOUT]"