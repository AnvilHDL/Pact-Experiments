#!/usr/bin/env python3
"""Lines-of-code and assertion/signature-size comparison for each case.

Anvil side: lines of code of the full test_<case>.anvil implementation, plus
the character/line length of its interface(...) = <session type> declaration
(the closest Anvil analog to a type signature).

SV side: lines of code of the DUT file only (src/testbenches/, not the
submodule copies under axi/src etc. - per instruction, prefer the tracked
non-submodule variant), plus the size of the comm-safety formal wrapper/
assertion block for that case (module comm_<case>_formal ... endmodule in
formal/comm_safety/sv/{comm_safety_common,comm_safety_tb_wrappers}.sv) -
line count and assert/assume count. No SV "type signature" is collected
(SV has no session-type equivalent).
"""
import argparse
import csv
import re
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COMPAT_DIR = ROOT / "src" / "compat"
TESTBENCH_DIR = ROOT / "src" / "testbenches"
HARNESS_FILES = [
    ROOT / "formal" / "comm_safety" / "sv" / "comm_safety_common.sv",
    ROOT / "formal" / "comm_safety" / "sv" / "comm_safety_tb_wrappers.sv",
]
DEFAULT_RESULTS_BASE = ROOT / "formal" / "comm_safety" / "results"


@dataclass(frozen=True)
class Case:
    name: str
    anvil_test: str
    anvil_type_file: str  # interface(s) live in type_*.anvil, not test_*.anvil
    anvil_interfaces: tuple  # DUT's own interface name(s), not driver/master/slave
    sv_dut: str
    harness_module: str


CASES = [
    Case("fifo", "test_fifo.anvil", "type_fifo.anvil", ("fifo_itfc",), "fifo_test.sv", "comm_fifo_formal"),
    Case("spill_register", "test_spill_reg.anvil", "type_spill_reg.anvil", ("spill_register_itfc",), "spill_register_test.sv", "comm_spill_formal"),
    Case("stream_fifo", "test_stream_fifo.anvil", "type_stream_fifo.anvil", ("stream_fifo_if",), "stream_fifo_test.sv", "comm_stream_fifo_formal"),
    Case("arbiter", "test_arbiter.anvil", "type_arbiter.anvil", ("rr_arbiter_itfc",), "arbiter_test.sv", "comm_arbiter_formal"),
    Case("axi_demux_read", "test_demux_read.anvil", "type_demux_read.anvil", ("demux_ar_main", "demux_r_main"), "axi_lite_demux_read.sv", "comm_axi_demux_read_formal"),
    Case("axi_demux_write", "test_demux_write.anvil", "type_demux_write.anvil", ("demux_aw_main", "demux_w_main", "demux_b_main"), "axi_lite_demux_write.sv", "comm_axi_demux_write_formal"),
    Case("axi_mux_read", "test_mux_read.anvil", "type_mux_read_simplified.anvil", ("r_rr_arbiter_itfc",), "axi_lite_mux_read.sv", "comm_axi_mux_read_formal"),
    Case("axi_mux_write", "test_mux_write.anvil", "type_mux_4p_write.anvil", ("w_rr_arbiter_itfc",), "axi_lite_mux_write.sv", "comm_axi_mux_write_formal"),
    Case("ace", "test_ace.anvil", "type_ace.anvil", ("ace_itfc",), "ccu_fsm_tb.sv", "comm_ace_formal"),
    Case("tilelink", "test_tilelink.anvil", "type_tilelink.anvil", ("crossbar_itfc_A", "crossbar_itfc_D"), "TLCrossBar_test.sv", "comm_tilelink_formal"),
]


def count_lines(path):
    if not path.exists():
        return None
    text = path.read_text(errors="ignore")
    return len(text.splitlines())


def find_interface_span(anvil_path, interface_name):
    """Best-effort: the `interface <name>(...) = <session type>` declaration,
    from its own line up to (but not including) the next top-level
    interface/proc/chan/pool/import/type/struct declaration or EOF."""
    if not anvil_path.exists():
        return None
    text = anvil_path.read_text(errors="ignore")
    lines = text.splitlines()
    start = None
    for i, line in enumerate(lines):
        if re.match(rf"^\s*interface\s+{re.escape(interface_name)}\b", line):
            start = i
            break
    if start is None:
        return None
    end = len(lines)
    for i in range(start + 1, len(lines)):
        if re.match(r"^\s*(interface|proc|chan|pool|import|type|struct)\b", lines[i]):
            end = i
            break
    span = lines[start:end]
    while span and not span[-1].strip():
        span.pop()
    return {
        "lines": len(span),
        "chars": sum(len(l) for l in span),
    }


