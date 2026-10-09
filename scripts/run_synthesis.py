#!/usr/bin/env python3
"""Area and timing of Pact and SystemVerilog designs for the ten benchmarks.

Steps:
  1. collect_yosys_perf.py: compile each Pact benchmark at -O 3 and collect the design modules
     and the SystemVerilog reference design.
  2. collect_real_synth_perf.py: map both to sky130_fd_sc_hd cells (tt_025C_1v80) with Yosys,
     report cell area, and run OpenSTA at a 10 ns clock.

Output directory (default results/synthesis_<time>/):
  comparison.md   expected / measured values for every benchmark
  yosys/          step 1 output (generated SystemVerilog, generic synthesis)
  cells/          step 2 output (netlists, Yosys and OpenSTA logs, summary.csv)

Examples:
  python3 scripts/run_synthesis.py
  python3 scripts/run_synthesis.py --case fifo --case ace
  python3 scripts/run_synthesis.py --report-only results/synthesis_<time>
"""
import argparse
import csv
import json
import math
import subprocess
import sys
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXPECTED = ROOT / "expected" / "synthesis.json"
LABELS = {
    "fifo": "FIFO", "stream_fifo": "Stream FIFO", "spill_register": "Spill reg.", "arbiter": "Arbiter",
    "ace": "ACE", "tilelink": "TileLink", "axi_demux_read": "AXI demux R", "axi_demux_write": "AXI demux W",
    "axi_mux_read": "AXI mux R", "axi_mux_write": "AXI mux W",
}


def parse_args():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--case", action="append", dest="cases", help="Run only this case (repeatable)")
    p.add_argument("--results-dir", help="Output directory inside the repository (default: results/synthesis_<time>)")
    p.add_argument("--report-only", metavar="DIR", help="Only rebuild comparison.md for an existing results directory")
    p.add_argument("--write-expected", action="store_true", help="Store the results as expected/synthesis.json (maintainers)")
    p.add_argument("--podman-bin", help="Passed to collect_real_synth_perf.py when OpenSTA runs in a container")
    return p.parse_args()


def run(cmd):
    print("$ " + " ".join(cmd), flush=True)
    subprocess.run(cmd, cwd=ROOT, check=True)


def measured(out_dir):
    rows = list(csv.DictReader(open(out_dir / "cells" / "summary.csv")))
    agg = {(r["case"], r["variant"]): r for r in rows if r["row_type"] == "aggregate"}
    result = {}
    for case in LABELS:
        p, s = agg.get((case, "pact")), agg.get((case, "sv"))
        if not p or not s:
            continue
        ok = p["status"] == "PASS" and s["status"] == "PASS"
        result[case] = {
            "pact_um2": round(float(p["area_um2"]), 1) if p["area_um2"] else None,
            "sv_um2": round(float(s["area_um2"]), 1) if s["area_um2"] else None,
            "pact_seq": int(float(p["seq_cells"])) if p["seq_cells"] else None,
            "sv_seq": int(float(s["seq_cells"])) if s["seq_cells"] else None,
            "pact_slack_ns": float(p["worst_slack_setup_ns"]) if p["worst_slack_setup_ns"] else None,
            "sv_slack_ns": float(s["worst_slack_setup_ns"]) if s["worst_slack_setup_ns"] else None,
            "status": "PASS" if ok else f"pact={p['status']};sv={s['status']}",
        }
    return result


def ratio(c):
    return c["pact_um2"] / c["sv_um2"] if c and c.get("pact_um2") and c.get("sv_um2") else None


def f(v, fmt):
    return "--" if v is None else format(v, fmt)


def meets(c):
    if not c or c.get("pact_slack_ns") is None:
        return "--"
    return "yes" if c["pact_slack_ns"] >= 0 and (c.get("sv_slack_ns") or 0) >= 0 else "no"


def report(out_dir, write_exp):
    got = measured(out_dir)
    if write_exp:
        EXPECTED.parent.mkdir(exist_ok=True)
        EXPECTED.write_text(json.dumps({"flow": "Pact -O 3; Yosys + yosys-slang; sky130_fd_sc_hd__tt_025C_1v80; OpenSTA, 10 ns clock",
                                        "cases": got}, indent=2) + "\n")
    exp = json.loads(EXPECTED.read_text())["cases"] if EXPECTED.exists() else {}
    head = ["Benchmark", "Pact area (µm²)", "SV area (µm²)", "Pact/SV", "Pact FFs", "SV FFs", "Pact setup slack (ns)", "Meets 100 MHz"]
    lines = ["Each cell: expected / measured.", "",
             "| " + " | ".join(head) + " |", "|" + "---|" * len(head)]
    for case, label in LABELS.items():
        if case not in got:
            continue
        x, g = exp.get(case), got[case]
        row = [label,
               f"{f(x and x['pact_um2'], ',.0f')} / {f(g['pact_um2'], ',.0f')}",
               f"{f(x and x['sv_um2'], ',.0f')} / {f(g['sv_um2'], ',.0f')}",
               f"{f(ratio(x), '.2f')} / {f(ratio(g), '.2f')}",
               f"{f(x and x['pact_seq'], 'd')} / {f(g['pact_seq'], 'd')}",
               f"{f(x and x['sv_seq'], 'd')} / {f(g['sv_seq'], 'd')}",
               f"{f(x and x['pact_slack_ns'], '.2f')} / {f(g['pact_slack_ns'], '.2f')}",
               f"{meets(x)} / {meets(g)}"]
        if g["status"] != "PASS":
            row[0] += f" ({g['status']})"
        lines.append("| " + " | ".join(row) + " |")
    means = []
    for cases in (exp, got):
        rs = [ratio(c) for k, c in cases.items() if k in got and ratio(c)]
        means.append(f"{math.exp(sum(map(math.log, rs)) / len(rs)):.2f}" if rs else "--")
    lines.append(f"\nGeometric mean Pact/SV area ratio: {means[0]} / {means[1]}")
    text = "\n".join(lines) + "\n"
    (out_dir / "comparison.md").write_text(text)
    return text


def main():
    args = parse_args()
    if args.report_only:
        print(report(Path(args.report_only).resolve(), args.write_expected))
        return
    out_dir = Path(args.results_dir) if args.results_dir else ROOT / "results" / datetime.now().strftime("synthesis_%Y%m%d_%H%M%S")
    out_dir = (out_dir if out_dir.is_absolute() else ROOT / out_dir).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    case_args = [a for c in (args.cases or []) for a in ("--case", c)]
    run([sys.executable, "scripts/collect_yosys_perf.py", "--phase", "all", "--results-dir", str(out_dir / "yosys"), *case_args])
    cells = [sys.executable, "scripts/collect_real_synth_perf.py", "--generated-dir", str(out_dir / "yosys" / "generated"),
             "--results-dir", str(out_dir / "cells"), *case_args]
    if args.podman_bin:
        cells += ["--podman-bin", args.podman_bin, "--sta-bin", ""]
    run(cells)
    print(report(out_dir, args.write_expected))
    print(f"Wrote {out_dir / 'comparison.md'}")


if __name__ == "__main__":
    main()
