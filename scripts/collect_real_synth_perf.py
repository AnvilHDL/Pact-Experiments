#!/usr/bin/env python3
"""Real standard-cell synthesis + timing/power collection, layered on top of
collect_yosys_perf.py's output.

Where collect_yosys_perf.py maps to Yosys's generic internal cells ($_DFF_*,
$_MUX_*, ...) - a proxy for relative size only, with no real area/timing/power
meaning - this script re-synthesizes the SAME already-generated/sanitized SV
(from synthesis_reports/yosys_perf_results/generated/<case>/) against a real
sky130 standard-cell Liberty file (via Yosys's dfflibmap + abc -liberty), then
runs OpenSTA (via podman, openroad/opensta image) against the resulting
gate-level netlist for real worst-case timing slack and Liberty-based power.

Prerequisites (see pact.md and the OVERHEAD_FINDINGS.md tooling note):
  - `pip install --user volare && volare enable --pdk sky130 <version>`
  - `podman pull docker.io/openroad/opensta:latest`
  - collect_yosys_perf.py must have already been run for the cases in
    question, so generated/<case>/anvil.yosys.sv and the SV sources exist.

This intentionally reuses collect_yosys_perf.py's manifest and its already-
sanitized generated SV rather than re-deriving anvil codegen or module
discovery - it only adds a second synthesis target (real cells instead of
generic) and a real STA/power step on top.
"""
import argparse
import csv
import json
import re
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / "scripts" / "yosys_perf_manifest.json"
DEFAULT_RESULTS = ROOT / "synthesis_reports" / "real_synth_perf_results"
DEFAULT_GENERATED = ROOT / "synthesis_reports" / "yosys_perf_results" / "generated"
DEFAULT_PDK_LIB = Path(
    "/home/aditya/.volare/volare/sky130/versions/"
    "c6d73a35f524070e85faff4a6a9eef49553ebc2b/sky130A/libs.ref/sky130_fd_sc_hd/lib/"
    "sky130_fd_sc_hd__tt_025C_1v80.lib"
)
DEFAULT_STA_IMAGE = "docker.io/openroad/opensta:latest"
DEFAULT_CLOCK_PERIOD_NS = 10.0

SUM_FIELDS = ["total_cells", "seq_cells", "comb_cells", "area_um2", "internal_power_w", "switching_power_w", "leakage_power_w", "total_power_w"]
MIN_FIELDS = ["worst_slack_setup_ns", "worst_slack_hold_ns"]
RATIO_FIELDS = [f"{field}_ratio" for field in (SUM_FIELDS + MIN_FIELDS)]

CSV_FIELDS = [
    "case",
    "row_type",
    "variant",
    "module",
    "status",
    "status_detail",
    "total_cells",
    "seq_cells",
    "comb_cells",
    "area_um2",
    "seq_area_um2",
    "clock_period_ns",
    "worst_slack_setup_ns",
    "worst_slack_hold_ns",
    "tns_setup_ns",
    "internal_power_w",
    "switching_power_w",
    "leakage_power_w",
    "total_power_w",
    *RATIO_FIELDS,
]


@dataclass(frozen=True)
class RunConfig:
    case_names: set[str] | None
    variant: str
    results_dir: Path
    manifest_path: Path
    generated_dir: Path
    pdk_lib: Path
    sta_image: str
    clock_period_ns: float
    timeout_seconds: int
    podman_bin: str


