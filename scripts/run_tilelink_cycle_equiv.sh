#!/usr/bin/env bash

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
ANVIL_DIR="$ROOT/src/compat"
TILELINK_DIR="$ROOT/tilelink"
LOG_DIR="$TILELINK_DIR/logs/tilelink_cycle_equiv"
SV_OBJ_DIR="$TILELINK_DIR/build/tb_tlcrossbar_obj"
SV_DRIVER="$TILELINK_DIR/build/tb_tlcrossbar_driver.cpp"
SV_TIMEOUT="${SV_TIMEOUT:-80}"
ANVIL_TIMEOUT="${ANVIL_TIMEOUT:-76}"
SV_LOG="$LOG_DIR/TLCrossBar_test.sv.log"
ANVIL_LOG="$LOG_DIR/test_tilelink.anvil.log"
SV_LOGIC_LOG="$LOG_DIR/TLCrossBar_test.sv.logic.log"
ANVIL_LOGIC_LOG="$LOG_DIR/test_tilelink.anvil.logic.log"
DIFF_LOG="$LOG_DIR/logic.diff"

normalize_logic_log() {
  local in_file="$1"
  local out_file="$2"

  grep '^\[Cycle' "$in_file" \
    | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//' \
    | sort -s -k2,2n -k3,99 \
    > "$out_file"
}

mkdir -p "$LOG_DIR" "$TILELINK_DIR/build"

echo "[1/3] Building and running tilelink/tilelink/TLCrossBar_test.sv"
sed 's/Vtop/Vtb_tlcrossbar/g' "$ANVIL_DIR/sim_main.cpp" > "$SV_DRIVER"

env OBJCACHE= verilator \
  --cc \
  --exe \
  --build \
  -Wno-fatal \
  -DTILELINK_CROSSBAR_TB_TRACE \
  --top-module tb_tlcrossbar \
  --Mdir "$SV_OBJ_DIR" \
  -I"$TILELINK_DIR/debug_output" \
  "$TILELINK_DIR/debug_output/TLArbiter.sv" \
  "$TILELINK_DIR/debug_output/TLArbiter_2.sv" \
  "$TILELINK_DIR/debug_output/TLArbiter_4.sv" \
  "$TILELINK_DIR/debug_output/TLArbiter_6.sv" \
  "$TILELINK_DIR/debug_output/TLArbiter_8.sv" \
  "$TILELINK_DIR/debug_output/TLCrossBar.sv" \
  "$TILELINK_DIR/tilelink/TLCrossBar_test.sv" \
  "$SV_DRIVER" \
  > "$LOG_DIR/TLCrossBar_test.verilator-build.log" \
  2>&1

"$SV_OBJ_DIR/Vtb_tlcrossbar" "$SV_TIMEOUT" | tee "$SV_LOG"
normalize_logic_log "$SV_LOG" "$SV_LOGIC_LOG"

echo "[2/3] Type-checking Anvil compat test_tilelink"
"$ROOT/run_anvil" -jc src/compat/test_tilelink.anvil

echo "[3/3] Running Anvil compat test_tilelink"
(
  cd "$ANVIL_DIR"
  env -u DEBUG OBJCACHE= make -B run MODULE_NAME=test_tilelink LTOFF=1 COMPAT=1 SILENT=1 TIMEOUT="$ANVIL_TIMEOUT"
) | tee "$ANVIL_LOG"
normalize_logic_log "$ANVIL_LOG" "$ANVIL_LOGIC_LOG"

diff -u "$SV_LOGIC_LOG" "$ANVIL_LOGIC_LOG" > "$DIFF_LOG"

echo "Logs written to $LOG_DIR"
echo "Logical logs match"
