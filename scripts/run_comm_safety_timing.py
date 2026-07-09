#!/usr/bin/env python3
import argparse
import csv
import re
import shlex
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path


# sby's own exit-code convention (see sby_core.py): the overall run status is
# encoded in the low bits regardless of the `expect` setting.
SBY_RETCODE_STATUS = {
    0: "PASS",
    1: "PASS",
    2: "FAIL",
    4: "UNKNOWN",
    8: "TIMEOUT",
    16: "ERROR",
    32: "CANCELLED",
}


def sby_status_from_retcode(rc):
    return SBY_RETCODE_STATUS.get(rc, f"FAIL({rc})")


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_RESULTS_BASE = ROOT / "formal" / "comm_safety" / "results"


@dataclass(frozen=True)
class Case:
    name: str
    phase: str
    sby: str
    anvil_type: str
    harness_module: str


SHORT_CASES = [
    Case("fifo", "short", "formal/comm_safety/fifo.sby", "type_fifo.anvil", "comm_fifo_formal"),
    Case("spill_register", "short", "formal/comm_safety/spill_register.sby", "type_spill_reg.anvil", "comm_spill_formal"),
    Case("stream_fifo", "short", "formal/comm_safety/stream_fifo.sby", "type_stream_fifo.anvil", "comm_stream_fifo_formal"),
    Case("arbiter", "short", "formal/comm_safety/arbiter.sby", "type_arbiter.anvil", "comm_arbiter_formal"),
    Case("axi_demux_read", "short", "formal/comm_safety/axi_demux_read.sby", "type_demux_read.anvil", "comm_axi_demux_read_formal"),
]

BIG_CASES = [
    Case("axi_demux_write", "big", "formal/comm_safety/axi_demux_write.sby", "type_demux_write.anvil", "comm_axi_demux_write_formal"),
    Case("axi_mux_read", "big", "formal/comm_safety/axi_mux_read.sby", "type_mux_read_simplified.anvil", "comm_axi_mux_read_formal"),
    Case("axi_mux_write", "big", "formal/comm_safety/axi_mux_write.sby", "type_mux_4p_write.anvil", "comm_axi_mux_write_formal"),
    Case("ace", "big", "formal/comm_safety/ace.sby", "type_ace.anvil", "comm_ace_formal"),
    Case("tilelink", "big", "formal/comm_safety/tilelink.sby", "type_tilelink.anvil", "comm_tilelink_formal"),
]

HARNESS_FILES = [
    ROOT / "formal" / "comm_safety" / "sv" / "comm_safety_common.sv",
    ROOT / "formal" / "comm_safety" / "sv" / "comm_safety_tb_wrappers.sv",
]


def sby_depth(sby_path):
    with open(sby_path) as f:
        for line in f:
            parts = line.split()
            if len(parts) == 2 and parts[0] == "depth":
                return int(parts[1])
    return None


def harness_assertion_counts(module_name):
    """(lines, asserts, assumes) for a case's `module comm_<case>_formal ...
    endmodule` block - the actual property/assumption set k-induction proves
    against, not just a pass/fail summary."""
    for path in HARNESS_FILES:
        if not path.exists():
            continue
        text = path.read_text(errors="ignore")
        match = re.search(rf"^module\s+{re.escape(module_name)}\b", text, re.MULTILINE)
        if match is None:
            continue
        start = match.start()
        end = text.find("\nendmodule", start)
        if end == -1:
            continue
        end += len("\nendmodule")
        body = text[start:end]
        active_body = "\n".join(line for line in body.splitlines() if not line.lstrip().startswith("//"))
        return len(body.splitlines()), len(re.findall(r"\bassert\s*\(", active_body)), len(re.findall(r"\bassume\s*\(", active_body))
    return None, None, None


