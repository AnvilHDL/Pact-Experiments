#!/usr/bin/env bash

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PACT_SRC_DIR="$ROOT/src/compat"
SV_DIR="$ROOT/src/testbenches"
LOG_ROOT="$ROOT/results/equiv/common_cells"
BUILD_ROOT="$ROOT/src/build/common_cells_cycle_equiv"
SV_TIMEOUT="${SV_TIMEOUT:-180}"
PACT_TIMEOUT="${PACT_TIMEOUT:-220}"

normalize_logic_log() {
  local in_file="$1"
  local out_file="$2"

  grep '^\[Cycle' "$in_file" \
    | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//' \
    | LC_ALL=C sort -s -k2,2n -k3,99 \
    > "$out_file"
}

run_case() {
  local case_name="$1"
  local sv_file="$2"
  local top_module="$3"
  local trace_define="$4"
  local pact_module="$5"

  local log_dir="$LOG_ROOT/$case_name"
  local obj_dir="$BUILD_ROOT/${case_name}_obj"
  local driver="$BUILD_ROOT/${case_name}_driver.cpp"
  local sv_log="$log_dir/${sv_file}.log"
  local pact_log="$log_dir/${pact_module}.pact.log"
  local sv_logic_log="$log_dir/${sv_file}.logic.log"
  local pact_logic_log="$log_dir/${pact_module}.pact.logic.log"
  local diff_log="$log_dir/logic.diff"

  mkdir -p "$log_dir" "$BUILD_ROOT"

  echo "[SV] Building and running $sv_file"
  sed "s/Vtop/V${top_module}/g" "$PACT_SRC_DIR/sim_main.cpp" > "$driver"

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

  echo "[PACT] Running $pact_module"
  (
    cd "$PACT_SRC_DIR"
    env -u DEBUG OBJCACHE= make -B run MODULE_NAME="$pact_module" LTOFF=1 COMPATOFF=1 SILENT=1 TIMEOUT="$PACT_TIMEOUT"
  ) | tee "$pact_log"
  normalize_logic_log "$pact_log" "$pact_logic_log"

  diff -u "$sv_logic_log" "$pact_logic_log" > "$diff_log"
  echo "[OK] $case_name logical traces match"
}

run_case "fifo" "fifo_test.sv" "tb_fifo" "FIFO_TB_TRACE" "test_fifo"
run_case "stream_fifo" "stream_fifo_test.sv" "tb_fifo" "STREAM_FIFO_TB_TRACE" "test_stream_fifo"
run_case "spill_reg" "spill_register_test.sv" "tb_spill" "SPILL_REG_TB_TRACE" "test_spill_reg"
run_case "arbiter" "arbiter_test.sv" "tb_arbiter" "ARBITER_TB_TRACE" "test_arbiter"

echo "Logs written to $LOG_ROOT"
echo "All common-cell logical traces match"
