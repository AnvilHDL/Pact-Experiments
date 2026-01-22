#!/bin/bash

set -e

cp run_yosys.sh ../ace/
cd ../ace/



BENDER_CMD="bender"
TOP_MODULE=$1

if [ -z "$TOP_MODULE" ]; then
    echo "Usage: ./script_name.sh <top_module>"
    exit 1
fi

$BENDER_CMD update

LOCAL_INC="include"
COMMON_CELLS_INC=$(find .bender -type d -path "*/common_cells*/include" | head -n 1)


FILES=$($BENDER_CMD script flist --target synthesis | tr '\n' ' ')
CLEAN_FILES=""
AXI_INCS="-I$(realpath ../axi/include)"

for f in $FILES; do
    if [[ "$f" == *"ace_pkg.sv"* ]] || \
       [[ "$f" == *"snoop_pkg.sv"* ]] || \
       [[ "$f" == *"ace_intf.sv"* ]] || \
       [[ "$f" == *"snoop_intf.sv"* ]] || \
       [[ "$f" == *"$TOP_MODULE.sv"* ]]; then
        CLEAN_FILES="$CLEAN_FILES $f"
    fi
done

CLEAN_FILES="$CLEAN_FILES src/${TOP_MODULE}.sv src/ccu_fsm.sv ../axi/src/axi_pkg.sv"

echo "Filtered file list prepared."

ARGS="-I$LOCAL_INC -I$COMMON_CELLS_INC $AXI_INCS $CLEAN_FILES"
bash run_yosys.sh -a "$ARGS" "$TOP_MODULE"