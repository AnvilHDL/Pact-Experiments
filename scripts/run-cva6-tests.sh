#!/bin/bash

#   ./scripts/run-cva6-tests.sh [--anvil]
#   --anvil    Use Anvil TLB/PTW (default: use original CVA6 SystemVerilog)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARTEFACT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CVA6_DIR="$ARTEFACT_ROOT/cva6_ariane"
ANVIL_SRC="$ARTEFACT_ROOT/src/cva6"

USE_ANVIL=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --anvil)
            USE_ANVIL=true
            ;;
        --help|-h)
            echo "Usage: $0 [--anvil]"
            echo "  --anvil    Use Anvil TLB/PTW instead of default SystemVerilog"
            exit 0
            ;;
    esac
done


if [ -z "$RISCV" ]; then
    if [ -f "$ARTEFACT_ROOT/scripts/env-cva6.sh" ]; then
        source "$ARTEFACT_ROOT/scripts/env-cva6.sh"
    else
        echo "Error: Environment not set up. Run ./scripts/setup-cva6.sh first"
        exit 1
    fi
fi

echo "========================================"
echo " CVA6 Tests Runner"
echo " Mode: $([ "$USE_ANVIL" = true ] && echo 'Anvil TLB/PTW' || echo 'Default SV')"
echo "========================================"

MMU_DIR="$CVA6_DIR/core/cva6_mmu"


# Anvil Integration
if [ "$USE_ANVIL" = true ]; then
    echo "[INFO] Setting up Anvil TLB/PTW..."
    
    FLIST="$CVA6_DIR/core/Flist.cva6"
    
    [ -f "$MMU_DIR/cva6_tlb.sv" ] && [ ! -f "$MMU_DIR/cva6_tlb.sv.orig" ] && cp "$MMU_DIR/cva6_tlb.sv" "$MMU_DIR/cva6_tlb.sv.orig"
    [ -f "$MMU_DIR/cva6_ptw.sv" ] && [ ! -f "$MMU_DIR/cva6_ptw.sv.orig" ] && cp "$MMU_DIR/cva6_ptw.sv" "$MMU_DIR/cva6_ptw.sv.orig"
    [ -f "$FLIST" ] && [ ! -f "$FLIST.orig" ] && cp "$FLIST" "$FLIST.orig"
    

    cd "$ANVIL_SRC"
    if command -v anvil &> /dev/null; then
        echo "[INFO] Compiling Anvil TLB..."
        anvil -O 3 anvil_tlb.anvil > anvil_tlb.anvil.sv 2>/dev/null || true
        echo "[INFO] Compiling Anvil PTW..."
        anvil -O 3 anvil_ptw.anvil > anvil_ptw.anvil.sv 2>/dev/null || true
    fi
    

    cp "$ANVIL_SRC/anvil_tlb.anvil.sv" "$MMU_DIR/anvil_tlb.sv"
    cp "$ANVIL_SRC/cva6_anvil_tlb.sv" "$MMU_DIR/cva6_tlb.sv"
    cp "$ANVIL_SRC/anvil_ptw.anvil.sv" "$MMU_DIR/anvil_ptw.sv"
    cp "$ANVIL_SRC/cva6_anvil_ptw.sv" "$MMU_DIR/cva6_ptw.sv"
    

    if ! grep -q "anvil_tlb.sv" "$FLIST"; then
        echo "[INFO] Adding Anvil modules to Flist.cva6..."
        sed -i '/cva6_ptw.sv/i \${CVA6_REPO_DIR}/core/cva6_mmu/anvil_tlb.sv\n\${CVA6_REPO_DIR}/core/cva6_mmu/anvil_ptw.sv' "$FLIST"
    fi
    
    cd "$ARTEFACT_ROOT"
    echo "[INFO] Anvil integration complete"
    
    # Restore on exit
    cleanup() {
        echo "[INFO] Restoring original files..."
        [ -f "$MMU_DIR/cva6_tlb.sv.orig" ] && mv "$MMU_DIR/cva6_tlb.sv.orig" "$MMU_DIR/cva6_tlb.sv"
        [ -f "$MMU_DIR/cva6_ptw.sv.orig" ] && mv "$MMU_DIR/cva6_ptw.sv.orig" "$MMU_DIR/cva6_ptw.sv"
        [ -f "$FLIST.orig" ] && mv "$FLIST.orig" "$FLIST"
        rm -f "$MMU_DIR/anvil_tlb.sv" "$MMU_DIR/anvil_ptw.sv"
    }
    trap cleanup EXIT
fi


# Run Tests

cd "$CVA6_DIR"

echo "[INFO] Running cv64a6_imafdc tests..."
bash verif/regress/cv64a6_imafdc_tests.sh

echo "========================================"
echo " Tests Complete"
echo "========================================"
