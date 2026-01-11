#!/bin/bash

# CVA6 Setup Script 

# This script sets up the complete CVA6 environment including:
# - RISC-V GCC Toolchain
# - Verilator
# - Spike ISS
# - Python dependencies
# - Test suites

# Run from the Anvil-Experiments root directory:
#   ./scripts/setup-cva6.sh [OPTIONS]

set -e

# Get the root directory 
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARTEFACT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CVA6_DIR="$ARTEFACT_ROOT/cva6_ariane"

# Default installation paths
INSTALL_BASE="${INSTALL_BASE:-$ARTEFACT_ROOT/tools}"
RISCV_INSTALL_DIR="${RISCV:-$INSTALL_BASE/riscv}"


RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_section() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Parse command line arguments
SKIP_TOOLCHAIN=false
SKIP_VERILATOR=false
SKIP_SPIKE=false
TOOLCHAIN_ONLY=false
TEST_ONLY=false
INSTALL_DEPS=false
NUM_JOBS=${NUM_JOBS:-$(nproc)}

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-toolchain)
            SKIP_TOOLCHAIN=true
            shift
            ;;
        --skip-verilator)
            SKIP_VERILATOR=true
            shift
            ;;
        --skip-spike)
            SKIP_SPIKE=true
            shift
            ;;
        --toolchain-only)
            TOOLCHAIN_ONLY=true
            shift
            ;;
        --test-only)
            TEST_ONLY=true
            shift
            ;;
        --install-deps)
            INSTALL_DEPS=true
            shift
            ;;
        --jobs=*)
            NUM_JOBS="${1#*=}"
            shift
            ;;
        -j*)
            NUM_JOBS="${1#-j}"
            shift
            ;;
        --help|-h)
            echo "CVA6 Setup Script for Anvil-Experiments Artefact"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --install-deps      Install system dependencies (requires sudo)"
            echo "  --skip-toolchain    Skip RISC-V toolchain build"
            echo "  --skip-verilator    Skip Verilator installation"
            echo "  --skip-spike        Skip Spike ISS installation"
            echo "  --toolchain-only    Only build the RISC-V toolchain"
            echo "  --test-only         Only run tests (assumes setup is complete)"
            echo "  --jobs=N, -jN       Number of parallel jobs (default: nproc)"
            echo "  --help, -h          Show this help message"
            echo ""
            echo "Environment Variables:"
            echo "  RISCV               Installation directory for toolchain (default: $ARTEFACT_ROOT/tools/riscv)"
            echo "  NUM_JOBS            Number of parallel jobs"
            echo "  INSTALL_BASE        Base directory for tool installations"
            echo ""
            echo "After setup, source the environment with:"
            echo "  source $ARTEFACT_ROOT/scripts/env-cva6.sh"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

export NUM_JOBS

log_section "CVA6 Setup for Anvil-Experiments"
log_info "Artefact root: $ARTEFACT_ROOT"
log_info "CVA6 directory: $CVA6_DIR"
log_info "Installation base: $INSTALL_BASE"
log_info "RISC-V toolchain dir: $RISCV_INSTALL_DIR"
log_info "Number of parallel jobs: $NUM_JOBS"


# Install system dependencies and check prerequisites
install_system_deps() {
    log_section "Installing System Dependencies"
    
  
    local PACKAGES="autoconf automake autotools-dev curl git libmpc-dev libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo gperf libtool patchutils bc zlib1g-dev cmake python3 python3-pip help2man device-tree-compiler libfl-dev"
    
    if command -v apt-get &> /dev/null; then
        log_info "Detected Debian/Ubuntu system, installing dependencies..."
        sudo apt-get update
        sudo apt-get install -y $PACKAGES
    elif command -v yum &> /dev/null; then
        log_info "Detected RHEL/CentOS system, installing dependencies..."
        sudo yum install -y autoconf automake curl git mpfr-devel gmp-devel libmpc-devel gawk gcc gcc-c++ bison flex texinfo gperf libtool patchutils bc zlib-devel cmake python3 python3-pip help2man dtc flex-devel
    elif command -v pacman &> /dev/null; then
        log_info "Detected Arch Linux system, installing dependencies..."
        sudo pacman -Syu --noconfirm autoconf automake curl git mpfr gmp libmpc gawk base-devel bison flex texinfo gperf libtool patchutils bc zlib cmake python python-pip help2man dtc
    else
        log_warn "Could not detect package manager. Please install dependencies manually:"
        echo "  $PACKAGES"
    fi
}

