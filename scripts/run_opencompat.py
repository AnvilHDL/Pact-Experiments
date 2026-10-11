#!/usr/bin/env python3
"""Compatibility verdicts for the AXI communication-error cases (paper appendix, Table utility-cases).

Each case file in opencompat/ is checked with `pact -just-check -debug-choice 3`.
Every pool's verdict is compared with expected/opencompat.json.

Output directory (default results/opencompat_<time>/):
  comparison.md   expected / measured verdict for every pool
  logs/           compiler output per file

Examples:
  python3 scripts/run_opencompat.py
  python3 scripts/run_opencompat.py --case axi_demux
"""
import argparse
import json
import os
import re
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXPECTED = ROOT / "expected" / "opencompat.json"
PACT_DIR = Path(os.environ.get("PACT_DIR", ROOT.parent / "Pact")).resolve()
VERDICT_RE = re.compile(r"\[(?:PASS|FAIL)\] \[Simultaneous\] Pool (\S+) Compatibility: (true|false)")
WORDS = {"true": "compatible", "false": "incompatible"}


def parse_args():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--case", action="append", dest="cases", help="Run only this case (repeatable)")
    p.add_argument("--results-dir", help="Output directory (default: new timestamped directory)")
    p.add_argument("--pact", help="Pact binary (default: $PACT_DIR/_build/default/bin/main.exe)")
    p.add_argument("-j", "--threads", type=int, default=4, help="Threads per check (default 4)")
    p.add_argument("--timeout", type=float, default=3600.0, help="Seconds per file (default 3600)")
    return p.parse_args()


def main():
    args = parse_args()
    expected = json.loads(EXPECTED.read_text())["cases"]
    cases = {k: v for k, v in expected.items() if not args.cases or k in args.cases}
    if not cases:
        sys.exit(f"no such case; choose from {', '.join(expected)}")
    pact = Path(args.pact) if args.pact else PACT_DIR / "_build" / "default" / "bin" / "main.exe"
    if not args.pact:
        subprocess.run(["dune", "build", "--root", str(PACT_DIR), "bin/main.exe"], check=True)
    out_dir = Path(args.results_dir) if args.results_dir else \
        ROOT / "results" / datetime.now().strftime("opencompat_%Y%m%d_%H%M%S")
    (out_dir / "logs").mkdir(parents=True, exist_ok=True)

    rows, ok = [], True
    for name, case in cases.items():
        for rel, pools in case["files"].items():
            path = ROOT / "opencompat" / rel
            print(f"[{name}] {rel}", flush=True)
            start = time.monotonic()
            try:
                run = subprocess.run([str(pact), "-just-check", "-debug-choice", "3", "-j", str(args.threads), path.name],
                                     cwd=path.parent, capture_output=True, text=True, timeout=args.timeout)
                output = run.stdout + run.stderr
            except subprocess.TimeoutExpired as e:
                output = (e.stdout or b"").decode() + (e.stderr or b"").decode() + "\ntimeout\n"
            secs = time.monotonic() - start
            (out_dir / "logs" / (path.stem + ".log")).write_text(output)
            measured = {p: WORDS[v] for p, v in VERDICT_RE.findall(output)}
            for pool, want in pools.items():
                got = measured.get(pool, "no verdict")
                ok &= got == want
                rows.append((case["label"], case["setting"], rel, pool, want, got, secs))
                print(f"  {pool}: expected {want}, measured {got}", flush=True)

    lines = ["| Case | Setting | File | Pool | Verdict (expected / measured) | File time (s) |",
             "| --- | --- | --- | --- | --- | ---: |"]
    for label, setting, rel, pool, want, got, secs in rows:
        mark = "" if want == got else " **mismatch**"
        lines.append(f"| {label} | {setting} | `{rel}` | `{pool}` | {want} / {got}{mark} | {secs:.1f} |")
    (out_dir / "comparison.md").write_text("\n".join(lines) + "\n")
    print(f"\nWrote {out_dir / 'comparison.md'}")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
