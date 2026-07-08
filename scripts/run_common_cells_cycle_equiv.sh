#!/usr/bin/env bash

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
ANVIL_DIR="$ROOT/src/compat"
SV_DIR="$ROOT/src/testbenches"
LOG_ROOT="$ROOT/src/logs/common_cells_cycle_equiv"
BUILD_ROOT="$ROOT/src/build/common_cells_cycle_equiv"
SV_TIMEOUT="${SV_TIMEOUT:-180}"
ANVIL_TIMEOUT="${ANVIL_TIMEOUT:-220}"

normalize_logic_log() {
  local in_file="$1"
  local out_file="$2"

  grep '^\[Cycle' "$in_file" \
    | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//' \
    > "$out_file"
}

run_case() {
  local case_name="$1"
  local sv_file="$2"
  local top_module="$3"
  local trace_define="$4"
  local anvil_module="$5"

  local log_dir="$LOG_ROOT/$case_name"
  local obj_dir="$BUILD_ROOT/${case_name}_obj"
  local driver="$BUILD_ROOT/${case_name}_driver.cpp"
  local sv_log="$log_dir/${sv_file}.log"
  local anvil_log="$log_dir/${anvil_module}.anvil.log"
  local sv_logic_log="$log_dir/${sv_file}.logic.log"
  local anvil_logic_log="$log_dir/${anvil_module}.anvil.logic.log"
  local diff_log="$log_dir/logic.diff"

  mkdir -p "$log_dir" "$BUILD_ROOT"

  echo "[SV] Building and running $sv_file"
  sed "s/Vtop/V${top_module}/g" "$ANVIL_DIR/sim_main.cpp" > "$driver"

  env OBJCACHE= verilator \
    --cc \
    --exe \
    --build \
    -Wno-fatal \
    "-D${trace_define}" \
    --top-module "$top_module" \
    --Mdir "$obj_dir" \
    "$SV_DIR/$sv_file" \
    "$driver" \
    > "$log_dir/${sv_file}.verilator-build.log" \
    2>&1

  "$obj_dir/V${top_module}" "$SV_TIMEOUT" | tee "$sv_log"
  normalize_logic_log "$sv_log" "$sv_logic_log"

  echo "[Anvil] Running $anvil_module"
  (
    cd "$ANVIL_DIR"
    env -u DEBUG OBJCACHE= make -B run MODULE_NAME="$anvil_module" LTOFF=1 COMPAT=1 SILENT=1 TIMEOUT="$ANVIL_TIMEOUT"
  ) | tee "$anvil_log"
  normalize_logic_log "$anvil_log" "$anvil_logic_log"

  diff -u "$sv_logic_log" "$anvil_logic_log" > "$diff_log"
  echo "[OK] $case_name logical traces match"
}

run_case "fifo" "fifo_test.sv" "tb_fifo" "FIFO_TB_TRACE" "test_fifo"
run_case "stream_fifo" "stream_fifo_test.sv" "tb_fifo" "STREAM_FIFO_TB_TRACE" "test_stream_fifo"
run_case "spill_reg" "spill_register_test.sv" "tb_spill" "SPILL_REG_TB_TRACE" "test_spill_reg"
run_case "arbiter" "arbiter_test.sv" "tb_arbiter" "ARBITER_TB_TRACE" "test_arbiter"

echo "Logs written to $LOG_ROOT"
echo "All common-cell logical traces match"
