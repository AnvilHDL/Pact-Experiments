#!/usr/bin/env bash
# Refresh one tracked testbench copy under src/testbenches/ from its submodule
# working-tree original, without losing the FORMAL_COMM_SAFETY instrumentation
# that the formal/comm_safety harnesses depend on.
#
#   usage: scripts/refresh_testbench.sh <submodule-copy> <tracked-copy>
#
# - submodule copy present   -> copy it over the tracked copy, then re-apply the
#                               formal self-report blocks (idempotent).
# - submodule copy absent    -> keep the tracked copy (it is the only versioned
#                               one; the submodules never carried these files).
# - neither present          -> fail: the file has to be (re)generated first.
set -euo pipefail

src="$1"
dst="$2"
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

if [[ -f "$src" ]]; then
  cp "$src" "$dst"
  python3 "$ROOT/scripts/instrument_comm_safety.py" --if-known "$dst"
elif [[ -f "$dst" ]]; then
  echo "[refresh_testbench] $src not present (not versioned in its submodule); building from tracked $dst" >&2
else
  echo "[refresh_testbench] ERROR: neither $src nor $dst exists." >&2
  echo "[refresh_testbench] $(basename "$dst") is not versioned anywhere; regenerate it (see testbench.md) and place it at one of those paths." >&2
  exit 1
fi
