#!/usr/bin/env bash

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PACT_SRC_DIR="$ROOT/src/compat"
TILELINK_DIR="$ROOT/tilelink"
TB_DIR="$ROOT/src/testbenches"
LOG_DIR="$ROOT/logs/equiv/tilelink/tilelink_cycle_equiv"
SV_OBJ_DIR="$ROOT/src/build/tilelink/tb_tlcrossbar_obj"
SV_DRIVER="$ROOT/src/build/tilelink/tb_tlcrossbar_driver.cpp"
# The SV testbench starts its trace counter one cycle after the PACT model.
SV_TIMEOUT="${SV_TIMEOUT:-78}"
PACT_TIMEOUT="${PACT_TIMEOUT:-76}"
SV_LOG="$LOG_DIR/TLCrossBar_test.sv.log"
PACT_LOG="$LOG_DIR/test_tilelink.pact.log"
SV_LOGIC_LOG="$LOG_DIR/TLCrossBar_test.sv.logic.log"
PACT_LOGIC_LOG="$LOG_DIR/test_tilelink.pact.logic.log"
DIFF_LOG="$LOG_DIR/logic.diff"

normalize_logic_log() {
  local in_file="$1"
  local out_file="$2"

  grep '^\[Cycle' "$in_file" \
    | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//' \
    | LC_ALL=C sort -s -k2,2n -k3,99 \
    > "$out_file"
}

mkdir -p "$LOG_DIR" "$ROOT/src/build/tilelink" "$TB_DIR"

echo "[1/3] Building and running src/testbenches/TLCrossBar_test.sv"

bash "$ROOT/scripts/build_tilelink_rtl.sh"

sed 's/Vtop/Vtb_tlcrossbar/g' "$PACT_SRC_DIR/sim_main.cpp" > "$SV_DRIVER"

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

echo "[2/3] Type-checking PACT compat test_tilelink"
(cd "$ROOT" && ./run_pact -jc src/compat/test_tilelink.anvil)

echo "[3/3] Running PACT compat test_tilelink"
(
  cd "$PACT_SRC_DIR"
  env -u DEBUG OBJCACHE= make -B run MODULE_NAME=test_tilelink LTOFF=1 COMPATOFF=1 SILENT=1 TIMEOUT="$PACT_TIMEOUT"
) | tee "$PACT_LOG"
normalize_logic_log "$PACT_LOG" "$PACT_LOGIC_LOG"

diff -u "$SV_LOGIC_LOG" "$PACT_LOGIC_LOG" > "$DIFF_LOG"

echo "Logs written to $LOG_DIR"
echo "Logical logs match"
