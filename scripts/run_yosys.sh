#!/bin/bash



BENDER_CMD="bender"

TOP_MODULE=$1


$BENDER_CMD update
COMMON_CELLS_INC=$(find .bender -type d -path "*/common_cells*/include" | head -n 1)
LOCAL_INC="include"

if [ -z "$COMMON_CELLS_INC" ]; then
    echo "Error: Could not find common_cells include directory."
    exit 1
fi

echo "Found common_cells includes at: $COMMON_CELLS_INC"


FILES=$($BENDER_CMD script flist --target synthesis | tr '\n' ' ')


CLEAN_FILES=""
for f in $FILES; do
    if [[ "$f" == *"common_cells"* ]]; then
        CLEAN_FILES="$CLEAN_FILES $f"
    elif [[ "$f" == *"tech_cells_generic"* ]]; then
        CLEAN_FILES="$CLEAN_FILES $f"
    elif [[ "$f" == *"axi_pkg.sv"* ]]; then
        CLEAN_FILES="$CLEAN_FILES $f"
    elif [[ "$f" == *"axi_lite_mux.sv"* ]]; then
        CLEAN_FILES="$CLEAN_FILES $f"
    elif [[ "$f" == *"axi_lite_demux.sv"* ]]; then
        CLEAN_FILES="$CLEAN_FILES $f"
    elif [[ "$f" == *"axi_intf.sv"* ]]; then
        CLEAN_FILES="$CLEAN_FILES $f"
    elif [[ "$f" == *"$TOP_MODULE.sv"* ]]; then
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
    flatten
    stat
"| tee $TOP_MODULE"_yosys.log"

echo "----------------------------------------"
echo "Done. Log saved to $(pwd)/$TOP_MODULE\_yosys.log"
echo "----------------------------------------"