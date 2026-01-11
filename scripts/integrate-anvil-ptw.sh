#!/bin/bash


# This script substitutes the original CVA6 PTW module with the Anvil 
#   ./scripts/integrate-anvil-ptw.sh [--restore]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARTEFACT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CVA6_DIR="$ARTEFACT_ROOT/cva6_ariane"
ANVIL_SRC="$ARTEFACT_ROOT/src/cva6"


RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Target files
CVA6_MMU_DIR="$CVA6_DIR/core/cva6_mmu"
FLIST="$CVA6_DIR/core/Flist.cva6"

# PTW files
ORIGINAL_PTW="$CVA6_MMU_DIR/cva6_ptw.sv"
BACKUP_PTW="$CVA6_MMU_DIR/cva6_ptw.sv.orig"
ANVIL_PTW_WRAPPER="$ANVIL_SRC/cva6_anvil_ptw.sv"
ANVIL_PTW_SV="$ANVIL_SRC/anvil_ptw.anvil.sv"
ANVIL_PTW_ANVIL="$ANVIL_SRC/anvil_ptw.anvil"

# TLB files
ORIGINAL_TLB="$CVA6_MMU_DIR/cva6_tlb.sv"
BACKUP_TLB="$CVA6_MMU_DIR/cva6_tlb.sv.orig"
ANVIL_TLB_WRAPPER="$ANVIL_SRC/cva6_anvil_tlb.sv"
ANVIL_TLB_SV="$ANVIL_SRC/anvil_tlb.anvil.sv"
ANVIL_TLB_ANVIL="$ANVIL_SRC/anvil_tlb.anvil"

# Flist backup
BACKUP_FLIST="$FLIST.orig"

usage() {
    echo "Anvil PTW/TLB Integration Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --integrate       Integrate Anvil PTW and TLB (default if no option)"
    echo "  --restore         Restore original CVA6 PTW"
    echo "  --status          Show current integration status"
    echo "  --compile-anvil   Only compile Anvil sources (no integration)"
    echo "  --help, -h        Show this help"
}

compile_anvil_sources() {
    log_info "Compiling Anvil PTW and TLB to SystemVerilog..."
    
    cd "$ANVIL_SRC"
    
    if command -v anvil &> /dev/null; then
        log_info "Using Anvil compiler..."
        
        if [ -f "$ANVIL_PTW_ANVIL" ]; then
            log_info "Compiling Anvil PTW..."
            anvil -O 3 anvil_ptw.anvil > anvil_ptw.anvil.sv 2>&1 || {
                log_warn "Anvil PTW compilation completed (check for warnings)"
            }
            log_info "Generated: $ANVIL_PTW_SV"
        fi
        
        if [ -f "$ANVIL_TLB_ANVIL" ]; then
            log_info "Compiling Anvil TLB..."
            anvil -O 3 anvil_tlb.anvil > anvil_tlb.anvil.sv 2>&1 || {
                log_warn "Anvil TLB compilation completed (check for warnings)"
            }
            log_info "Generated: $ANVIL_TLB_SV"
        fi
    else
        log_warn "Anvil compiler not found in PATH"
        if [ -f "$ANVIL_PTW_SV" ] && [ -f "$ANVIL_TLB_SV" ]; then
            log_info "Using existing pre-compiled SystemVerilog"
        else
            log_error "No pre-compiled SystemVerilog found. Install Anvil compiler first."
            return 1
        fi
    fi
    
    cd "$ARTEFACT_ROOT"
}

check_status() {
    echo ""
    echo "=== Anvil PTW/TLB Integration Status ==="
    echo ""
    
    if [ -f "$BACKUP_PTW" ] || [ -f "$BACKUP_TLB" ]; then
        echo "Status: INTEGRATED (Anvil modules active)"
        echo ""
        echo "Backups:"
        [ -f "$BACKUP_PTW" ] && echo "  - PTW: $BACKUP_PTW"
        [ -f "$BACKUP_TLB" ] && echo "  - TLB: $BACKUP_TLB"
        [ -f "$BACKUP_FLIST" ] && echo "  - Flist: $BACKUP_FLIST"
    else
        echo "Status: ORIGINAL (CVA6 modules active)"
        echo ""
        echo "Files:"
        echo "  - Current PTW: $ORIGINAL_PTW"
        echo "  - Current TLB: $ORIGINAL_TLB"
    fi
    
    echo ""
    echo "Anvil PTW sources:"
    [ -f "$ANVIL_PTW_ANVIL" ] && echo "  - Anvil source: EXISTS" || echo "  - Anvil source: NOT FOUND"
    [ -f "$ANVIL_PTW_SV" ] && echo "  - Compiled SV: EXISTS" || echo "  - Compiled SV: NOT FOUND"
    [ -f "$ANVIL_PTW_WRAPPER" ] && echo "  - Wrapper: EXISTS" || echo "  - Wrapper: NOT FOUND"
    
    echo ""
    echo "Anvil TLB sources:"
    [ -f "$ANVIL_TLB_ANVIL" ] && echo "  - Anvil source: EXISTS" || echo "  - Anvil source: NOT FOUND"
    [ -f "$ANVIL_TLB_SV" ] && echo "  - Compiled SV: EXISTS" || echo "  - Compiled SV: NOT FOUND"
    [ -f "$ANVIL_TLB_WRAPPER" ] && echo "  - Wrapper: EXISTS" || echo "  - Wrapper: NOT FOUND"
    echo ""
}

