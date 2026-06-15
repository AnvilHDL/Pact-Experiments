#!/usr/bin/env bash

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
ANVIL_DIR="$ROOT/src/compat"
AXI_DIR="$ROOT/axi"
LOG_DIR="$AXI_DIR/logs/demux_write_cycle_equiv"
SV_OBJ_DIR="$AXI_DIR/build/tb_axi_write_demux_obj"
SV_DRIVER="$AXI_DIR/build/tb_axi_write_demux_driver.cpp"
SV_TIMEOUT="${SV_TIMEOUT:-280}"
ANVIL_TIMEOUT="${ANVIL_TIMEOUT:-300}"
SV_LOG="$LOG_DIR/axi_lite_demux_write_tb.sv.log"
ANVIL_LOG="$LOG_DIR/test_demux_write.anvil.log"
SV_LOGIC_LOG="$LOG_DIR/axi_lite_demux_write_tb.sv.logic.log"
ANVIL_LOGIC_LOG="$LOG_DIR/test_demux_write.anvil.logic.log"
DIFF_LOG="$LOG_DIR/logic.diff"
ANVIL_CHECK_ARGS=()

if [[ "${ANVIL_CHECKS:-0}" != "1" ]]; then
  ANVIL_CHECK_ARGS+=(SESSIONOFF=1 COMPATOFF=1)
fi

normalize_logic_log() {
  local in_file="$1"
  local out_file="$2"

  grep '^\[Cycle' "$in_file" \
    | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//' \
    > "$out_file"
}

mkdir -p "$LOG_DIR" "$AXI_DIR/build"

echo "[1/2] Building and running axi/src/axi_lite_demux_write_tb.sv"
sed 's/Vtop/Vtb_axi_write_demux/g' "$ANVIL_DIR/sim_main.cpp" > "$SV_DRIVER"

env OBJCACHE= verilator \
  --cc \
  --exe \
  --build \
  -Wno-fatal \
  -DAXI_DEMUX_WRITE_TB_TRACE \
  --top-module tb_axi_write_demux \
  --Mdir "$SV_OBJ_DIR" \
  -I"$ROOT/common_cells/include" \
  -I"$AXI_DIR/include" \
  "$ROOT/common_cells/src/spill_register_flushable.sv" \
  "$ROOT/common_cells/src/spill_register.sv" \
  "$ROOT/common_cells/src/fifo_v3.sv" \
  "$AXI_DIR/src/axi_pkg.sv" \
  "$AXI_DIR/src/axi_lite_demux_write.sv" \
  "$AXI_DIR/src/axi_lite_demux_write_tb.sv" \
  "$SV_DRIVER" \
  > "$LOG_DIR/axi_lite_demux_write_tb.verilator-build.log" \
  2>&1

"$SV_OBJ_DIR/Vtb_axi_write_demux" "$SV_TIMEOUT" | tee "$SV_LOG"
normalize_logic_log "$SV_LOG" "$SV_LOGIC_LOG"

echo "[2/2] Running Anvil compat test_demux_write"
(
  cd "$ANVIL_DIR"
  env -u DEBUG OBJCACHE= make run MODULE_NAME=test_demux_write LTOFF=1 COMPAT=1 SILENT=1 TIMEOUT="$ANVIL_TIMEOUT" "${ANVIL_CHECK_ARGS[@]}"
) | tee "$ANVIL_LOG"
normalize_logic_log "$ANVIL_LOG" "$ANVIL_LOGIC_LOG"

diff -u "$SV_LOGIC_LOG" "$ANVIL_LOGIC_LOG" > "$DIFF_LOG"

echo "Logs written to $LOG_DIR"
echo "Logical logs match"