def parse_args() -> RunConfig:
    parser = argparse.ArgumentParser(
        description="Real sky130-cell synthesis + OpenSTA timing/power, layered on collect_yosys_perf.py output."
    )
    parser.add_argument("--case", dest="case_names", action="append", help="Run one named case; repeatable")
    parser.add_argument("--variant", choices=["anvil", "sv", "both"], default="both")
    parser.add_argument("--results-dir", default=str(DEFAULT_RESULTS))
    parser.add_argument("--manifest", default=str(DEFAULT_MANIFEST))
    parser.add_argument("--generated-dir", default=str(DEFAULT_GENERATED))
    parser.add_argument("--pdk-lib", default=str(DEFAULT_PDK_LIB))
    parser.add_argument("--sta-image", default=DEFAULT_STA_IMAGE)
    parser.add_argument("--clock-period-ns", type=float, default=DEFAULT_CLOCK_PERIOD_NS)
    parser.add_argument("--timeout-seconds", type=int, default=180)
    parser.add_argument("--podman-bin", default="podman")
    args = parser.parse_args()

    results_dir = Path(args.results_dir)
    if not results_dir.is_absolute():
        results_dir = ROOT / results_dir
    manifest_path = Path(args.manifest)
    if not manifest_path.is_absolute():
        manifest_path = ROOT / manifest_path
    generated_dir = Path(args.generated_dir)
    if not generated_dir.is_absolute():
        generated_dir = ROOT / generated_dir

    return RunConfig(
        case_names=set(args.case_names) if args.case_names else None,
        variant=args.variant,
        results_dir=results_dir,
        manifest_path=manifest_path,
        generated_dir=generated_dir,
        pdk_lib=Path(args.pdk_lib),
        sta_image=args.sta_image,
        clock_period_ns=args.clock_period_ns,
        timeout_seconds=args.timeout_seconds,
        podman_bin=args.podman_bin,
    )


