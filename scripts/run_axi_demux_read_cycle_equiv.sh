#!/usr/bin/env bash

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
ANVIL_DIR="$ROOT/src/compat"
AXI_DIR="$ROOT/axi"
TB_DIR="$ROOT/src/testbenches"
LOG_DIR="$AXI_DIR/logs/demux_read_cycle_equiv"
SV_OBJ_DIR="$AXI_DIR/build/tb_axi_read_demux_obj"
SV_DRIVER="$AXI_DIR/build/tb_axi_read_demux_driver.cpp"
SV_TIMEOUT="${SV_TIMEOUT:-140}"
ANVIL_TIMEOUT="${ANVIL_TIMEOUT:-200}"
SV_LOG="$LOG_DIR/axi_lite_demux_read_tb.sv.log"
ANVIL_LOG="$LOG_DIR/test_demux_read.anvil.log"
SV_LOGIC_LOG="$LOG_DIR/axi_lite_demux_read_tb.sv.logic.log"
ANVIL_LOGIC_LOG="$LOG_DIR/test_demux_read.anvil.logic.log"
DIFF_LOG="$LOG_DIR/logic.diff"

normalize_logic_log() {
  local in_file="$1"
  local out_file="$2"

  grep '^\[Cycle' "$in_file" \
    | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//' \
    | sort -s -k2,2n -k3,99 \
    > "$out_file"
}

mkdir -p "$LOG_DIR" "$AXI_DIR/build" "$TB_DIR"

echo "[1/2] Building and running axi/src/axi_lite_demux_read_tb.sv"

# axi/ is an untracked-content submodule (its testbench .sv files are not
# committed anywhere in the submodule's own history), so refresh the tracked
# copy under src/testbenches/ on every run rather than building straight out
# of the submodule working tree - otherwise these sources only exist on
# whichever machine last edited them.
"$ROOT/scripts/refresh_testbench.sh" "$AXI_DIR/src/axi_lite_demux_read.sv" "$TB_DIR/axi_lite_demux_read.sv"
"$ROOT/scripts/refresh_testbench.sh" "$AXI_DIR/src/axi_lite_demux_read_tb.sv" "$TB_DIR/axi_lite_demux_read_tb.sv"

sed 's/Vtop/Vtb_axi_read_demux/g' "$ANVIL_DIR/sim_main.cpp" > "$SV_DRIVER"

env OBJCACHE= verilator \
  --cc \
  --exe \
  --build \
  -Wno-fatal \
  -DAXI_DEMUX_READ_TB_TRACE \
  --top-module tb_axi_read_demux \
  --Mdir "$SV_OBJ_DIR" \
  -I"$ROOT/common_cells/include" \
  -I"$AXI_DIR/include" \
  "$ROOT/common_cells/src/spill_register_flushable.sv" \
  "$ROOT/common_cells/src/spill_register.sv" \
  "$ROOT/common_cells/src/fifo_v3.sv" \
  "$AXI_DIR/src/axi_pkg.sv" \
  "$TB_DIR/axi_lite_demux_read.sv" \
  "$TB_DIR/axi_lite_demux_read_tb.sv" \
  "$SV_DRIVER" \
  > "$LOG_DIR/axi_lite_demux_read_tb.verilator-build.log" \
  2>&1

"$SV_OBJ_DIR/Vtb_axi_read_demux" "$SV_TIMEOUT" | tee "$SV_LOG"
normalize_logic_log "$SV_LOG" "$SV_LOGIC_LOG"

echo "[2/2] Running Anvil compat test_demux_read"
(
  cd "$ANVIL_DIR"
  env -u DEBUG OBJCACHE= make -B run MODULE_NAME=test_demux_read LTOFF=1 COMPATOFF=1 SILENT=1 TIMEOUT="$ANVIL_TIMEOUT"
) | tee "$ANVIL_LOG"
normalize_logic_log "$ANVIL_LOG" "$ANVIL_LOGIC_LOG"

diff -u "$SV_LOGIC_LOG" "$ANVIL_LOGIC_LOG" > "$DIFF_LOG"

echo "Logs written to $LOG_DIR"
echo "Logical logs match"
