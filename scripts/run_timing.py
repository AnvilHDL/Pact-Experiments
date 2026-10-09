#!/usr/bin/env python3
"""Compatibility-checking time (Pact) and model-checking time (SymbiYosys) for the ten benchmarks.

Pact: `pact -just-check -debug-choice 3 -j N` on each benchmark's type pool, N = 1 and 8,
median of 5 runs (1 run once a run exceeds --rep-cutoff seconds).
SymbiYosys: k-induction (depth 500) on the communication-safety harness, three runs per
benchmark: S assertions only (safety), L assertions only (liveness), all assertions.

Output directory (default results/timing_<time>/):
  comparison.md     expected / measured values for every benchmark
  summary.json      measured values
  pact_runs.csv, sv_runs.csv, members.json, invocations.json, pact_logs/, sby/

Examples:
  python3 scripts/run_timing.py                          # Pact and SymbiYosys, all benchmarks
  python3 scripts/run_timing.py --part pact
  python3 scripts/run_timing.py --part sv --sv-jobs 15
  python3 scripts/run_timing.py --part pact --case fifo --case arbiter
"""
import argparse
import csv
import fcntl
import json
import os
import platform
import re
import shutil
import signal
import statistics
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXPECTED_DIR = ROOT / "expected"
COMPAT_DIR = ROOT / "src" / "compat"
PACT_DIR = Path(os.environ.get("PACT_DIR", ROOT.parent / "Pact")).resolve()


@dataclass(frozen=True)
class Case:
    name: str
    label: str
    pact_type: str
    sby: str


# Paper row order; the big cases use the 4-port (full pool) type files.
CASES = [
    Case("fifo", "FIFO", "type_fifo.anvil", "fifo.sby"),
    Case("stream_fifo", "Stream FIFO", "type_stream_fifo.anvil", "stream_fifo.sby"),
    Case("spill_register", "Spill reg.", "type_spill_reg.anvil", "spill_register.sby"),
    Case("arbiter", "Arbiter", "type_arbiter.anvil", "arbiter.sby"),
    Case("ace", "ACE", "type_ace.anvil", "ace.sby"),
    Case("tilelink", "TileLink", "type_tilelink.anvil", "tilelink.sby"),
    Case("axi_demux_read", "AXI demux R", "type_demux_read.anvil", "axi_demux_read.sby"),
    Case("axi_demux_write", "AXI demux W", "type_demux_write.anvil", "axi_demux_write.sby"),
    Case("axi_mux_read", "AXI mux R", "type_mux_read.anvil", "axi_mux_read.sby"),
    Case("axi_mux_write", "AXI mux W", "type_mux_write.anvil", "axi_mux_write.sby"),
]

# Harness defines that keep one half of the assertions (see comm_safety_*.sv).
SV_VARIANTS = {"full": None, "safety": "COMM_ONLY_S", "live": "COMM_ONLY_L"}


def parse_args():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--part", choices=["pact", "sv", "all"], default="all")
    p.add_argument("--case", action="append", dest="cases", help="Run only this case (repeatable)")
    p.add_argument("--results-dir", help="Output directory (default: new timestamped directory)")
    p.add_argument("--pact", help="Pact binary (default: $PACT_DIR/_build/default/bin/main.exe, copied into the results)")
    p.add_argument("--modes", default="3", help="Comma-separated Pact -debug-choice modes (default 3)")
    p.add_argument("--threads", default="1,8", help="Comma-separated -j values (default 1,8)")
    p.add_argument("--reps", type=int, default=5, help="Pact repetitions per configuration; the median is reported")
    p.add_argument("--rep-cutoff", type=float, default=300.0,
                   help="Stop repeating a configuration once one run exceeds this many seconds")
    p.add_argument("--pact-timeout", type=float, default=7200.0, help="Limit per Pact run in seconds")
    p.add_argument("--pact-jobs", type=int, default=1,
                   help="Pact configurations (case, mode, threads) run in parallel; repetitions stay sequential")
    p.add_argument("--pact-mem", default="48G", help="Memory cap per Pact run (systemd-run), '' to disable")
    p.add_argument("--sv-variants", default="full,safety,live")
    p.add_argument("--sv-timeout", type=float, default=7200.0, help="SBY timeout per run in seconds (paper: 2 h)")
    p.add_argument("--sv-jobs", type=int, default=1, help="SBY runs in parallel (each uses two solver processes)")
    p.add_argument("--sv-mem", default="16G", help="Memory cap per SBY run (systemd-run), '' to disable")
    p.add_argument("--report-only", metavar="DIR", help="Only rebuild comparison.md for an existing results directory")
    p.add_argument("--write-expected", action="store_true", help="Store the results as expected/*.json (maintainers)")
    return p.parse_args()


