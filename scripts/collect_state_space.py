#!/usr/bin/env python3
"""Naive RTL state-space estimate (2**seq_cells, memory bits excluded) for the
full-test scope already used for model checking in formal/comm_safety/*.sby -
DUT plus its driver/harness wiring, not just the isolated core component
collect_yosys_perf.py measures.

SV side: reuses each case's own .sby [script]/[files] section verbatim (same
top module, same file list, comm_safety harness included where the .sby
already includes it) - state_space and model-checking data line up 1:1 for
the same synthesized design.

Anvil side: synthesizes the same case's full src/compat/test_<case>.anvil
file (not type_<case>.anvil, which has no proc bodies) with --top set to the
outermost driver process module, which genuinely instantiates every other
process as a real submodule - so -flatten captures the whole test's state,
not just one isolated process.
"""
import argparse
import csv
import json
import re
import shlex
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ANVIL_DIR = ROOT / "src" / "compat"

# Simulation-only constructs that read_slang can't synthesize; safe to strip
# since they don't affect any register/state - unlike collect_yosys_perf.py's
# core-component scope, this script's --top is the outer driver process
# itself, which does emit these (mainly $finish on a terminal test event).
SIM_ONLY_RE = re.compile(r"^\s*\$(display|write|strobe|monitor|finish)\b.*?;\s*$", re.MULTILINE)
DEFAULT_RESULTS = ROOT / "formal" / "comm_safety" / "results" / "state_space"


@dataclass(frozen=True)
class Case:
    name: str
    sby: str
    anvil_test: str
    anvil_top: str


CASES = [
    Case("fifo", "formal/comm_safety/fifo.sby", "test_fifo.anvil", "test_fifo"),
    Case("spill_register", "formal/comm_safety/spill_register.sby", "test_spill_reg.anvil", "test_spill_reg"),
    Case("stream_fifo", "formal/comm_safety/stream_fifo.sby", "test_stream_fifo.anvil", "test_stream_fifo"),
    Case("arbiter", "formal/comm_safety/arbiter.sby", "test_arbiter.anvil", "test_arbiter"),
    Case("axi_demux_read", "formal/comm_safety/axi_demux_read.sby", "test_demux_read.anvil", "test_demux_read"),
    Case("axi_demux_write", "formal/comm_safety/axi_demux_write.sby", "test_demux_write.anvil", "test_demux_write"),
    Case("axi_mux_read", "formal/comm_safety/axi_mux_read.sby", "test_mux_read.anvil", "test_mux_read"),
    Case("axi_mux_write", "formal/comm_safety/axi_mux_write.sby", "test_mux_write.anvil", "test_mux_write"),
    Case("ace", "formal/comm_safety/ace.sby", "test_ace.anvil", "test_ace"),
    Case("tilelink", "formal/comm_safety/tilelink.sby", "test_tilelink.anvil", "test_tilelink"),
]


def parse_args():
    parser = argparse.ArgumentParser(description="Naive state-space (2**seq_cells) for full-test Anvil vs SV.")
    parser.add_argument("--case", dest="case_names", action="append", help="Run one named case; repeatable")
    parser.add_argument("--results-dir", default=str(DEFAULT_RESULTS))
    parser.add_argument("--timeout-seconds", type=int, default=180)
    return parser.parse_args()


def selected_cases(names):
    if not names:
        return CASES
    wanted = set(names)
    return [case for case in CASES if case.name in wanted]


def read_sby_sections(sby_path):
    sections = {}
    section = None
    with open(sby_path) as sby_file:
        for raw_line in sby_file:
            line = raw_line.strip()
            if not line or line.startswith("#"):
                continue
            if line.startswith("[") and line.endswith("]"):
                section = line[1:-1].split()[0]
                sections.setdefault(section, [])
                continue
            if section:
                sections.setdefault(section, []).append(raw_line.rstrip())
    return sections


STATE_SPACE_RECIPE = [
    # These full-test tops have no data outputs (only clk_i/rst_ni) - a full
    # `synth -flatten` run's reachability-based DCE deletes the entire
    # unreachable design (confirmed empirically: 0 cells without this).
    # `hierarchy`+`flatten` first, THEN `keep` on every wire, THEN just
    # `proc`+`opt_clean` (not the rest of synth's optimization/mapping
    # pipeline) forces every declared register/memory to survive as itself -
    # `proc` still turns always blocks into real $dff/$mem cells so seq_cells
    # is meaningful, it just skips the passes that would prune anything
    # `keep` didn't protect.
    "hierarchy -top {top}",
    "flatten",
    "setattr -set keep 1 w:*",
    "proc",
    "opt_clean",
    "stat -json",
]


