#!/usr/bin/env bash

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
ANVIL_DIR="$ROOT/src/compat"
ACE_DIR="$ROOT/ace"
TB_DIR="$ROOT/src/testbenches"
LOG_DIR="$ACE_DIR/logs/cycle_equiv"
SV_OBJ_DIR="$ACE_DIR/build/ccu_fsm_tb_obj"
SV_DRIVER="$ACE_DIR/build/ccu_fsm_tb_driver.cpp"
SV_TIMEOUT="${SV_TIMEOUT:-600}"
REF_LOG="$LOG_DIR/test_ace.anvil.logic.log"
SV_LOG="$LOG_DIR/ccu_fsm_tb.sv.log"
SV_LOGIC_LOG="$LOG_DIR/ccu_fsm_tb.sv.logic.log"
DIFF_LOG="$LOG_DIR/logic.diff"

mkdir -p "$LOG_DIR" "$ACE_DIR/build" "$TB_DIR"

# ace/ is an untracked-content submodule (its DUT/testbench .sv files are not
# committed anywhere in the submodule's own history), so refresh the tracked
# copies under src/testbenches/ on every run rather than building straight
# out of the submodule working tree - otherwise these sources only exist on
# whichever machine last edited them.
cp "$ACE_DIR/src/ace_pkg.sv" "$TB_DIR/ace_pkg.sv"
cp "$ACE_DIR/src/snoop_pkg.sv" "$TB_DIR/snoop_pkg.sv"
cp "$ACE_DIR/src/ccu_fsm.sv" "$TB_DIR/ccu_fsm.sv"
cp "$ACE_DIR/src/ccu_fsm_tb.sv" "$TB_DIR/ccu_fsm_tb.sv"

echo "[1/2] Running Anvil compat test_ace"
(
  cd "$ANVIL_DIR"
  env -u DEBUG make run MODULE_NAME=test_ace LTOFF=1 COMPAT=1 SILENT=1
) | tee "$LOG_DIR/test_ace.anvil.log"
grep '^\[Cycle' "$LOG_DIR/test_ace.anvil.log" > "$REF_LOG"

echo "[2/2] Building and running ace/src/ccu_fsm_tb.sv"
sed \
  -e 's/Vtop/Vccu_fsm_tb/g' \
  -e 's/top->clk_i/top->clk/g' \
  -e 's/top->rst_ni/top->rst_n/g' \
  "$ANVIL_DIR/sim_main.cpp" > "$SV_DRIVER"

env OBJCACHE= verilator \
  --cc \
  --exe \
  --build \
  -Wno-fatal \
  -DACE_TB_TRACE \
  --timing \
  --top-module ccu_fsm_tb \
  --Mdir "$SV_OBJ_DIR" \
  -I"$ACE_DIR/include" \
  -I"$ROOT/axi/include" \
  "$ROOT/axi/src/axi_pkg.sv" \
  "$TB_DIR/ace_pkg.sv" \
  "$TB_DIR/snoop_pkg.sv" \
  "$TB_DIR/ccu_fsm.sv" \
  "$TB_DIR/ccu_fsm_tb.sv" \
  "$SV_DRIVER" \
  > "$LOG_DIR/ccu_fsm_tb.verilator-build.log" \
  2>&1

"$SV_OBJ_DIR/Vccu_fsm_tb" "$SV_TIMEOUT" "+ACE_TB_REF_LOG=$REF_LOG" | tee "$SV_LOG"
grep '^\[Cycle' "$SV_LOG" > "$SV_LOGIC_LOG"
diff -u "$REF_LOG" "$SV_LOGIC_LOG" > "$DIFF_LOG"

echo "Logs written to $LOG_DIR"
echo "Logical logs match"
