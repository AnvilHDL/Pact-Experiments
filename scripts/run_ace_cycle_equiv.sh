#!/usr/bin/env bash

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PACT_SRC_DIR="$ROOT/src/compat"
ACE_DIR="$ROOT/ace"
TB_DIR="$ROOT/src/testbenches"
LOG_DIR="$ROOT/results/equiv/ace/cycle_equiv"
SV_OBJ_DIR="$ROOT/src/build/ace/ccu_fsm_tb_obj"
SV_DRIVER="$ROOT/src/build/ace/ccu_fsm_tb_driver.cpp"
SV_TIMEOUT="${SV_TIMEOUT:-2200}"
PACT_LOGIC_LOG="$LOG_DIR/test_ace.pact.logic.log"
SV_LOG="$LOG_DIR/ccu_fsm_tb.sv.log"
SV_LOGIC_LOG="$LOG_DIR/ccu_fsm_tb.sv.logic.log"
DIFF_LOG="$LOG_DIR/logic.diff"

normalize_logic_log() {
  grep '^\[Cycle' "$1" \
    | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//' \
    | LC_ALL=C sort -s -k2,2n -k3,99 > "$2"
  test -s "$2"
}

mkdir -p "$LOG_DIR" "$ROOT/src/build/ace" "$TB_DIR"

echo "[1/2] Running PACT compat test_ace"
(
  cd "$PACT_SRC_DIR"
  env -u DEBUG make -B run MODULE_NAME=test_ace LTOFF=1 COMPATOFF=1 SILENT=1
) | tee "$LOG_DIR/test_ace.pact.log"
normalize_logic_log "$LOG_DIR/test_ace.pact.log" "$PACT_LOGIC_LOG"

echo "[2/2] Building and running the DUT with ccu_fsm_tb2.sv"
sed \
  -e 's/Vtop/Vccu_fsm_tb/g' \
  -e 's/top->clk_i/top->clk/g' \
  -e 's/top->rst_ni/top->rst_n/g' \
  "$PACT_SRC_DIR/sim_main.cpp" > "$SV_DRIVER"

env OBJCACHE= verilator \
  --cc \
  --exe \
  --build \
  -Wno-fatal \
  -DACE_TB_DUT_TRACE \
  --timing \
  --top-module ccu_fsm_tb \
  --Mdir "$SV_OBJ_DIR" \
  -I"$ACE_DIR/include" \
  -I"$ROOT/axi/include" \
  "$ROOT/axi/src/axi_pkg.sv" \
  "$TB_DIR/ace_pkg.sv" \
  "$TB_DIR/snoop_pkg.sv" \
  "$TB_DIR/ccu_fsm.sv" \
  "$TB_DIR/ccu_fsm_tb2.sv" \
  "$SV_DRIVER" \
  > "$LOG_DIR/ccu_fsm_tb.verilator-build.log" \
  2>&1

"$SV_OBJ_DIR/Vccu_fsm_tb" "$SV_TIMEOUT" | tee "$SV_LOG"
normalize_logic_log "$SV_LOG" "$SV_LOGIC_LOG"
diff -u "$PACT_LOGIC_LOG" "$SV_LOGIC_LOG" > "$DIFF_LOG"

echo "Logs written to $LOG_DIR"
echo "Logical logs match"