def parse_args():
    parser = argparse.ArgumentParser(description="Time communication-safety SBY and Anvil checks.")
    parser.add_argument("--phase", choices=["short", "big", "all"], default="short")
    parser.add_argument("--mode", choices=["2", "3", "4"], default="2")
    parser.add_argument(
        "--results-dir",
        default=None,
        help=f"Default: a new timestamped directory under {DEFAULT_RESULTS_BASE.relative_to(ROOT)}/ "
        "(never overwrites a previous run's results)",
    )
    parser.add_argument("--case", dest="case_names", action="append", help="Run one named case; repeatable")
    parser.add_argument("--skip-yosys", action="store_true")
    parser.add_argument("--skip-anvil", action="store_true")
    parser.add_argument("--checker", choices=["sby", "ebmc", "both"], default="sby")
    parser.add_argument("--ebmc-bound", type=int, help="Override the bound used for EBMC k-induction")
    parser.add_argument("--ebmc-solver", choices=["yices", "z3", "boolector", "cvc4", "mathsat"], default="yices")
    parser.add_argument(
        "--setup-only",
        action="store_true",
        help="Only set up SBY workdirs for frontend/debug checks. Default runs the full model checker.",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=None,
        help="Wall-clock seconds to allow each individual sby/ebmc/anvil subprocess before killing it "
        "(each of the up-to-3 steps per case gets its own budget, not a shared one). "
        "Default: none (run to completion).",
    )
    parser.add_argument(
        "--jobs",
        type=int,
        default=1,
        help="Number of cases to run concurrently (each case's own sby/ebmc/anvil steps still run "
        "sequentially within that case). Default: 1 (sequential, original behavior).",
    )
    return parser.parse_args()


def selected_cases(phase, names):
    cases = []
    if phase in ("short", "all"):
        cases.extend(SHORT_CASES)
    if phase in ("big", "all"):
        cases.extend(BIG_CASES)
    if names:
        wanted = set(names)
        cases = [case for case in cases if case.name in wanted]
    return cases


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


def sby_depth(sby_path):
    for line in read_sby_sections(sby_path).get("options", []):
        parts = line.split()
        if len(parts) == 2 and parts[0] == "depth":
            return int(parts[1])
    return 1


def ebmc_args_from_sby(case, bound_override=None, solver="yices"):
    sby_path = ROOT / case.sby
    sections = read_sby_sections(sby_path)
    read_slang_line = None
    for line in sections.get("script", []):
        if line.strip().startswith("read_slang "):
            read_slang_line = line
            break
    if read_slang_line is None:
        raise ValueError(f"{case.sby} does not contain a read_slang command")

    tokens = shlex.split(read_slang_line)
    top = None
    defines = []
    includes = []
    files = []

    i = 1
    while i < len(tokens):
        token = tokens[i]
        if token in ("--top", "-top"):
            top = tokens[i + 1]
            i += 2
        elif token == "-D":
            defines.append(tokens[i + 1])
            i += 2
        elif token.startswith("-D"):
            defines.append(token[2:])
            i += 1
        elif token == "-I":
            includes.append(tokens[i + 1])
            i += 2
        elif token.startswith("-I"):
            includes.append(token[2:])
            i += 1
        elif token.startswith("-"):
            i += 1
        else:
            files.append(token)
            i += 1

    if top is None:
        raise ValueError(f"{case.sby} read_slang command has no --top")

    command = [
        "ebmc",
        "--systemverilog",
        "--top",
        top,
        "--bound",
        str(bound_override or sby_depth(sby_path)),
        "--k-induction",
        "--liveness-to-safety",
        f"--{solver}",
    ]
    for define in defines:
        command.extend(["-D", define])
    for include in includes:
        command.extend(["-I", include])
    command.extend(files)
    return command