def sv_yosys_command(case):
    sby_path = ROOT / case.sby
    sections = read_sby_sections(sby_path)
    read_slang_line = None
    for line in sections.get("script", []):
        if line.strip().startswith("read_slang "):
            read_slang_line = line.strip()
            break
    if read_slang_line is None:
        raise ValueError(f"{case.sby} has no read_slang command")
    top_match = re.search(r"--top\s+(\S+)", read_slang_line)
    if top_match is None:
        raise ValueError(f"{case.sby} read_slang command has no --top")
    top = top_match.group(1)
    script = "\n".join([read_slang_line] + [line.format(top=top) for line in STATE_SPACE_RECIPE])
    return ["yosys", "-m", "slang", "-p", script], top


def anvil_yosys_command(sv_path, top):
    script = "\n".join(
        [f"read_slang --single-unit --top {top} {sv_path.resolve()}"]
        + [line.format(top=top) for line in STATE_SPACE_RECIPE]
    )
    return ["yosys", "-m", "slang", "-p", script]


def run_logged(command, log_path, cwd=ROOT, timeout_seconds=180):
    log_path.parent.mkdir(parents=True, exist_ok=True)
    start = time.perf_counter()
    try:
        proc = subprocess.run(
            command,
            cwd=cwd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            check=False,
            timeout=timeout_seconds or None,
        )
        rc, output = proc.returncode, proc.stdout
    except subprocess.TimeoutExpired as err:
        rc = -124
        output = (err.stdout or "") + f"\n# timeout_seconds: {timeout_seconds}\n"
    elapsed = time.perf_counter() - start
    with log_path.open("w") as log_file:
        log_file.write("$ " + " ".join(command) + "\n")
        log_file.write(output)
        log_file.write(f"\n# elapsed_seconds: {elapsed:.6f}\n# returncode: {rc}\n")
    return rc, elapsed, output


def extract_stat_json(output):
    decoder = json.JSONDecoder()
    for index, char in enumerate(output):
        if char != "{":
            continue
        try:
            parsed, _ = decoder.raw_decode(output[index:])
        except json.JSONDecodeError:
            continue
        if isinstance(parsed, dict) and "modules" in parsed:
            return parsed
    return None


def find_module_stat(stat_json, top):
    modules = stat_json.get("modules", {})
    for key in (top, "\\" + top):
        if key in modules:
            return modules[key]
    for key, value in modules.items():
        if key.lstrip("\\") == top:
            return value
    if len(modules) == 1:
        return next(iter(modules.values()))
    return None


def count_sequential_cells(cell_hist):
    seq_tokens = ("dff", "adff", "sdff", "dlatch", "latch", "$ff")
    return sum(int(count) for name, count in cell_hist.items() if any(tok in name.lower() for tok in seq_tokens))


def count_memory_bits(module_stat):
    return int(module_stat.get("num_memory_bits", 0))


def generate_anvil_sv(case, results_dir, timeout_seconds):
    out_path = results_dir / "generated" / f"{case.name}.anvil.sv"
    log_path = results_dir / "logs" / case.name / "anvil_generate.log"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    log_path.parent.mkdir(parents=True, exist_ok=True)
    command = ["anvil", "-disable-lt-checks", "-disable-compat-checks", "-disable-session-checks", "-O", "3", case.anvil_test]
    start = time.perf_counter()
    with out_path.open("w") as stdout_file, log_path.open("w") as log_file:
        log_file.write("$ " + " ".join(command) + " (cwd=" + str(ANVIL_DIR) + ")\n")
        try:
            proc = subprocess.run(command, cwd=ANVIL_DIR, stdout=stdout_file, stderr=log_file, check=False, timeout=timeout_seconds or None)
            rc = proc.returncode
        except subprocess.TimeoutExpired:
            rc = -124
            log_file.write(f"\n# timeout_seconds: {timeout_seconds}\n")
        log_file.write(f"# elapsed_seconds: {time.perf_counter() - start:.6f}\n# returncode: {rc}\n")
    if rc != 0 or not out_path.exists() or out_path.stat().st_size == 0:
        return None

    sanitized_path = results_dir / "generated" / f"{case.name}.anvil.yosys.sv"
    sanitized_text, stripped = SIM_ONLY_RE.subn("", out_path.read_text())
    sanitized_path.write_text(sanitized_text)
    if stripped:
        with log_path.open("a") as log_file:
            log_file.write(f"# sanitizer: stripped {stripped} simulation-only statement(s)\n")
    return sanitized_path


