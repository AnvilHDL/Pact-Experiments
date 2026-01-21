#!/bin/bash

set -e

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -top ) TOP_MODULE="$2"; shift ;;
        * ) FILE="$1" ;;
    esac
    shift
done

if [ -z "$TOP_MODULE" ] || [ -z "$FILE" ]; then
    echo "Usage: $0 -top <top_module_name> <file_to_collect>"
    exit 1
fi

echo "Collecting $FILE into $TOP_MODULE"

YOSYS_SCRIPT="read_slang $FILE; hierarchy -top $TOP_MODULE; synth; stat"

echo "Running: yosys -m slang -p \"$YOSYS_SCRIPT\""

OUT_FILE="result_$(basename $FILE .sv).log"

yosys -m slang -p "$YOSYS_SCRIPT" > "$OUT_FILE"

echo "Result written to $OUT_FILE"