def run_logged(command, log_path, timeout_seconds=None):
    start = time.perf_counter()
    with open(log_path, "w") as log_file:
        log_file.write("$ " + " ".join(command) + "\n")
        log_file.flush()
        try:
            proc = subprocess.run(
                command,
                cwd=ROOT,
                stdout=log_file,
                stderr=subprocess.STDOUT,
                check=False,
                timeout=timeout_seconds,
            )
            rc = proc.returncode
        except subprocess.TimeoutExpired:
            rc = None
            log_file.write(f"\n# TIMED OUT after {timeout_seconds}s (external timeout)\n")
    return rc, time.perf_counter() - start


def run_sby(case, results_dir, setup_only=False, timeout_seconds=None):
    log_path = results_dir / f"{case.name}.log"
    workdir = results_dir / f"sby_{case.name}"
    command = ["sby", "-f"]
    if setup_only:
        command.append("--setup")
    command.extend(["-d", str(workdir), str(ROOT / case.sby)])
    rc, elapsed = run_logged(command, log_path, timeout_seconds=timeout_seconds)
    status = "EXTERNAL_TIMEOUT" if rc is None else sby_status_from_retcode(rc)
    return {
        "yosys_mode": "setup_only" if setup_only else "model_check",
        "yosys_status": status,
        "yosys_seconds": f"{elapsed:.6f}",
        "yosys_log": str(log_path.relative_to(ROOT)),
    }


def run_ebmc(case, results_dir, bound_override=None, solver="yices", timeout_seconds=None):
    log_path = results_dir / f"{case.name}.ebmc.log"
    try:
        command = ebmc_args_from_sby(case, bound_override=bound_override, solver=solver)
    except ValueError as err:
        log_path.write_text(str(err) + "\n")
        return {
            "ebmc_status": "ERROR",
            "ebmc_seconds": "0.000000",
            "ebmc_log": str(log_path.relative_to(ROOT)),
        }
    rc, elapsed = run_logged(command, log_path, timeout_seconds=timeout_seconds)
    status = "EXTERNAL_TIMEOUT" if rc is None else ("PASS" if rc == 0 else f"FAIL({rc})")
    return {
        "ebmc_status": status,
        "ebmc_seconds": f"{elapsed:.6f}",
        "ebmc_log": str(log_path.relative_to(ROOT)),
    }


def read_single_anvil_csv(path):
    with open(path, newline="") as csv_file:
        rows = list(csv.DictReader(csv_file))
    if not rows:
        return "Error", ""
    return rows[0].get("result", "Error"), rows[0].get("elapsed_seconds", "")


def run_anvil(case, mode, results_dir, timeout_seconds=None):
    log_path = results_dir / f"{case.name}.anvil.log"
    csv_path = results_dir / f"{case.name}.anvil.csv"
    # run_compat.py only writes this CSV once, after its whole run completes -
    # remove any stale file first so a killed/timed-out subprocess can't be
    # mistaken for a fresh result below.
    csv_path.unlink(missing_ok=True)
    command = [
        sys.executable,
        "run_compat.py",
        str(mode),
        "--only",
        case.anvil_type,
        "--csv",
        str(csv_path),
    ]
    rc, elapsed = run_logged(command, log_path, timeout_seconds=timeout_seconds)
    if rc is None:
        return {
            "anvil_status": "EXTERNAL_TIMEOUT",
            "anvil_seconds": f"{elapsed:.6f}",
            "anvil_log": str(log_path.relative_to(ROOT)),
        }
    if csv_path.exists():
        result, compat_elapsed = read_single_anvil_csv(csv_path)
    else:
        result, compat_elapsed = "Error", ""
    status = result if rc == 0 else f"{result}/FAIL({rc})"
    return {
        "anvil_status": status,
        "anvil_seconds": compat_elapsed or f"{elapsed:.6f}",
        "anvil_log": str(log_path.relative_to(ROOT)),
    }


