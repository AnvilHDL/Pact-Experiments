#!/usr/bin/env bash

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PACT_SRC_DIR="$ROOT/src/compat"
AXI_DIR="$ROOT/axi"
TB_DIR="$ROOT/src/testbenches"
LOG_DIR="$ROOT/results/equiv/axi/mux_read_cycle_equiv"
SV_OBJ_DIR="$ROOT/src/build/axi/tb_axi_read_mux_obj"
SV_DRIVER="$ROOT/src/build/axi/tb_axi_read_mux_driver.cpp"
SV_TIMEOUT="${SV_TIMEOUT:-280}"
PACT_TIMEOUT="${PACT_TIMEOUT:-280}"
SV_LOG="$LOG_DIR/axi_lite_mux_read_tb.sv.log"
PACT_LOG="$LOG_DIR/test_mux_read.pact.log"
SV_LOGIC_LOG="$LOG_DIR/axi_lite_mux_read_tb.sv.logic.log"
PACT_LOGIC_LOG="$LOG_DIR/test_mux_read.pact.logic.log"
DIFF_LOG="$LOG_DIR/logic.diff"
PACT_CHECK_ARGS=()

if [[ "${PACT_CHECKS:-1}" != "1" ]]; then
  PACT_CHECK_ARGS+=(SESSIONOFF=1 COMPATOFF=1)
fi

normalize_logic_log() {
  local in_file="$1"
  local out_file="$2"

  grep '^\[Cycle' "$in_file" \
    | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//' \
    | LC_ALL=C sort -s -k2,2n -k3,99 \
    > "$out_file"
}

mkdir -p "$LOG_DIR" "$ROOT/src/build/axi" "$TB_DIR"

echo "[1/2] Building and running src/testbenches/axi_lite_mux_read_tb.sv"

sed 's/Vtop/Vtb_axi_read_mux/g' "$PACT_SRC_DIR/sim_main.cpp" > "$SV_DRIVER"

env OBJCACHE= verilator \
  --cc \
  --exe \
  --build \
  -Wno-fatal \
  -DAXI_MUX_READ_TB_TRACE \
  --top-module tb_axi_read_mux \
  --Mdir "$SV_OBJ_DIR" \
  -I"$ROOT/common_cells/include" \
  -I"$AXI_DIR/include" \
  "$ROOT/common_cells/src/cf_math_pkg.sv" \
  "$ROOT/common_cells/src/lzc.sv" \
  "$ROOT/common_cells/src/rr_arb_tree.sv" \
  "$ROOT/common_cells/src/spill_register_flushable.sv" \
  "$ROOT/common_cells/src/spill_register.sv" \
  "$ROOT/common_cells/src/fifo_v3.sv" \
  "$AXI_DIR/src/axi_pkg.sv" \
  "$TB_DIR/axi_lite_mux_read.sv" \
  "$TB_DIR/axi_lite_mux_read_tb.sv" \
  "$SV_DRIVER" \
  > "$LOG_DIR/axi_lite_mux_read_tb.verilator-build.log" \
  2>&1

"$SV_OBJ_DIR/Vtb_axi_read_mux" "$SV_TIMEOUT" | tee "$SV_LOG"
normalize_logic_log "$SV_LOG" "$SV_LOGIC_LOG"

echo "[2/2] Running PACT compat test_mux_read"
(
  cd "$PACT_SRC_DIR"
  env -u DEBUG OBJCACHE= make -B run MODULE_NAME=test_mux_read LTOFF=1 COMPATOFF=1 SILENT=1 TIMEOUT="$PACT_TIMEOUT" "${PACT_CHECK_ARGS[@]}"
) | tee "$PACT_LOG"
normalize_logic_log "$PACT_LOG" "$PACT_LOGIC_LOG"

diff -u "$SV_LOGIC_LOG" "$PACT_LOGIC_LOG" > "$DIFF_LOG"

echo "Logs written to $LOG_DIR"
echo "Logical logs match"