check_prerequisites() {
    log_section "Checking Prerequisites"
    
    local MISSING_PKGS=""
    
  
    for tool in git make gcc g++ autoconf automake bison flex makeinfo gperf libtoolize bc cmake python3 dtc; do
        if ! command -v $tool &> /dev/null; then
            MISSING_PKGS="$MISSING_PKGS $tool"
        fi
    done
    
  
    if ! command -v pip3 &> /dev/null; then
        if ! python3 -m pip --version &> /dev/null; then
            MISSING_PKGS="$MISSING_PKGS pip3"
        fi
    fi
    
  
    if ! echo '#include <mpfr.h>' | gcc -E - &>/dev/null; then
        MISSING_PKGS="$MISSING_PKGS libmpfr-dev"
    fi
    if ! echo '#include <mpc.h>' | gcc -E - &>/dev/null; then
        MISSING_PKGS="$MISSING_PKGS libmpc-dev"
    fi
    if ! echo '#include <gmp.h>' | gcc -E - &>/dev/null; then
        MISSING_PKGS="$MISSING_PKGS libgmp-dev"
    fi
    
    if [ -n "$MISSING_PKGS" ]; then
        log_error "Missing required tools/libraries:$MISSING_PKGS"
        log_info "Run with --install-deps to install system dependencies, or manually run:"
        echo "  sudo apt-get install autoconf automake autotools-dev curl git libmpc-dev libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo gperf libtool patchutils bc zlib1g-dev cmake python3 python3-pip help2man device-tree-compiler libfl-dev"
        return 1
    fi
    
    log_info "Prerequisites check passed"
    return 0
}


# Initialize Git Submodules

init_submodules() {
    log_section "Initializing Git Submodules"
    
    cd "$ARTEFACT_ROOT"
    
    if [ ! -d ".git" ]; then
        log_error "Not in a Git repository"
        return 1
    fi
    
    git submodule update --init --recursive
    
    log_info "Git submodules initialized"
}


# Build RISC-V Toolchain

build_toolchain() {
    if [ "$SKIP_TOOLCHAIN" = true ]; then
        log_info "Skipping toolchain build (--skip-toolchain)"
        return 0
    fi
    
    # Check if toolchain already exists (check for riscv-none-elf which is used by gcc-13.1.0-baremetal)
    if [ -f "$RISCV_INSTALL_DIR/bin/riscv-none-elf-gcc" ] && \
       [ -f "$RISCV_INSTALL_DIR/riscv-none-elf/include/stdint.h" ]; then
        log_info "RISC-V toolchain already installed at $RISCV_INSTALL_DIR"
        return 0
    fi
    
    log_section "Building RISC-V GCC Toolchain"
    log_warn "This may take 30-60 minutes depending on your system"
    
    cd "$CVA6_DIR/util/toolchain-builder"
    

    log_info "Fetching toolchain sources..."
    bash get-toolchain.sh gcc-13.1.0-baremetal
    

    log_info "Building toolchain..."
    export PATH="$RISCV_INSTALL_DIR/bin:$PATH"
    bash build-toolchain.sh gcc-13.1.0-baremetal "$RISCV_INSTALL_DIR"
    

    if [ ! -f "$RISCV_INSTALL_DIR/riscv-none-elf/include/stdint.h" ]; then
        log_warn "Newlib headers missing, rebuilding newlib..."
        

        local NEWLIB_SRC="$CVA6_DIR/util/toolchain-builder/src/riscv-gnu-toolchain/newlib"
        local NEWLIB_BUILD="$CVA6_DIR/util/toolchain-builder/build/newlib"
        
        mkdir -p "$NEWLIB_BUILD"
        cd "$NEWLIB_BUILD"
        
        "$NEWLIB_SRC/configure" \
            --target=riscv-none-elf \
            --prefix="$RISCV_INSTALL_DIR" \
            --enable-newlib-io-long-double \
            --enable-newlib-io-long-long \
            --enable-newlib-io-c99-formats \
            --enable-newlib-register-fini
        
        make -j$(nproc)
        make install
        
        log_info "Newlib rebuilt successfully"
    fi
    
    cd "$ARTEFACT_ROOT"
    
    if [ ! -f "$RISCV_INSTALL_DIR/riscv-none-elf/include/stdint.h" ]; then
        log_error "Toolchain build failed: newlib headers not found"
        exit 1
    fi
    
    log_info "RISC-V toolchain built successfully"
}
# Install Python dependencies
install_python_deps() {
    log_section "Installing Python Dependencies"
    
    pip3 install --user -r "$CVA6_DIR/verif/sim/dv/requirements.txt"
    
    log_info "Python dependencies installed"
}