def run_case(case, args, results_dir):
    print(f"[{case.name}] starting", flush=True)
    harness_lines, harness_asserts, harness_assumes = harness_assertion_counts(case.harness_module)
    row = {
        "case": case.name,
        "phase": case.phase,
        "sby": case.sby,
        "anvil_type": case.anvil_type,
        "harness_module": case.harness_module,
        "kinduction_depth": sby_depth(ROOT / case.sby),
        "harness_lines": harness_lines,
        "harness_asserts": harness_asserts,
        "harness_assumes": harness_assumes,
    }
    if args.skip_yosys:
        row.update({"yosys_mode": "skipped", "yosys_status": "SKIPPED", "yosys_seconds": "", "yosys_log": ""})
        row.update({"ebmc_status": "SKIPPED", "ebmc_seconds": "", "ebmc_log": ""})
    else:
        if args.checker in ("sby", "both"):
            print(f"[{case.name}] running {'SBY setup only' if args.setup_only else 'full SBY model check'}", flush=True)
            row.update(run_sby(case, results_dir, setup_only=args.setup_only, timeout_seconds=args.timeout))
        else:
            row.update({"yosys_mode": "not_selected", "yosys_status": "SKIPPED", "yosys_seconds": "", "yosys_log": ""})

        if args.checker in ("ebmc", "both") and not args.setup_only:
            print(f"[{case.name}] running EBMC proof mode", flush=True)
            row.update(run_ebmc(case, results_dir, bound_override=args.ebmc_bound, solver=args.ebmc_solver, timeout_seconds=args.timeout))
        else:
            row.update({"ebmc_status": "SKIPPED", "ebmc_seconds": "", "ebmc_log": ""})

    if args.skip_anvil:
        row.update({"anvil_status": "SKIPPED", "anvil_seconds": "", "anvil_log": ""})
    else:
        row.update(run_anvil(case, args.mode, results_dir, timeout_seconds=args.timeout))

    print(
        f"[{case.name}] done: yosys={row['yosys_status']} {row['yosys_seconds']}s "
        f"ebmc={row['ebmc_status']} {row['ebmc_seconds']}s "
        f"anvil={row['anvil_status']} {row['anvil_seconds']}s",
        flush=True,
    )
    return row


def main():
    args = parse_args()
    if args.results_dir is None:
        results_dir = DEFAULT_RESULTS_BASE / datetime.now().strftime("%Y%m%d_%H%M%S")
    else:
        results_dir = Path(args.results_dir)
        if not results_dir.is_absolute():
            results_dir = ROOT / results_dir
    results_dir.mkdir(parents=True, exist_ok=True)
    print(f"Results directory: {results_dir.relative_to(ROOT)}", flush=True)

    cases = selected_cases(args.phase, args.case_names)
    if not cases:
        print("No cases selected.", file=sys.stderr)
        return 1

    rows_by_case = {}
    if args.jobs <= 1:
        for case in cases:
            rows_by_case[case.name] = run_case(case, args, results_dir)
    else:
        with ThreadPoolExecutor(max_workers=args.jobs) as pool:
            futures = {pool.submit(run_case, case, args, results_dir): case for case in cases}
            for future in as_completed(futures):
                case = futures[future]
                rows_by_case[case.name] = future.result()

    rows = [rows_by_case[case.name] for case in cases]

    timing_csv = results_dir / "timing.csv"
    with open(timing_csv, "w", newline="") as csv_file:
        writer = csv.DictWriter(
            csv_file,
            fieldnames=[
                "case",
                "phase",
                "yosys_mode",
                "yosys_status",
                "yosys_seconds",
                "kinduction_depth",
                "harness_module",
                "harness_lines",
                "harness_asserts",
                "harness_assumes",
                "anvil_status",
                "anvil_seconds",
                "ebmc_status",
                "ebmc_seconds",
                "sby",
                "anvil_type",
                "yosys_log",
                "ebmc_log",
                "anvil_log",
            ],
        )
        writer.writeheader()
        writer.writerows(rows)

    print(f"Wrote {timing_csv.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