def rel(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


def load_manifest(path: Path) -> tuple[dict, list[dict]]:
    with path.open() as manifest_file:
        manifest = json.load(manifest_file)
    return manifest.get("defaults", {}), manifest.get("cases", [])


def discover_modules(sv_path: Path) -> list[str]:
    module_re = re.compile(r"^\s*module\s+([A-Za-z_][A-Za-z0-9_$]*)\b")
    modules = []
    with sv_path.open(errors="ignore") as sv_file:
        for line in sv_file:
            match = module_re.match(line)
            if match:
                modules.append(match.group(1))
    return modules


def extract_module_text(sv_path: Path, module_name: str) -> str | None:
    """Isolate module_name's own module...endmodule text - see the identical
    helper (and full rationale) in collect_yosys_perf.py: read_slang's --top
    restricts elaboration but not whole-file semantic checking, so an
    unrelated, unreachable module elsewhere in the same single-unit file can
    still break synthesis of the requested top."""
    text = sv_path.read_text(errors="ignore")
    match = re.search(rf"^module\s+{re.escape(module_name)}\b", text, re.MULTILINE)
    if match is None:
        return None
    start = match.start()
    end = text.find("\nendmodule", start)
    if end == -1:
        return None
    end += len("\nendmodule")
    return text[start:end] + "\n"


def matches_any(name: str, patterns: list[str]) -> bool:
    return any(re.search(pattern, name) for pattern in patterns)


def run_logged(command: list[str], log_path: Path, cwd: Path = ROOT, timeout_seconds: int = 180) -> tuple[int, str]:
    log_path.parent.mkdir(parents=True, exist_ok=True)
    try:
        proc = subprocess.run(
            command, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
            check=False, timeout=timeout_seconds or None,
        )
        returncode, output = proc.returncode, proc.stdout
    except subprocess.TimeoutExpired as err:
        returncode = -124
        output = (err.stdout or "") + f"\n# timeout_seconds: {timeout_seconds}\n"
    with log_path.open("w") as log_file:
        log_file.write("$ " + " ".join(command) + "\n")
        log_file.write(output)
        log_file.write(f"\n# returncode: {returncode}\n")
    return returncode, output


def synth_to_real_cells(
    top: str, files: list[Path], defines: list[str], include_dirs: list[Path],
    pdk_lib: Path, out_v: Path, log_path: Path, timeout_seconds: int,
) -> tuple[int, str]:
    define_args = " ".join(f"-D {d}" for d in defines)
    include_args = " ".join(f"-I{d.resolve()}" for d in include_dirs)
    file_args = " ".join(str(f.resolve()) for f in files)
    script = "\n".join([
        f"read_slang --single-unit --top {top} {define_args} {include_args} {file_args}",
        f"synth -top {top} -flatten",
        f"dfflibmap -liberty {pdk_lib.resolve()}",
        f"abc -liberty {pdk_lib.resolve()}",
        "opt_clean -purge",
        f"stat -liberty {pdk_lib.resolve()} -json",
        f"write_verilog {out_v.resolve()}",
    ])
    return run_logged(["yosys", "-m", "slang", "-p", script], log_path, timeout_seconds=timeout_seconds)


def extract_stat_json(output: str) -> dict | None:
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


def find_module_stat(stat_json: dict, top: str) -> dict | None:
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


def real_seq_cell_names(synth_output: str) -> set[str]:
    """Real (Liberty) cell names that Yosys's dfflibmap mapped a generic
    $_DFF_*/$_DFFE_*/... cell onto, e.g. "mapped 36 $_DFF_PN0_ cells to
    \\sky130_fd_sc_hd__dfrtp_1 cells." Parsed straight from dfflibmap's own
    report instead of guessing at a target library's flip-flop naming
    convention (sky130 uses "df*" for flip-flops, not "dff", so the generic-
    cell script's substring-token matcher doesn't transfer to real libraries -
    this asks Yosys directly instead)."""
    return {name.lstrip("\\") for name in re.findall(r"mapped \d+ \$_[A-Z]+\S* cells to (\S+) cells", synth_output)}


def count_sequential_cells(cell_hist: dict[str, int], seq_cell_names: set[str]) -> int:
    return sum(int(count) for cell_type, count in cell_hist.items() if cell_type.lstrip("\\") in seq_cell_names)


def metrics_from_stat(stat_json: dict, top: str, seq_cell_names: set[str]) -> dict:
    module_stat = find_module_stat(stat_json, top)
    if module_stat is None:
        raise ValueError(f"stat JSON does not contain top module {top}")
    cell_hist = {str(k): int(v) for k, v in module_stat.get("num_cells_by_type", {}).items()}
    total_cells = int(module_stat.get("num_cells", sum(cell_hist.values())))
    seq_cells = count_sequential_cells(cell_hist, seq_cell_names)
    area_um2 = float(module_stat.get("area", 0.0))
    return {
        "total_cells": total_cells,
        "seq_cells": seq_cells,
        "comb_cells": max(total_cells - seq_cells, 0),
        "area_um2": area_um2,
        "cell_hist": cell_hist,
    }


def write_sdc(sdc_path: Path, clock_port: str, period_ns: float) -> None:
    sdc_path.parent.mkdir(parents=True, exist_ok=True)
    sdc_path.write_text(
        f"create_clock -name {clock_port} -period {period_ns} [get_ports {clock_port}]\n"
        f"set_input_delay -clock {clock_port} 1 [all_inputs]\n"
        f"set_output_delay -clock {clock_port} 1 [all_outputs]\n"
    )


def run_sta(
    config: RunConfig, netlist_v: Path, top: str, clock_port: str, sdc_path: Path,
    tcl_path: Path, log_path: Path,
) -> dict:
    tcl_path.parent.mkdir(parents=True, exist_ok=True)
    tcl_path.write_text("\n".join([
        f"read_liberty /pdk/{config.pdk_lib.name}",
        f"read_verilog /work/{netlist_v.name}",
        f"link_design {top}",
        f"read_sdc /work/{sdc_path.name}",
        "puts \"=== WORST_SLACK_SETUP ===\"",
        "report_worst_slack -max",
        "puts \"=== WORST_SLACK_HOLD ===\"",
        "report_worst_slack -min",
        "puts \"=== TNS ===\"",
        "report_tns",
        "puts \"=== POWER ===\"",
        "report_power",
        "",
    ]))
    work_dir = netlist_v.parent
    command = [
        config.podman_bin, "run", "--rm",
        "-v", f"{config.pdk_lib.parent}:/pdk:ro",
        "-v", f"{work_dir}:/work:ro",
        config.sta_image,
        f"/work/{tcl_path.name}",
    ]
    rc, output = run_logged(command, log_path, timeout_seconds=config.timeout_seconds)
    result = {"status": "PASS" if rc == 0 else f"STA_FAIL({rc})"}
    if rc != 0:
        return result

    def grab_float(pattern: str) -> float | None:
        m = re.search(pattern, output)
        return float(m.group(1)) if m else None

    result["worst_slack_setup_ns"] = grab_float(r"worst slack max\s+(-?[\d.]+)")
    result["worst_slack_hold_ns"] = grab_float(r"worst slack min\s+(-?[\d.]+)")
    result["tns_setup_ns"] = grab_float(r"tns max\s+(-?[\d.]+)")

    total_line = re.search(
        r"^Total\s+([\d.eE+-]+)\s+([\d.eE+-]+)\s+([\d.eE+-]+)\s+([\d.eE+-]+)",
        output, re.MULTILINE,
    )
    if total_line:
        result["internal_power_w"] = float(total_line.group(1))
        result["switching_power_w"] = float(total_line.group(2))
        result["leakage_power_w"] = float(total_line.group(3))
        result["total_power_w"] = float(total_line.group(4))
    return result


def process_module(
    config: RunConfig, case_name: str, variant: str, top: str, files: list[Path],
    defines: list[str], include_dirs: list[Path], clock_port: str,
) -> dict:
    mod_dir = config.results_dir / case_name / variant
    mod_dir.mkdir(parents=True, exist_ok=True)
    netlist_v = mod_dir / f"{top}.sky130.v"
    synth_log = mod_dir / f"{top}.synth.log"
    row = {field: "" for field in CSV_FIELDS}
    row.update(case=case_name, row_type="module", variant=variant, module=top)

    rc, output = synth_to_real_cells(top, files, defines, include_dirs, config.pdk_lib, netlist_v, synth_log, config.timeout_seconds)
    if rc != 0:
        row["status"] = f"SYNTH_FAIL({rc})"
        row["status_detail"] = f"see {rel(synth_log)}"
        return row

    stat_json = extract_stat_json(output)
    if stat_json is None:
        row["status"] = "STAT_PARSE_FAIL"
        return row
    seq_cell_names = real_seq_cell_names(output)
    try:
        metrics = metrics_from_stat(stat_json, top, seq_cell_names)
    except ValueError as err:
        row["status"] = "STAT_PARSE_FAIL"
        row["status_detail"] = str(err)
        return row
    row.update(total_cells=metrics["total_cells"], seq_cells=metrics["seq_cells"], comb_cells=metrics["comb_cells"], area_um2=metrics["area_um2"])

    sdc_path = mod_dir / f"{top}.sdc"
    write_sdc(sdc_path, clock_port, config.clock_period_ns)
    tcl_path = mod_dir / f"{top}.sta.tcl"
    sta_log = mod_dir / f"{top}.sta.log"
    sta_result = run_sta(config, netlist_v, top, clock_port, sdc_path, tcl_path, sta_log)
    if sta_result["status"] != "PASS":
        row["status"] = sta_result["status"]
        row["status_detail"] = f"see {rel(sta_log)}"
        return row

    row["status"] = "PASS"
    row["clock_period_ns"] = config.clock_period_ns
    for key in ("worst_slack_setup_ns", "worst_slack_hold_ns", "tns_setup_ns", "internal_power_w", "switching_power_w", "leakage_power_w", "total_power_w"):
        if sta_result.get(key) is not None:
            row[key] = sta_result[key]
    return row


def rows_for_anvil_case(config: RunConfig, case: dict, defaults: dict) -> list[dict]:
    case_name = case["name"]
    anvil_sv = config.generated_dir / case_name / "anvil.yosys.sv"
    if not anvil_sv.exists():
        return [{**{f: "" for f in CSV_FIELDS}, "case": case_name, "row_type": "module", "variant": "anvil", "module": "aggregate", "status": "MISSING_GENERATED_SV", "status_detail": f"run collect_yosys_perf.py --case {case_name} --variant anvil first"}]

    modules = discover_modules(anvil_sv)
    core_patterns = case.get("anvil_core_patterns", [])
    selected = [m for m in modules if matches_any(m, core_patterns)]
    include_dirs = [ROOT / d for d in defaults.get("include_dirs", [])]
    defines = defaults.get("defines", [])

    isolated_dir = config.results_dir / case_name / "anvil_isolated"
    rows = []
    for module in selected:
        module_text = extract_module_text(anvil_sv, module)
        if module_text is None:
            files = [anvil_sv]
        else:
            isolated_dir.mkdir(parents=True, exist_ok=True)
            isolated_path = isolated_dir / f"{module}.sv"
            isolated_path.write_text(module_text)
            files = [isolated_path]
        rows.append(process_module(config, case_name, "anvil", module, files, defines, include_dirs, "clk_i"))
    return rows


def rows_for_sv_case(config: RunConfig, case: dict, defaults: dict) -> list[dict]:
    case_name = case["name"]
    files = [ROOT / p for p in case.get("sv_files", [])]
    missing = [f for f in files if not f.exists()]
    if missing:
        return [{**{f: "" for f in CSV_FIELDS}, "case": case_name, "row_type": "module", "variant": "sv", "module": case["sv_top"], "status": "MISSING_SV_FILES", "status_detail": ",".join(rel(m) for m in missing)}]
    include_dirs = [ROOT / d for d in defaults.get("include_dirs", [])]
    defines = defaults.get("defines", [])
    return [process_module(config, case_name, "sv", case["sv_top"], files, defines, include_dirs, "clk_i")]


def base_row(case_name: str, row_type: str, variant: str, module: str) -> dict:
    row = {field: "" for field in CSV_FIELDS}
    row.update(case=case_name, row_type=row_type, variant=variant, module=module)
    return row


def aggregate_row(case_name: str, variant: str, module_rows: list[dict]) -> dict:
    aggregate = base_row(case_name, "aggregate", variant, "aggregate")
    pass_rows = [r for r in module_rows if r["status"] == "PASS"]
    failed = [r["module"] for r in module_rows if r["status"] != "PASS"]
    if not module_rows:
        aggregate["status"] = "NO_MODULES"
        return aggregate
    aggregate["status"] = "PASS" if not failed else "PARTIAL_FAIL"
    aggregate["status_detail"] = ",".join(failed)
    if not pass_rows:
        return aggregate
    for field in SUM_FIELDS:
        aggregate[field] = sum(float(r[field]) for r in pass_rows if r.get(field) not in ("", None))
    for field in MIN_FIELDS:
        values = [float(r[field]) for r in pass_rows if r.get(field) not in ("", None)]
        if values:
            aggregate[field] = min(values)
    aggregate["clock_period_ns"] = pass_rows[0].get("clock_period_ns", "")
    return aggregate


def comparison_row(case_name: str, anvil_agg: dict | None, sv_agg: dict | None) -> dict | None:
    if anvil_agg is None or sv_agg is None:
        return None
    row = base_row(case_name, "comparison", "comparison", "anvil_over_sv")
    if anvil_agg["status"] != "PASS" or sv_agg["status"] != "PASS":
        row["status"] = "UNAVAILABLE"
        row["status_detail"] = f"anvil={anvil_agg['status']};sv={sv_agg['status']}"
        return row
    row["status"] = "PASS"
    for field in SUM_FIELDS + MIN_FIELDS:
        numerator, denominator = anvil_agg.get(field), sv_agg.get(field)
        if numerator in ("", None) or denominator in ("", None) or float(denominator) == 0.0:
            continue
        row[f"{field}_ratio"] = f"{float(numerator) / float(denominator):.6f}"
    return row


def apply_sv_subtract(case: dict, sv_aggregate: dict, sv_aggregates_by_case: dict[str, dict]) -> None:
    """Subtract other cases' own standalone SV aggregate SUM_FIELDS (cells,
    area, power - not slack, which isn't meaningful to subtract) from this
    case's flattened SV aggregate, count times each (in place). Mirrors
    collect_yosys_perf.py's apply_sv_subtract - see WIDTH_FINDINGS.md's
    "FIFO/Arbiter Exclusion Methodology" for the rationale.
    """
    if sv_aggregate.get("status") != "PASS":
        return
    for entry in case.get("sv_subtract", []):
        other = sv_aggregates_by_case.get(entry["case"])
        if other is None or other.get("status") != "PASS":
            sv_aggregate["status_detail"] += f";sv_subtract unavailable for {entry['case']}"
            continue
        count = entry.get("count", 1)
        for field in SUM_FIELDS:
            value, other_value = sv_aggregate.get(field), other.get(field)
            if value in ("", None) or other_value in ("", None):
                continue
            sv_aggregate[field] = max(float(value) - count * float(other_value), 0)


def add_aggregates_and_comparisons(all_rows: list[dict], cases: list[dict]) -> list[dict]:
    result = list(all_rows)
    per_case_aggregates: dict[str, dict] = {}
    for case in cases:
        case_name = case["name"]
        case_rows = [r for r in all_rows if r["case"] == case_name and r["row_type"] == "module"]
        aggregates = {}
        for variant in ("anvil", "sv"):
            variant_rows = [r for r in case_rows if r["variant"] == variant]
            if not variant_rows:
                continue
            aggregates[variant] = aggregate_row(case_name, variant, variant_rows)
        per_case_aggregates[case_name] = aggregates

    sv_aggregates_by_case = {
        name: aggregates["sv"] for name, aggregates in per_case_aggregates.items() if "sv" in aggregates
    }
    for case in cases:
        case_name = case["name"]
        aggregates = per_case_aggregates[case_name]
        if "sv" in aggregates and case.get("sv_subtract"):
            apply_sv_subtract(case, aggregates["sv"], sv_aggregates_by_case)
        result.extend(aggregates.values())
        comp = comparison_row(case_name, aggregates.get("anvil"), aggregates.get("sv"))
        if comp is not None:
            result.append(comp)
    return result


def format_num(value) -> str:
    if value in ("", None):
        return ""
    try:
        return f"{float(value):.4g}"
    except (TypeError, ValueError):
        return str(value)


def write_markdown(rows: list[dict], md_path: Path) -> None:
    with md_path.open("w") as f:
        f.write("# Real Synthesis (sky130) + OpenSTA Timing/Power Summary\n\n")
        f.write("Synthesis-only (no place-and-route): real sky130_fd_sc_hd area, ")
        f.write("worst-case setup/hold slack and Liberty-based power at a fixed clock period.\n\n")
        f.write("| Case | Variant | Status | Cells | Seq cells | Area (um2) | Setup slack (ns) | Total power (uW) |\n")
        f.write("| --- | --- | --- | ---: | ---: | ---: | ---: | ---: |\n")
        for row in rows:
            if row["row_type"] not in ("aggregate", "comparison"):
                continue
            if row["row_type"] == "comparison":
                cells = format_num(row.get("total_cells_ratio"))
                seq = format_num(row.get("seq_cells_ratio"))
                area = format_num(row.get("area_um2_ratio"))
                slack = format_num(row.get("worst_slack_setup_ns_ratio"))
                power = format_num(row.get("total_power_w_ratio"))
                notes = "ratios are Anvil/SV"
            else:
                cells = format_num(row.get("total_cells"))
                seq = format_num(row.get("seq_cells"))
                area = format_num(row.get("area_um2"))
                slack = format_num(row.get("worst_slack_setup_ns"))
                power_w = row.get("total_power_w")
                power = format_num(float(power_w) * 1e6) if power_w not in ("", None) else ""
                notes = row.get("status_detail", "")
            f.write(
                f"| {row['case']} | {row['variant']} | {row['status']} | {cells} | {seq} | {area} | {slack} | {power} |\n"
            )


def write_summary(rows: list[dict], results_dir: Path) -> None:
    results_dir.mkdir(parents=True, exist_ok=True)
    csv_path = results_dir / "summary.csv"
    with csv_path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=CSV_FIELDS)
        writer.writeheader()
        for row in rows:
            writer.writerow({field: row.get(field, "") for field in CSV_FIELDS})
    json_path = results_dir / "summary.json"
    with json_path.open("w") as f:
        json.dump(rows, f, indent=2, sort_keys=True)
        f.write("\n")
    md_path = results_dir / "summary.md"
    write_markdown(rows, md_path)
    print(f"Summary CSV: {rel(csv_path)}")
    print(f"Summary JSON: {rel(json_path)}")
    print(f"Summary MD: {rel(md_path)}")


def main() -> int:
    config = parse_args()
    if not config.pdk_lib.exists():
        print(f"PDK Liberty file not found: {config.pdk_lib}", file=sys.stderr)
        print("Run: pip install --user volare && volare enable --pdk sky130 <version>", file=sys.stderr)
        return 1
    defaults, cases = load_manifest(config.manifest_path)
    selected_cases = [c for c in cases if not config.case_names or c.get("name") in config.case_names]
    if not selected_cases:
        print("No cases selected.", file=sys.stderr)
        return 1

    all_rows = []
    for case in selected_cases:
        print(f"[{case['name']}] real-cell synth + STA ({config.variant})", flush=True)
        if config.variant in ("anvil", "both"):
            all_rows.extend(rows_for_anvil_case(config, case, defaults))
        if config.variant in ("sv", "both"):
            all_rows.extend(rows_for_sv_case(config, case, defaults))

    all_rows = add_aggregates_and_comparisons(all_rows, selected_cases)
    write_summary(all_rows, config.results_dir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
