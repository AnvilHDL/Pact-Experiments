#!/bin/bash

set -e

cp run_yosys.sh ../axi/
cd ../axi/


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

FILES=$($BENDER_CMD script flist --target synthesis | tr '\n' ' ')
CLEAN_FILES=""

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

CLEAN_FILES+=" src/axi_lite_mux_top.sv src/axi_router_top.sv src/axi_lite_mux_read.sv src/axi_lite_mux_write.sv src/axi_lite_mux_read_tb.sv src/axi_lite_mux_write_tb.sv src/axi_lite_demux_read.sv src/axi_lite_demux_write.sv src/axi_lite_demux_read_tb.sv src/axi_lite_demux_write_tb.sv"

echo "Filtered file list prepared."

ARGS="-I$LOCAL_INC -I$COMMON_CELLS_INC $CLEAN_FILES"
bash run_yosys.sh -a "$ARGS" "$TOP_MODULE"