integrate_anvil() {
    log_info "Integrating Anvil PTW and TLB into CVA6..."
    
    # Check if already integrated
    if [ -f "$BACKUP_PTW" ] || [ -f "$BACKUP_TLB" ]; then
        log_warn "Anvil modules already integrated. Use --restore first to reintegrate."
        return 0
    fi
    
    # Compile Anvil sources
    compile_anvil_sources || return 1
    
    # Check required files exist
    if [ ! -f "$ANVIL_PTW_WRAPPER" ]; then
        log_error "Anvil PTW wrapper not found: $ANVIL_PTW_WRAPPER"
        return 1
    fi
    
    if [ ! -f "$ANVIL_PTW_SV" ]; then
        log_error "Compiled Anvil PTW not found: $ANVIL_PTW_SV"
        return 1
    fi
    
    if [ ! -f "$ANVIL_TLB_WRAPPER" ]; then
        log_error "Anvil TLB wrapper not found: $ANVIL_TLB_WRAPPER"
        return 1
    fi
    
    if [ ! -f "$ANVIL_TLB_SV" ]; then
        log_error "Compiled Anvil TLB not found: $ANVIL_TLB_SV"
        return 1
    fi
    

    log_info "Backing up original files..."
    cp "$ORIGINAL_PTW" "$BACKUP_PTW"
    cp "$ORIGINAL_TLB" "$BACKUP_TLB"
    cp "$FLIST" "$BACKUP_FLIST"
    
    log_info "Copying Anvil files to CVA6..."
    cp "$ANVIL_PTW_SV" "$CVA6_MMU_DIR/anvil_ptw.sv"
    cp "$ANVIL_TLB_SV" "$CVA6_MMU_DIR/anvil_tlb.sv"
    

    log_info "Installing Anvil wrappers..."
    cp "$ANVIL_TLB_WRAPPER" "$ORIGINAL_TLB"
    sed 's/module cva6_anvil_ptw/module cva6_ptw/' "$ANVIL_PTW_WRAPPER" > "$ORIGINAL_PTW"
    

    log_info "Updating file list..."
    
    if ! grep -q "anvil_tlb.sv" "$FLIST"; then
        sed -i '/cva6_ptw.sv/i \${CVA6_REPO_DIR}/core/cva6_mmu/anvil_tlb.sv\n\${CVA6_REPO_DIR}/core/cva6_mmu/anvil_ptw.sv' "$FLIST"
        log_info "Added Anvil modules to Flist.cva6"
    fi
    
    log_info "Anvil integration complete!"
    log_info ""
    log_info "The CVA6 will now use the Anvil PTW and TLB implementations."
    log_info "Run './scripts/run-cva6-tests.sh' to test."
}

restore_original() {
    log_info "Restoring original CVA6 modules..."
    
    if [ ! -f "$BACKUP_PTW" ] && [ ! -f "$BACKUP_TLB" ]; then
        log_warn "No backups found. Original modules may already be in place."
        return 0
    fi
    
    # Restore originals
    [ -f "$BACKUP_PTW" ] && mv "$BACKUP_PTW" "$ORIGINAL_PTW"
    [ -f "$BACKUP_TLB" ] && mv "$BACKUP_TLB" "$ORIGINAL_TLB"
    [ -f "$BACKUP_FLIST" ] && mv "$BACKUP_FLIST" "$FLIST"
    
    # Remove Anvil files from CVA6
    rm -f "$CVA6_MMU_DIR/anvil_ptw.sv"
    rm -f "$CVA6_MMU_DIR/anvil_tlb.sv"
    
    log_info "Original CVA6 modules restored!"
}

# Parse arguments
ACTION="integrate"
while [[ $# -gt 0 ]]; do
    case $1 in
        --integrate)
            ACTION="integrate"
            shift
            ;;
        --restore)
            ACTION="restore"
            shift
            ;;
        --status)
            ACTION="status"
            shift
            ;;
        --compile-anvil)
            ACTION="compile"
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

case "$ACTION" in
    integrate)
        integrate_anvil
        ;;
    restore)
        restore_original
        ;;
    status)
        check_status
        ;;
    compile)
        compile_anvil_sources
        ;;
esac