def find_harness_module(module_name):
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
        return {
            "lines": len(body.splitlines()),
            "asserts": len(re.findall(r"\bassert\s*\(", active_body)),
            "assumes": len(re.findall(r"\bassume\s*\(", active_body)),
        }
    return None


def parse_args():
    parser = argparse.ArgumentParser(description="Lines-of-code / assertion / signature-size comparison.")
    parser.add_argument("--case", dest="case_names", action="append", help="Run one named case; repeatable")
    parser.add_argument(
        "--csv",
        default=None,
        help=f"Default: code_size.csv in a new timestamped directory under "
        f"{DEFAULT_RESULTS_BASE.relative_to(ROOT)}/ (never overwrites a previous run's results)",
    )
    return parser.parse_args()


def selected_cases(names):
    if not names:
        return CASES
    wanted = set(names)
    return [case for case in CASES if case.name in wanted]


def main():
    args = parse_args()
    if args.csv is None:
        csv_path = DEFAULT_RESULTS_BASE / datetime.now().strftime("%Y%m%d_%H%M%S") / "code_size.csv"
    else:
        csv_path = Path(args.csv)
        if not csv_path.is_absolute():
            csv_path = ROOT / csv_path
    csv_path.parent.mkdir(parents=True, exist_ok=True)
    print(f"Results directory: {csv_path.parent.relative_to(ROOT)}", flush=True)

    rows = []
    for case in selected_cases(args.case_names):
        anvil_path = COMPAT_DIR / case.anvil_test
        type_path = COMPAT_DIR / case.anvil_type_file
        sv_path = TESTBENCH_DIR / case.sv_dut

        anvil_loc = count_lines(anvil_path)
        sv_loc = count_lines(sv_path)

        iface_lines = 0
        iface_chars = 0
        iface_found = []
        for iface_name in case.anvil_interfaces:
            span = find_interface_span(type_path, iface_name)
            if span:
                iface_lines += span["lines"]
                iface_chars += span["chars"]
                iface_found.append(iface_name)

        harness = find_harness_module(case.harness_module)

        row = {
            "case": case.name,
            "anvil_file": str(anvil_path.relative_to(ROOT)) if anvil_path.exists() else f"MISSING:{case.anvil_test}",
            "anvil_loc": anvil_loc if anvil_loc is not None else "",
            "anvil_type_file": str(type_path.relative_to(ROOT)) if type_path.exists() else f"MISSING:{case.anvil_type_file}",
            "anvil_interfaces": ",".join(case.anvil_interfaces),
            "anvil_interfaces_found": ",".join(iface_found),
            "anvil_interface_lines": iface_lines if iface_found else "",
            "anvil_interface_chars": iface_chars if iface_found else "",
            "sv_file": str(sv_path.relative_to(ROOT)) if sv_path.exists() else f"MISSING:{case.sv_dut}",
            "sv_loc": sv_loc if sv_loc is not None else "",
            "sv_harness_module": case.harness_module,
            "sv_harness_lines": harness["lines"] if harness else "",
            "sv_harness_asserts": harness["asserts"] if harness else "",
            "sv_harness_assumes": harness["assumes"] if harness else "",
        }
        rows.append(row)
        print(
            f"[{case.name}] anvil_loc={row['anvil_loc']} iface_lines={row['anvil_interface_lines']} "
            f"sv_loc={row['sv_loc']} harness_lines={row['sv_harness_lines']} "
            f"asserts={row['sv_harness_asserts']} assumes={row['sv_harness_assumes']}"
        )

    fieldnames = [
        "case",
        "anvil_file", "anvil_loc", "anvil_type_file", "anvil_interfaces", "anvil_interfaces_found",
        "anvil_interface_lines", "anvil_interface_chars",
        "sv_file", "sv_loc", "sv_harness_module", "sv_harness_lines", "sv_harness_asserts", "sv_harness_assumes",
    ]
    with csv_path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
    print(f"Wrote {csv_path.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