def measure(command, cwd, top, log_path, timeout_seconds):
    rc, elapsed, output = run_logged(command, log_path, cwd=cwd, timeout_seconds=timeout_seconds)
    if rc != 0:
        return {"status": f"FAIL({rc})", "seq_cells": "", "memory_bits": "", "state_space_2pow": "", "elapsed_seconds": f"{elapsed:.6f}"}
    stat_json = extract_stat_json(output)
    if stat_json is None:
        return {"status": "STAT_PARSE_FAIL", "seq_cells": "", "memory_bits": "", "state_space_2pow": "", "elapsed_seconds": f"{elapsed:.6f}"}
    module_stat = find_module_stat(stat_json, top)
    if module_stat is None:
        return {"status": "MODULE_NOT_FOUND", "seq_cells": "", "memory_bits": "", "state_space_2pow": "", "elapsed_seconds": f"{elapsed:.6f}"}
    cell_hist = {str(k): int(v) for k, v in module_stat.get("num_cells_by_type", {}).items()}
    seq_cells = count_sequential_cells(cell_hist)
    memory_bits = count_memory_bits(module_stat)
    return {
        "status": "PASS",
        "seq_cells": seq_cells,
        "memory_bits": memory_bits,
        "state_space_2pow": f"2^{seq_cells}",
        "elapsed_seconds": f"{elapsed:.6f}",
    }


def main():
    args = parse_args()
    results_dir = Path(args.results_dir)
    if not results_dir.is_absolute():
        results_dir = ROOT / results_dir
    results_dir.mkdir(parents=True, exist_ok=True)

    rows = []
    for case in selected_cases(args.case_names):
        print(f"[{case.name}] sv", flush=True)
        row = {"case": case.name}
        try:
            command, top = sv_yosys_command(case)
            sv_result = measure(command, ROOT, top, results_dir / "logs" / case.name / "sv.log", args.timeout_seconds)
        except ValueError as err:
            sv_result = {"status": f"ERROR({err})", "seq_cells": "", "memory_bits": "", "state_space_2pow": "", "elapsed_seconds": ""}
        row.update({f"sv_{k}": v for k, v in sv_result.items()})

        print(f"[{case.name}] anvil generate", flush=True)
        anvil_sv = generate_anvil_sv(case, results_dir, args.timeout_seconds)
        if anvil_sv is None:
            anvil_result = {"status": "GENERATE_FAIL", "seq_cells": "", "memory_bits": "", "state_space_2pow": "", "elapsed_seconds": ""}
        else:
            print(f"[{case.name}] anvil synth", flush=True)
            command = anvil_yosys_command(anvil_sv, case.anvil_top)
            anvil_result = measure(command, ROOT, case.anvil_top, results_dir / "logs" / case.name / "anvil_synth.log", args.timeout_seconds)
        row.update({f"anvil_{k}": v for k, v in anvil_result.items()})

        print(
            f"[{case.name}] done: sv={row['sv_status']} seq={row['sv_seq_cells']} "
            f"anvil={row['anvil_status']} seq={row['anvil_seq_cells']}",
            flush=True,
        )
        rows.append(row)

    csv_path = results_dir / "state_space.csv"
    with csv_path.open("w", newline="") as csv_file:
        fieldnames = [
            "case",
            "sv_status", "sv_seq_cells", "sv_memory_bits", "sv_state_space_2pow", "sv_elapsed_seconds",
            "anvil_status", "anvil_seq_cells", "anvil_memory_bits", "anvil_state_space_2pow", "anvil_elapsed_seconds",
        ]
        writer = csv.DictWriter(csv_file, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
    print(f"Wrote {csv_path.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