def capture(cmd, cwd=None):
    try:
        return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=60).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return ""


def have_systemd_scope():
    return shutil.which("systemd-run") is not None and subprocess.run(
        ["systemd-run", "--user", "--scope", "-q", "true"], capture_output=True).returncode == 0


def capped(cmd, mem):
    if mem and have_systemd_scope():
        return ["systemd-run", "--user", "--scope", "-q", "-p", f"MemoryMax={mem}", "-p", "MemorySwapMax=0", *cmd]
    return cmd


def run_timed(cmd, cwd, log_path, timeout):
    """Run cmd in its own process group; return (returncode or None on timeout, wall seconds)."""
    with open(log_path, "w") as log:
        log.write("$ " + " ".join(map(str, cmd)) + "\n")
        log.flush()
        start = time.perf_counter()
        proc = subprocess.Popen(cmd, cwd=cwd, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            rc = proc.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            os.killpg(proc.pid, signal.SIGKILL)
            proc.wait()
            rc = None
        elapsed = time.perf_counter() - start
        if rc is None:
            log.write(f"\n# killed after {timeout:.0f} s\n")
    return rc, elapsed


def environment(pact_bin):
    def git(path, *args):
        return capture(["git", *args], cwd=path)

    info = {
        "date": datetime.now().astimezone().isoformat(timespec="seconds"),
        "host": platform.node(),
        "cpu": next((l.split(":", 1)[1].strip() for l in open("/proc/cpuinfo") if l.startswith("model name")), ""),
        "cores": os.cpu_count(),
        "loadavg_start": os.getloadavg(),
        "python": sys.version.split()[0],
        "pact_binary": str(pact_bin) if pact_bin else None,
        "revisions": {},
        "tools": {},
    }
    for name, path in [("Pact", PACT_DIR), ("Pact-Experiments", ROOT)]:
        info["revisions"][name] = {
            "commit": git(path, "rev-parse", "HEAD"),
            "branch": git(path, "rev-parse", "--abbrev-ref", "HEAD"),
            "dirty": git(path, "status", "--porcelain", "--untracked-files=no").splitlines(),
        }
    info["revisions"]["submodules"] = git(ROOT, "submodule", "status").splitlines()
    for tool, args in [("yosys", ["-V"]), ("sby", ["--version"]), ("yices-smt2", ["--version"])]:
        if shutil.which(tool):
            out = capture([tool, *args])
            info["tools"][tool] = out.splitlines()[0] if out else ""
    if pact_bin:
        info["pact_sha256"] = capture(["sha256sum", str(pact_bin)]).split()[0]
    return info


# ---------------------------------------------------------------- shared files

@contextmanager
def locked(out_dir):
    with open(out_dir / ".lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(lock, fcntl.LOCK_UN)


def load_csv(path):
    if not path.exists():
        return []
    with open(path, newline="") as f:
        rows = list(csv.DictReader(f))
    for r in rows:
        r.setdefault("mode", "2")  # rows written before modes were recorded
        if r.get("mode") in (None, ""):
            r["mode"] = "2"
    return rows


def write_csv(path, rows):
    keys = list(dict.fromkeys(k for r in rows for k in r))
    tmp = path.with_suffix(".tmp")
    with open(tmp, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=keys)
        w.writeheader()
        w.writerows(rows)
    tmp.replace(path)


def merge_rows(out_dir, name, drop, add):
    """Under the lock: remove rows matching drop(row), append add, rewrite the CSV."""
    path = out_dir / name
    with locked(out_dir):
        rows = [r for r in load_csv(path) if not drop(r)] + add
        write_csv(path, rows)


def update_json(out_dir, name, fn, default):
    path = out_dir / name
    with locked(out_dir):
        data = json.loads(path.read_text()) if path.exists() else default
        data = fn(data)
        path.write_text(json.dumps(data, indent=2))


# ---------------------------------------------------------------- Pact

def pact_one(pact_bin, case, mode, threads, rep, out_dir, timeout, mem):
    log = out_dir / "pact_logs" / f"{case.name}.m{mode}.j{threads}.r{rep}.log"
    cmd = capped([str(pact_bin), "-just-check", "-debug-choice", str(mode), "-j", str(threads), case.pact_type], mem)
    rc, wall = run_timed(cmd, COMPAT_DIR, log, timeout)
    text = log.read_text(errors="ignore")
    verdicts = re.findall(r"Compatibility: (true|false|error)\b", text)
    if rc is None:
        verdict = "timeout"
    elif rc != 0 or not verdicts or "error" in verdicts:
        verdict = "error"
    elif "false" in verdicts:
        verdict = "incompatible"
    else:
        verdict = "compatible"
    return {"case": case.name, "mode": str(mode), "threads": threads, "rep": rep, "verdict": verdict,
            "wall_s": f"{wall:.3f}", "timeout_s": int(timeout), "returncode": rc,
            "log": str(log.relative_to(out_dir))}


def pact_members(pact_bin, case, out_dir):
    """Untimed verbose run: pool size for the 'Part.' column (each paper file has one pool)."""
    log_dir = out_dir / "pact_logs" / f"{case.name}.verbose"
    log = out_dir / "pact_logs" / f"{case.name}.verbose.log"
    cmd = [str(pact_bin), "-just-check", "-verbose", "-log-dir", str(log_dir), "-debug-choice", "3", case.pact_type]
    members = []
    with open(log, "w") as f:
        proc = subprocess.Popen(cmd, cwd=COMPAT_DIR, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                text=True, start_new_session=True)
        for line in proc.stdout:
            f.write(line)
            m = re.search(r"\((\d+) members", line)
            if m:
                members.append(int(m.group(1)))
                break
        os.killpg(proc.pid, signal.SIGKILL)
        proc.wait()
    shutil.rmtree(log_dir, ignore_errors=True)
    return members


def pact_config(args, pact_bin, case, mode, threads, out_dir):
    """All repetitions of one (case, mode, threads) configuration, sequentially."""
    same = lambda r: r["case"] == case.name and r["mode"] == str(mode) and int(r["threads"]) == threads
    merge_rows(out_dir, "pact_runs.csv", same, [])
    for rep in range(1, args.reps + 1):
        row = pact_one(pact_bin, case, mode, threads, rep, out_dir, args.pact_timeout, args.pact_mem)
        merge_rows(out_dir, "pact_runs.csv", lambda r: False, [row])
        print(f"[pact] {case.name} mode {mode} -j {threads} rep {rep}: {row['verdict']} {row['wall_s']} s", flush=True)
        if row["verdict"] in ("timeout", "error") or float(row["wall_s"]) > args.rep_cutoff:
            break


def run_pact(args, cases, out_dir, pact_bin):
    (out_dir / "pact_logs").mkdir(parents=True, exist_ok=True)
    for case in cases:
        members = pact_members(pact_bin, case, out_dir)
        update_json(out_dir, "members.json", lambda d: {**d, case.name: members}, {})
    modes = [int(m) for m in args.modes.split(",")]
    threads = [int(t) for t in args.threads.split(",")]
    configs = [(c, m, j) for m in modes for c in cases for j in threads]
    with ThreadPoolExecutor(max_workers=max(1, args.pact_jobs)) as pool:
        for fut in as_completed([pool.submit(pact_config, args, pact_bin, c, m, j, out_dir) for c, m, j in configs]):
            fut.result()


# ---------------------------------------------------------------- SBY

def sby_variant(case, variant, define, out_dir, timeout):
    """Copy the case's .sby, adding the variant's define and an SBY timeout."""
    text = (ROOT / "formal" / "comm_safety" / case.sby).read_text()
    if define:
        text = re.sub(r"^(read_slang )", rf"\1-D {define} ", text, flags=re.MULTILINE)
    text = re.sub(r"^(\[options\]\n)", rf"\1timeout {int(timeout)}\n", text, flags=re.MULTILINE)
    path = out_dir / "sby" / f"{case.name}.{variant}.sby"
    path.write_text(text)
    return path


def sby_summary(workdir):
    log = workdir / "logfile.txt"
    text = log.read_text(errors="ignore") if log.exists() else ""
    status = (workdir / "status").read_text().split()[0] if (workdir / "status").exists() else ""
    summaries = re.findall(r"summary: (.*)", text)
    failed = re.findall(r"failed assertion (\S+)", text)
    base_depth = re.findall(r"basecase: .*Checking assertions in step (\d+)", text)
    ind_depth = re.findall(r"induction: .*Trying induction in step (\d+)", text)
    return {
        "sby_status": status,
        "basecase_depth": base_depth[-1] if base_depth else "",
        "induction_step": ind_depth[-1] if ind_depth else "",
        "failed_asserts": ";".join(sorted(set(failed))),
        "summary": " | ".join(summaries),
    }


def sv_one(case, variant, define, out_dir, timeout, mem):
    sby = sby_variant(case, variant, define, out_dir, timeout)
    workdir = out_dir / "sby" / f"{case.name}.{variant}"
    shutil.rmtree(workdir, ignore_errors=True)
    log = out_dir / "sby" / f"{case.name}.{variant}.log"
    # SBY enforces the timeout itself; the outer limit only catches a hang.
    rc, wall = run_timed(capped(["sby", "-f", "-d", str(workdir), str(sby)], mem), ROOT, log, timeout + 600)
    row = {"case": case.name, "variant": variant, "returncode": rc, "wall_s": f"{wall:.3f}", "timeout_s": int(timeout)}
    row.update(sby_summary(workdir))
    if rc is None:
        row["sby_status"] = "TIMEOUT"
    # Keep logs, status and traces; drop the copied sources and the solver model.
    shutil.rmtree(workdir / "src", ignore_errors=True)
    shutil.rmtree(workdir / "model", ignore_errors=True)
    return row


def run_sv(args, cases, out_dir):
    (out_dir / "sby").mkdir(parents=True, exist_ok=True)
    variants = [v for v in args.sv_variants.split(",") if v]
    jobs = [(c, v) for c in cases for v in variants]
    with ThreadPoolExecutor(max_workers=max(1, args.sv_jobs)) as pool:
        futures = [pool.submit(sv_one, c, v, SV_VARIANTS[v], out_dir, args.sv_timeout, args.sv_mem) for c, v in jobs]
        for fut in as_completed(futures):
            row = fut.result()
            key = (row["case"], row["variant"])
            merge_rows(out_dir, "sv_runs.csv", lambda r: (r["case"], r["variant"]) == key, [row])
            print(f"[sv] {row['case']} {row['variant']}: {row['sby_status']} {row['wall_s']} s", flush=True)


# ---------------------------------------------------------------- report

def summarize(cases, pact_rows, members, sv_rows):
    table = []
    for case in cases:
        entry = {"case": case.name, "label": case.label, "members": members.get(case.name)}
        configs = sorted({(r["mode"], int(r["threads"])) for r in pact_rows if r["case"] == case.name})
        for mode, j in configs:
            runs = [r for r in pact_rows if r["case"] == case.name and r["mode"] == mode and int(r["threads"]) == j]
            ok = [float(r["wall_s"]) for r in runs if r["verdict"] == "compatible"]
            entry[f"pact_m{mode}_j{j}"] = {
                "verdict": "compatible" if ok else runs[0]["verdict"],
                "median_s": statistics.median(ok) if ok else None,
                "runs_s": [float(r["wall_s"]) for r in runs],
                "timeout_s": runs[0].get("timeout_s"),
            }
        for r in sv_rows:
            if r["case"] == case.name:
                timed_out = r["sby_status"] == "TIMEOUT"
                entry[f"sv_{r['variant']}"] = {
                    "status": r["sby_status"],
                    "wall_s": float(r["timeout_s"]) if timed_out else float(r["wall_s"]),
                    "failed_asserts": r["failed_asserts"],
                }
        table.append(entry)
    return table


def fmt_s(v):
    if v is None:
        return "--"
    return f"{v:.2f}" if v < 1000 else f"{v:.0f}"


SV_WORDS = {"PASS": "proved", "FAIL": "counterexample", "UNKNOWN": "unproved", "TIMEOUT": "timeout", "ERROR": "error"}


def sv_word(entry):
    return SV_WORDS.get(entry["status"], entry["status"] or "error") if entry else "--"


def pact_cell(p):
    if not p:
        return "--"
    if p["median_s"] is not None:
        return fmt_s(p["median_s"])
    return p["verdict"]


def compat_table(table, expected, configs):
    exp_cases = expected.get("cases", {})
    head = ["Benchmark", "Part.", "Verdict"]
    for m, j in configs:
        head += [f"Mode {m}, {j} thr. (s)"]
    lines = ["| " + " | ".join(head) + " |", "|" + "---|" * len(head)]
    for e in table:
        x = exp_cases.get(e["case"], {})
        part = sum(e["members"]) if e.get("members") else None
        verdicts = {e[k]["verdict"] for k in e if k.startswith("pact_m")}
        got_verdict = "compatible" if verdicts == {"compatible"} else ",".join(sorted(verdicts)) or "--"
        row = [e["label"],
               f"{x.get('members', '--')} / {part if part is not None else '--'}",
               f"{x.get('verdict', '--')} / {got_verdict}"]
        for m, j in configs:
            key = f"m{m}_j{j}"
            exp_s = x.get("times_s", {}).get(key)
            row.append(f"{fmt_s(exp_s)} / {pact_cell(e.get(f'pact_{key}'))}")
        lines.append("| " + " | ".join(row) + " |")
    return "\n".join(lines)


def sv_table(table, expected):
    exp_cases = expected.get("cases", {})
    head = ["Benchmark", "Safety", "Live", "All assertions", "Time, all assertions (s)"]
    lines = ["| " + " | ".join(head) + " |", "|" + "---|" * len(head)]
    for e in table:
        if not any(k.startswith("sv_") for k in e):
            continue
        x = exp_cases.get(e["case"], {})
        row = [e["label"]]
        for v in ("safety", "live", "full"):
            xs = x.get(v)
            row.append(f"{SV_WORDS.get(xs['status'], xs['status']) if xs else '--'} / {sv_word(e.get(f'sv_{v}'))}")
        xf, gf = x.get("full"), e.get("sv_full")
        row.append(f"{fmt_s(xf['wall_s']) if xf else '--'} / {fmt_s(gf['wall_s']) if gf else '--'}")
        lines.append("| " + " | ".join(row) + " |")
    return "\n".join(lines)


def load_expected(name):
    path = EXPECTED_DIR / name
    return json.loads(path.read_text()) if path.exists() else {}


def write_expected(table, configs, env):
    """Store this directory's results as the expected values (maintainers only)."""
    EXPECTED_DIR.mkdir(exist_ok=True)
    compat = {"machine": f"{env.get('cpu', '')}, {env.get('cores', '')} cores",
              "compiler": env.get("revisions", {}).get("Pact", {}).get("commit", ""), "cases": {}}
    sv = {"machine": compat["machine"], "cases": {}}
    for e in table:
        times = {f"m{m}_j{j}": e[f"pact_m{m}_j{j}"]["median_s"] for m, j in configs if f"pact_m{m}_j{j}" in e}
        if times:
            verdicts = {e[f"pact_m{m}_j{j}"]["verdict"] for m, j in configs if f"pact_m{m}_j{j}" in e}
            compat["cases"][e["case"]] = {"members": sum(e["members"]) if e.get("members") else None,
                                          "verdict": verdicts.pop() if len(verdicts) == 1 else "mixed",
                                          "times_s": times}
        runs = {v: {"status": e[f"sv_{v}"]["status"], "wall_s": round(e[f"sv_{v}"]["wall_s"], 2)}
                for v in SV_VARIANTS if f"sv_{v}" in e}
        if runs:
            sv["cases"][e["case"]] = runs
    if compat["cases"]:
        (EXPECTED_DIR / "compat.json").write_text(json.dumps(compat, indent=2) + "\n")
    if sv["cases"]:
        (EXPECTED_DIR / "model_checking.json").write_text(json.dumps(sv, indent=2) + "\n")


def report(out_dir, write_exp=False):
    with locked(out_dir):
        pact_rows = load_csv(out_dir / "pact_runs.csv")
        sv_rows = load_csv(out_dir / "sv_runs.csv")
        members_path = out_dir / "members.json"
        members = json.loads(members_path.read_text()) if members_path.exists() else {}
        inv_path = out_dir / "invocations.json"
        env = (json.loads(inv_path.read_text()) or [{}])[-1] if inv_path.exists() else {}
    present = {r["case"] for r in pact_rows + sv_rows}
    table = summarize([c for c in CASES if c.name in present], pact_rows, members, sv_rows)
    configs = sorted({(r["mode"], int(r["threads"])) for r in pact_rows})
    (out_dir / "summary.json").write_text(json.dumps({"table": table}, indent=2))
    if write_exp:
        write_expected(table, configs, env)
    text = ["Each cell: expected / measured. Times are wall-clock seconds; expected times are from "
            "the machine named in expected/*.json."]
    if pact_rows:
        exp = load_expected("compat.json")
        text += ["", "## Pact compatibility checking", "", f"Expected values: {exp.get('machine', '--')}", "",
                 compat_table(table, exp, configs)]
    if sv_rows:
        exp = load_expected("model_checking.json")
        text += ["", "## SystemVerilog model checking (SymbiYosys)", "", f"Expected values: {exp.get('machine', '--')}", "",
                 sv_table(table, exp)]
    (out_dir / "comparison.md").write_text("\n".join(text) + "\n")
    return "\n".join(text)


def main():
    args = parse_args()
    if args.report_only:
        out_dir = Path(args.report_only).resolve()
        print(report(out_dir, args.write_expected))
        return
    cases = [c for c in CASES if not args.cases or c.name in args.cases]
    if not cases:
        sys.exit("no matching case")
    out_dir = Path(args.results_dir) if args.results_dir else \
        ROOT / "results" / datetime.now().strftime("timing_%Y%m%d_%H%M%S")
    out_dir = out_dir.resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    print(f"Results: {out_dir}", flush=True)

    pact_bin = None
    if args.part in ("pact", "all"):
        src = Path(args.pact) if args.pact else PACT_DIR / "_build" / "default" / "bin" / "main.exe"
        if not args.pact:
            subprocess.run(["dune", "build", "bin/main.exe"], cwd=PACT_DIR, check=True)
        pact_bin = out_dir / "pact"
        with locked(out_dir):
            # Several invocations may share the directory; copy only a changed binary.
            if not pact_bin.exists() or subprocess.run(["cmp", "-s", str(src), str(pact_bin)]).returncode != 0:
                pact_bin.unlink(missing_ok=True)
                shutil.copy2(src, pact_bin)
    if args.part in ("sv", "all") and not shutil.which("sby"):
        sys.exit("sby not on PATH")

    env = environment(pact_bin)
    # Pact first: its timings are short and sensitive to load from the SBY runs.
    if args.part in ("pact", "all"):
        run_pact(args, cases, out_dir, pact_bin)
    if args.part in ("sv", "all"):
        run_sv(args, cases, out_dir)

    env["loadavg_end"] = os.getloadavg()
    env["args"] = vars(args)
    update_json(out_dir, "invocations.json", lambda d: d + [env], [])
    print(report(out_dir, args.write_expected))
    print(f"\nWrote {out_dir / 'comparison.md'}")


if __name__ == "__main__":
    main()
