#!/usr/bin/env bash

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
ANVIL_DIR="$ROOT/src/compat"
TILELINK_DIR="$ROOT/tilelink"
TB_DIR="$ROOT/src/testbenches"
LOG_DIR="$TILELINK_DIR/logs/tilelink_cycle_equiv"
SV_OBJ_DIR="$TILELINK_DIR/build/tb_tlcrossbar_obj"
SV_DRIVER="$TILELINK_DIR/build/tb_tlcrossbar_driver.cpp"
# The SV testbench starts its trace counter one cycle after the Anvil model.
SV_TIMEOUT="${SV_TIMEOUT:-78}"
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
    | LC_ALL=C sort -s -k2,2n -k3,99 \
    > "$out_file"
}

mkdir -p "$LOG_DIR" "$TILELINK_DIR/build" "$TB_DIR"

echo "[1/3] Building and running tilelink/tilelink/TLCrossBar_test.sv"

bash "$ROOT/scripts/build_tilelink_rtl.sh"

sed 's/Vtop/Vtb_tlcrossbar/g' "$ANVIL_DIR/sim_main.cpp" > "$SV_DRIVER"

env OBJCACHE= verilator \
  --cc \
  --exe \
  --build \
  -Wno-fatal \
  -DTILELINK_CROSSBAR_TB_TRACE \
  --top-module tb_tlcrossbar \
  --Mdir "$SV_OBJ_DIR" \
  -I"$TB_DIR" \
  "$ROOT/src/build/tilelink_rtl/TLCrossBar.v" \
  "$TB_DIR/TLCrossBar_test.sv" \
  "$SV_DRIVER" \
  > "$LOG_DIR/TLCrossBar_test.verilator-build.log" \
  2>&1

"$SV_OBJ_DIR/Vtb_tlcrossbar" "$SV_TIMEOUT" | tee "$SV_LOG"
normalize_logic_log "$SV_LOG" "$SV_LOGIC_LOG"

echo "[2/3] Type-checking Anvil compat test_tilelink"
(cd "$ROOT" && ./run_anvil -jc src/compat/test_tilelink.anvil)

echo "[3/3] Running Anvil compat test_tilelink"
(
  cd "$ANVIL_DIR"
  env -u DEBUG OBJCACHE= make -B run MODULE_NAME=test_tilelink LTOFF=1 COMPATOFF=1 SILENT=1 TIMEOUT="$ANVIL_TIMEOUT"
) | tee "$ANVIL_LOG"
normalize_logic_log "$ANVIL_LOG" "$ANVIL_LOGIC_LOG"

diff -u "$SV_LOGIC_LOG" "$ANVIL_LOGIC_LOG" > "$DIFF_LOG"

echo "Logs written to $LOG_DIR"
echo "Logical logs match"
