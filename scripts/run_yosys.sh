#!/bin/bash

# collect as args:
set -e


ARGS=""
TOP_MODULE=""

mkdir -p logs

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--all_args)
            ARGS+="$2 "
            shift 2
            ;;
        *)
            TOP_MODULE="$1"
            shift
            ;;
    esac
done


yosys -m slang -p "
    read_slang --single-unit --top $TOP_MODULE $ARGS
    hierarchy -check -top $TOP_MODULE
    stat
    proc
    stat
    techmap
    async2sync
    stat
    write_blif $TOP_MODULE.blif
" | tee  logs/$TOP_MODULE"_bit_level.log"

yosys-abc -c "
    read_blif $TOP_MODULE.blif;
    strash;
    print_stats;
    zero;
    reach -B 1000000;
" | tee logs/$TOP_MODULE"_reach.log"

echo "----------------------------------------"
echo "Analysis Done."
echo "Yosys Log: logs/$TOP_MODULE""_word_level.log"
echo "Yosys Bit level Log: logs/$TOP_MODULE""_bit_level.log"
echo "Reachability Log: $TOP_MODULE""_reach.log"