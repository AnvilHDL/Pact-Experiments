#!/usr/bin/env python3
import argparse
import csv
import shlex
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_RESULTS = ROOT / "formal" / "comm_safety" / "results"


@dataclass(frozen=True)
class Case:
    name: str
    phase: str
    sby: str
    anvil_type: str


SHORT_CASES = [
    Case("fifo", "short", "formal/comm_safety/fifo.sby", "type_fifo.anvil"),
    Case("spill_register", "short", "formal/comm_safety/spill_register.sby", "type_spill_reg.anvil"),
    Case("stream_fifo", "short", "formal/comm_safety/stream_fifo.sby", "type_stream_fifo.anvil"),
    Case("arbiter", "short", "formal/comm_safety/arbiter.sby", "type_arbiter.anvil"),
    Case("axi_demux_read", "short", "formal/comm_safety/axi_demux_read.sby", "type_demux_read.anvil"),
]

BIG_CASES = [
    Case("axi_demux_write", "big", "formal/comm_safety/axi_demux_write.sby", "type_demux_write.anvil"),
    Case("axi_mux_read", "big", "formal/comm_safety/axi_mux_read.sby", "type_mux_read_simplified.anvil"),
    Case("axi_mux_write", "big", "formal/comm_safety/axi_mux_write.sby", "type_mux_write_simplified.anvil"),
    Case("ace", "big", "formal/comm_safety/ace.sby", "type_ace.anvil"),
    Case("tilelink", "big", "formal/comm_safety/tilelink.sby", "type_tilelink.anvil"),
]


def parse_args():
    parser = argparse.ArgumentParser(description="Time communication-safety SBY and Anvil checks.")
    parser.add_argument("--phase", choices=["short", "big", "all"], default="short")
    parser.add_argument("--mode", choices=["2", "3", "4"], default="4")
    parser.add_argument("--results-dir", default=str(DEFAULT_RESULTS))
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


def run_logged(command, log_path):
    start = time.perf_counter()
    with open(log_path, "w") as log_file:
        log_file.write("$ " + " ".join(command) + "\n")
        log_file.flush()
        proc = subprocess.run(
            command,
            cwd=ROOT,
            stdout=log_file,
            stderr=subprocess.STDOUT,
            check=False,
        )
    return proc.returncode, time.perf_counter() - start


def run_sby(case, results_dir, setup_only=False):
    log_path = results_dir / f"{case.name}.log"
    workdir = results_dir / f"sby_{case.name}"
    command = ["sby", "-f"]
    if setup_only:
        command.append("--setup")
    command.extend(["-d", str(workdir), str(ROOT / case.sby)])
    rc, elapsed = run_logged(command, log_path)
    return {
        "yosys_mode": "setup_only" if setup_only else "model_check",
        "yosys_status": "PASS" if rc == 0 else f"FAIL({rc})",
        "yosys_seconds": f"{elapsed:.6f}",
        "yosys_log": str(log_path.relative_to(ROOT)),
    }


def run_ebmc(case, results_dir, bound_override=None, solver="yices"):
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
    rc, elapsed = run_logged(command, log_path)
    return {
        "ebmc_status": "PASS" if rc == 0 else f"FAIL({rc})",
        "ebmc_seconds": f"{elapsed:.6f}",
        "ebmc_log": str(log_path.relative_to(ROOT)),
    }


def read_single_anvil_csv(path):
    with open(path, newline="") as csv_file:
        rows = list(csv.DictReader(csv_file))
    if not rows:
        return "Error", ""
    return rows[0].get("result", "Error"), rows[0].get("elapsed_seconds", "")


def run_anvil(case, mode, results_dir):
    log_path = results_dir / f"{case.name}.anvil.log"
    csv_path = results_dir / f"{case.name}.anvil.csv"
    command = [
        sys.executable,
        "run_compat.py",
        str(mode),
        "--only",
        case.anvil_type,
        "--csv",
        str(csv_path),
    ]
    rc, elapsed = run_logged(command, log_path)
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


def main():
    args = parse_args()
    results_dir = Path(args.results_dir)
    if not results_dir.is_absolute():
        results_dir = ROOT / results_dir
    results_dir.mkdir(parents=True, exist_ok=True)

    cases = selected_cases(args.phase, args.case_names)
    if not cases:
        print("No cases selected.", file=sys.stderr)
        return 1

    rows = []
    for case in cases:
        print(f"[{case.name}] starting")
        row = {
            "case": case.name,
            "phase": case.phase,
            "sby": case.sby,
            "anvil_type": case.anvil_type,
        }
        if args.skip_yosys:
            row.update({"yosys_mode": "skipped", "yosys_status": "SKIPPED", "yosys_seconds": "", "yosys_log": ""})
        else:
            if args.checker in ("sby", "both"):
                print(f"[{case.name}] running {'SBY setup only' if args.setup_only else 'full SBY model check'}")
                row.update(run_sby(case, results_dir, setup_only=args.setup_only))
            else:
                row.update({"yosys_mode": "not_selected", "yosys_status": "SKIPPED", "yosys_seconds": "", "yosys_log": ""})

            if args.checker in ("ebmc", "both") and not args.setup_only:
                print(f"[{case.name}] running EBMC proof mode")
                row.update(run_ebmc(case, results_dir, bound_override=args.ebmc_bound, solver=args.ebmc_solver))
            else:
                row.update({"ebmc_status": "SKIPPED", "ebmc_seconds": "", "ebmc_log": ""})

        if args.skip_anvil:
            row.update({"anvil_status": "SKIPPED", "anvil_seconds": "", "anvil_log": ""})
        else:
            row.update(run_anvil(case, args.mode, results_dir))

        rows.append(row)
        print(
            f"[{case.name}] yosys={row['yosys_status']} {row['yosys_seconds']}s "
            f"ebmc={row['ebmc_status']} {row['ebmc_seconds']}s "
            f"anvil={row['anvil_status']} {row['anvil_seconds']}s"
        )

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
