#!/bin/bash

# --- Setup ---
BENDER_CMD="bender"
TOP_MODULE=$1

if [ -z "$TOP_MODULE" ]; then
    echo "Usage: ./script_name.sh <top_module>"
    exit 1
fi

$BENDER_CMD update
COMMON_CELLS_INC=$(find .bender -type d -path "*/common_cells*/include" | head -n 1)
LOCAL_INC="include"

if [ -z "$COMMON_CELLS_INC" ]; then
    echo "Error: Could not find common_cells include directory."
    exit 1
fi

# --- File Collection ---
FILES=$($BENDER_CMD script flist --target synthesis | tr '\n' ' ')
CLEAN_FILES=""
# (Your existing file filtering logic)
for f in $FILES; do
    if [[ "$f" == *"common_cells"* ]] || \
       [[ "$f" == *"tech_cells_generic"* ]] || \
       [[ "$f" == *"axi_pkg.sv"* ]] || \
       [[ "$f" == *"axi_lite_mux.sv"* ]] || \
       [[ "$f" == *"axi_lite_demux.sv"* ]] || \
       [[ "$f" == *"axi_intf.sv"* ]] || \
       [[ "$f" == *"$TOP_MODULE.sv"* ]]; then
        CLEAN_FILES="$CLEAN_FILES $f"
    fi
done

echo "Filtered file list prepared."

yosys -m slang -p "
    read_slang --single-unit --top $TOP_MODULE -I$LOCAL_INC -I$COMMON_CELLS_INC $CLEAN_FILES src/axi_lite_mux_top.sv src/axi_router_top.sv
    hierarchy -check
    proc
    opt -noff
    memory
    opt -noff
    techmap
    opt -noff
    abc
    opt -noff
    async2sync
    flatten
    stat
"| tee $TOP_MODULE"_yosys.log"


# --- ABC REACHABILITY FLOW ---
# We use yosys-abc to compute exact reachability
echo "----------------------------------------"
echo "Running ABC for Reachable State Space Analysis..."
echo "WARNING: This uses BDDs and may explode memory for large designs (>200-300 FFs)."
echo "----------------------------------------"

yosys-abc -c "
    read_blif $TOP_MODULE.blif;
    strash;
    print_stats;
    reach;
" | tee $TOP_MODULE"_reach.log"

echo "----------------------------------------"
echo "Analysis Done."
echo "Yosys Log: $TOP_MODULE""_yosys.log"
echo "Reachability Log: $TOP_MODULE""_reach.log"