# Install Verilator and Spike
install_simulators() {
    log_section "Installing Simulators"
    

    export RISCV="$RISCV_INSTALL_DIR"
    
    cd "$CVA6_DIR"
    
    if [ "$SKIP_VERILATOR" != true ]; then
        log_info "Installing Verilator..."
        source ./verif/regress/install-verilator.sh
        log_info "Verilator installation complete"
    else
        log_info "Skipping Verilator installation (--skip-verilator)"
    fi
    
    if [ -d "$CVA6_DIR/tools/verilator-v5.008" ]; then
        export VERILATOR_INSTALL_DIR="$CVA6_DIR/tools/verilator-v5.008"
    elif [ -d "$CVA6_DIR/tools/verilator" ]; then
        export VERILATOR_INSTALL_DIR="$CVA6_DIR/tools/verilator"
    fi
    
    if [ -n "$VERILATOR_INSTALL_DIR" ]; then
        export PATH="$VERILATOR_INSTALL_DIR/bin:$PATH"
        export CPATH="$VERILATOR_INSTALL_DIR/share/verilator/include/vltstd:$CPATH"
        export C_INCLUDE_PATH="$VERILATOR_INSTALL_DIR/share/verilator/include/vltstd:$C_INCLUDE_PATH"
        export CPLUS_INCLUDE_PATH="$VERILATOR_INSTALL_DIR/share/verilator/include/vltstd:$CPLUS_INCLUDE_PATH"
        log_info "Set Verilator paths: $VERILATOR_INSTALL_DIR"
    fi
    
    if [ "$SKIP_SPIKE" != true ]; then
        log_info "Installing Spike ISS..."
        source ./verif/regress/install-spike.sh
        log_info "Spike ISS installation complete"
    else
        log_info "Skipping Spike installation (--skip-spike)"
    fi
    
    cd "$ARTEFACT_ROOT"
}

# Install test suites
install_test_suites() {
    log_section "Installing Test Suites"
    
    export RISCV="$RISCV_INSTALL_DIR"
    
    cd "$CVA6_DIR"
    
    # Source setup-env to get correct paths
    source ./verif/sim/setup-env.sh
    
    # Install test suites
    source ./verif/regress/install-riscv-compliance.sh
    source ./verif/regress/install-riscv-tests.sh
    source ./verif/regress/install-riscv-arch-test.sh
    
    cd "$ARTEFACT_ROOT"
    
    log_info "Test suites installed"
}

# Create environment setup script

create_env_script() {
    log_section "Creating Environment Scripts"
    
    cat > "$ARTEFACT_ROOT/scripts/env-cva6.sh" << EOF
#!/bin/bash
# CVA6 Environment Setup Script for Anvil-Experiments
# Source this file before running CVA6 simulations:
#   source scripts/env-cva6.sh

export ARTEFACT_ROOT="$ARTEFACT_ROOT"
export CVA6_DIR="$CVA6_DIR"
export RISCV="$RISCV_INSTALL_DIR"
export DV_SIMULATORS=veri-testharness,spike
export NUM_JOBS=\${NUM_JOBS:-\$(nproc)}

# Source the CVA6 simulation environment
cd "\$CVA6_DIR"
source ./verif/sim/setup-env.sh
cd "\$ARTEFACT_ROOT"

echo "CVA6 environment configured successfully"
echo "  ARTEFACT_ROOT=\$ARTEFACT_ROOT"
echo "  CVA6_DIR=\$CVA6_DIR"
echo "  RISCV=\$RISCV"
echo "  DV_SIMULATORS=\$DV_SIMULATORS"
echo ""
echo "Available commands:"
echo "  ./scripts/run-cva6-tests.sh          - Run CVA6 smoke tests"
echo "  ./scripts/run-cva6-tests.sh --anvil  - Run tests with Anvil TLB/PTW"
EOF

    chmod +x "$ARTEFACT_ROOT/scripts/env-cva6.sh"
    
    log_info "Environment script created: $ARTEFACT_ROOT/scripts/env-cva6.sh"
}


# Main execution

main() {
    if [ "$TEST_ONLY" = true ]; then
        log_info "Running tests only..."
        export RISCV="$RISCV_INSTALL_DIR"
        cd "$CVA6_DIR"
        source ./verif/sim/setup-env.sh
        export DV_SIMULATORS=veri-testharness,spike
        bash verif/regress/smoke-tests-cv64a6_imafdc_sv39.sh
        cd "$ARTEFACT_ROOT"
        exit 0
    fi
    


    if [ "$INSTALL_DEPS" = true ]; then
        install_system_deps
    fi
    

    check_prerequisites || exit 1
    

    # init_submodules
    

    build_toolchain
    
    if [ "$TOOLCHAIN_ONLY" = true ]; then
        log_info "Toolchain build complete (--toolchain-only)"
        create_env_script
        exit 0
    fi
    

    install_python_deps
    

    install_simulators
    
    
    install_test_suites
    
    
    create_env_script
    
    log_section "Setup Complete!"
    log_info ""
    log_info "To use the environment, run:"
    log_info "  source $ARTEFACT_ROOT/scripts/env-cva6.sh"
    log_info ""
    log_info "To run CVA6 smoke tests:"
    log_info "  ./scripts/run-cva6-tests.sh"
    log_info ""
}

main "$@"
