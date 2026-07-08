#!/usr/bin/env python3
import argparse
import csv
import json
import re
import shutil
import subprocess
import sys
import time
from collections import Counter
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / "scripts" / "yosys_perf_manifest.json"
DEFAULT_RESULTS = ROOT / "synthesis_reports" / "yosys_perf_results"
ANVIL_DIR = ROOT / "src" / "compat"
RESET_ONLY_FF_RE = re.compile(
    r"(?P<head>always_ff @\(posedge clk_i or negedge rst_ni\) begin : [^\n]+\n)"
    r"(?P<ifline>\s*if \(~rst_ni\) begin\n)"
    r"(?P<body>.*?)"
    r"(?P<tail>\n\s*end\n\s*end)",
    re.DOTALL,
)
RESET_ASSIGN_RE = re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_$]*(?:\[[^\]]+\])?)\s*<=", re.MULTILINE)
SIM_DEBUG_RE = re.compile(r"^\s*\$(display|write|strobe|monitor)\b.*?;\s*$", re.MULTILINE)

METRIC_FIELDS = [
    "total_cells",
    "seq_cells",
    "comb_cells",
    "memories",
    "memory_bits",
    "wire_bits",
    "port_bits",
    "abc_ands",
    "abc_latches",
    "abc_levels",
    "switching_proxy_nodes",
    "state_proxy_bits",
]

RATIO_FIELDS = [f"{field}_ratio" for field in METRIC_FIELDS]

CSV_FIELDS = [
    "case",
    "phase",
    "row_type",
    "variant",
    "module",
    "selected_for_aggregate",
    "status",
    "elapsed_seconds",
    "yosys_version",
    "log",
    "json",
    "abc_log",
    "true_power",
    "status_detail",
    *METRIC_FIELDS,
    *RATIO_FIELDS,
    "cell_histogram",
]


@dataclass(frozen=True)
class RunConfig:
    phase: str
    case_names: set[str] | None
    variant: str
    include_neighbors: bool
    strict: bool
    results_dir: Path
    manifest_path: Path
    keep_generated: bool
    timeout_seconds: int


def parse_args() -> RunConfig:
    parser = argparse.ArgumentParser(
        description="Collect Yosys-only core performance metrics for Anvil and SV components."
    )
    parser.add_argument("--phase", choices=["short", "big", "all"], default="short")
    parser.add_argument("--case", dest="case_names", action="append", help="Run one named case; repeatable")
    parser.add_argument("--variant", choices=["anvil", "sv", "both"], default="both")
    parser.add_argument("--include-neighbors", action="store_true")
    parser.add_argument("--strict", action="store_true")
    parser.add_argument("--results-dir", default=str(DEFAULT_RESULTS))
    parser.add_argument("--manifest", default=str(DEFAULT_MANIFEST))
    parser.add_argument("--keep-generated", action="store_true")
    parser.add_argument(
        "--timeout-seconds",
        type=int,
        default=180,
        help="Per Anvil/Yosys/ABC command timeout. Use 0 to disable.",
    )
    args = parser.parse_args()

    results_dir = Path(args.results_dir)
    if not results_dir.is_absolute():
        results_dir = ROOT / results_dir
    manifest_path = Path(args.manifest)
    if not manifest_path.is_absolute():
        manifest_path = ROOT / manifest_path

    return RunConfig(
        phase=args.phase,
        case_names=set(args.case_names) if args.case_names else None,
        variant=args.variant,
        include_neighbors=args.include_neighbors,
        strict=args.strict,
        results_dir=results_dir,
        manifest_path=manifest_path,
        keep_generated=args.keep_generated,
        timeout_seconds=args.timeout_seconds,
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


def select_cases(cases: list[dict], config: RunConfig) -> list[dict]:
    selected = []
    for case in cases:
        if config.case_names and case.get("name") not in config.case_names:
            continue
        if not config.case_names and config.phase != "all" and case.get("phase") != config.phase:
            continue
        selected.append(case)
    return selected


def get_yosys_version() -> str:
    try:
        proc = subprocess.run(["yosys", "-V"], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, check=False)
    except OSError:
        return ""
    return proc.stdout.strip()


def compile_patterns(patterns: list[str]) -> list[re.Pattern[str]]:
    return [re.compile(pattern) for pattern in patterns]


def matches_any(name: str, patterns: list[re.Pattern[str]]) -> bool:
    return any(pattern.search(name) for pattern in patterns)


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
    """The single `module <module_name> ( ... ) ... endmodule` block, verbatim.

    Anvil's generated SV is flat (no file-scope packages/typedefs, no
    submodule instantiation between the manifest's core-pattern modules -
    each is an independent leaf), so isolating exactly one module's own text
    is a complete, self-contained compilation unit on its own. This sidesteps
    a read_slang/slang limitation: `--top <name>` restricts elaboration but
    NOT whole-file semantic checking, so an unrelated, unreachable module
    elsewhere in the same file (e.g. a testbench wrapper using `.clk_i`
    implicit-port-connection shorthand only valid in its own scope) can still
    break synthesis of the requested top, even though it's never instantiated
    under it. Confirmed via isolating a real case (`demux_ar_main` out of
    `axi_demux_read`'s generated SV): synthesizes cleanly alone, fails
    against the full single-unit file with an unrelated `test_demux_read`
    "undeclared identifier 'clk_i'" error.
    """
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


def write_precheck_log(log_path: Path, command: list[str], stdout_path: Path | None = None) -> None:
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with log_path.open("w") as log_file:
        log_file.write("$ " + " ".join(command) + "\n")
        if stdout_path:
            log_file.write(f"# stdout: {rel(stdout_path)}\n")


def generate_anvil(case: dict, config: RunConfig) -> tuple[str, Path | None, Path]:
    case_name = case["name"]
    generated_dir = config.results_dir / "generated" / case_name
    generated_dir.mkdir(parents=True, exist_ok=True)
    out_path = generated_dir / "anvil.sv"
    yosys_path = generated_dir / "anvil.yosys.sv"
    log_path = config.results_dir / "logs" / case_name / "anvil" / "generate.log"
    command = ["anvil", "-disable-lt-checks", "-disable-compat-checks", "-disable-session-checks","-O", "3", case["anvil_test"]]

    if out_path.exists() and not config.keep_generated:
        out_path.unlink()

    write_precheck_log(log_path, command, out_path)
    start = time.perf_counter()
    with out_path.open("w") as stdout_file, log_path.open("a") as stderr_file:
        try:
            proc = subprocess.run(
                command,
                cwd=ANVIL_DIR,
                stdout=stdout_file,
                stderr=stderr_file,
                check=False,
                timeout=config.timeout_seconds or None,
            )
            returncode = proc.returncode
        except subprocess.TimeoutExpired:
            returncode = -124
            stderr_file.write(f"\n# timeout_seconds: {config.timeout_seconds}\n")
        stderr_file.write(f"\n# elapsed_seconds: {time.perf_counter() - start:.6f}\n")
        stderr_file.write(f"# returncode: {returncode}\n")

    if returncode == -124:
        return f"TIMEOUT({config.timeout_seconds})", None, log_path
    if returncode != 0:
        return f"PRECHECK_FAIL({returncode})", None, log_path
    if not out_path.exists() or out_path.stat().st_size == 0:
        return "PRECHECK_FAIL(empty-output)", None, log_path
    sanitize_anvil_sv_for_yosys(out_path, yosys_path, log_path)
    return "PASS", yosys_path, log_path


def sanitize_anvil_sv_for_yosys(in_path: Path, out_path: Path, log_path: Path) -> None:
    text = in_path.read_text()
    replacements = 0
    debug_statements = 0

    def replace_reset_only(match: re.Match[str]) -> str:
        nonlocal replacements
        body = match.group("body")
        if re.search(r"\n\s*end\s+else\b", match.group(0)):
            return match.group(0)
        targets = RESET_ASSIGN_RE.findall(body)
        if not targets:
            return match.group(0)
        replacements += 1
        holds = "".join(f"      {target} <= {target};\n" for target in targets)
        return (
            match.group("head")
            + match.group("ifline")
            + body
            + "\n    end else begin\n"
            + holds
            + "    end\n"
            + "  end"
        )

    sanitized, debug_statements = SIM_DEBUG_RE.subn("", text)
    sanitized = RESET_ONLY_FF_RE.sub(replace_reset_only, sanitized)
    out_path.write_text(sanitized)
    if replacements or debug_statements:
        with log_path.open("a") as log_file:
            if debug_statements:
                log_file.write(f"# yosys_sanitizer: stripped {debug_statements} simulation debug statement(s)\n")
            if replacements:
                log_file.write(f"# yosys_sanitizer: added explicit self-holds to {replacements} reset-only always_ff block(s)\n")


def sanitize_tilelink_crossbar_for_yosys(in_path: Path, out_path: Path) -> None:
    text = in_path.read_text()
    if "slaveLinksRemapped_0_d_bits_source" not in text:
        out_path.write_text(text)
        return

    module_index = text.find("module TLCrossBar")
    port_end = text.find(");\n", module_index)
    if module_index == -1 or port_end == -1:
        out_path.write_text(text)
        return

    early_decl = (
        "\n"
        "  wire [1:0] slaveLinksRemapped_0_d_bits_source;\n"
        "  wire [1:0] slaveLinksRemapped_1_d_bits_source;\n"
    )
    text = text[: port_end + 3] + early_decl + text[port_end + 3 :]
    text = re.sub(
        r"(\s*)wire\s+\[1:0\]\s+slaveLinksRemapped_0_d_bits_source\s*=",
        r"\1assign slaveLinksRemapped_0_d_bits_source =",
        text,
        count=1,
    )
    text = re.sub(
        r"(\s*)wire\s+\[1:0\]\s+slaveLinksRemapped_1_d_bits_source\s*=",
        r"\1assign slaveLinksRemapped_1_d_bits_source =",
        text,
        count=1,
    )
    out_path.write_text(text)


def prepare_sv_files_for_yosys(case: dict, config: RunConfig) -> tuple[list[Path], list[Path]]:
    original_files = [(ROOT / path) for path in case.get("sv_files", [])]
    missing = [path for path in original_files if not path.exists()]
    if missing:
        return original_files, missing

    prepared = []
    prepared_dir = config.results_dir / "generated" / case["name"] / "sv"
    for path in original_files:
        if path.name == "TLCrossBar.sv":
            prepared_dir.mkdir(parents=True, exist_ok=True)
            out_path = prepared_dir / path.name
            sanitize_tilelink_crossbar_for_yosys(path, out_path)
            prepared.append(out_path)
        else:
            prepared.append(path)
    return prepared, []


def yosys_args_for_case(case: dict, defaults: dict, top: str, files: list[Path], blif_path: Path) -> list[str]:
    define_args = []
    for define in defaults.get("defines", []):
        define_args.extend(["-D", define])

    include_args = []
    for include_dir in defaults.get("include_dirs", []):
        include_args.append("-I" + str((ROOT / include_dir).resolve()))

    file_args = [str(path.resolve()) for path in files]
    read_args = " ".join(["read_slang", "--single-unit", "--top", top, *define_args, *include_args, *file_args])
    script = "\n".join(
        [
            read_args,
            f"synth -top {top} -flatten",
            "opt -purge",
            "stat -json",
            f"write_blif {blif_path.resolve()}",
        ]
    )
    return ["yosys", "-m", "slang", "-p", script]


def run_logged(command: list[str], log_path: Path, cwd: Path = ROOT, timeout_seconds: int = 180) -> tuple[int, float, str]:
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
        returncode = proc.returncode
        output = proc.stdout
    except subprocess.TimeoutExpired as err:
        returncode = -124
        output = err.stdout or ""
        if isinstance(output, bytes):
            output = output.decode(errors="replace")
        output += f"\n# timeout_seconds: {timeout_seconds}\n"
    elapsed = time.perf_counter() - start
    with log_path.open("w") as log_file:
        log_file.write("$ " + " ".join(command) + "\n")
        log_file.write(output)
        log_file.write(f"\n# elapsed_seconds: {elapsed:.6f}\n")
        log_file.write(f"# returncode: {returncode}\n")
    return returncode, elapsed, output


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


def count_sequential_cells(cell_hist: dict[str, int]) -> int:
    seq_tokens = ("dff", "adff", "sdff", "dlatch", "latch", "$ff")
    total = 0
    for cell_type, count in cell_hist.items():
        lowered = cell_type.lower()
        if any(token in lowered for token in seq_tokens):
            total += int(count)
    return total


def count_memory_cells(cell_hist: dict[str, int]) -> int:
    return sum(int(count) for cell_type, count in cell_hist.items() if "$mem" in cell_type.lower())


def metrics_from_stat(stat_json: dict, top: str) -> tuple[dict, dict]:
    module_stat = find_module_stat(stat_json, top)
    if module_stat is None:
        raise ValueError(f"stat JSON does not contain top module {top}")

    cell_hist = {str(k): int(v) for k, v in module_stat.get("num_cells_by_type", {}).items()}
    total_cells = int(module_stat.get("num_cells", sum(cell_hist.values())))
    seq_cells = count_sequential_cells(cell_hist)
    mem_cells = count_memory_cells(cell_hist)
    comb_cells = max(total_cells - seq_cells - mem_cells, 0)
    memories = int(module_stat.get("num_memories", mem_cells))
    memory_bits = int(module_stat.get("num_memory_bits", 0))
    wire_bits = int(module_stat.get("num_wire_bits", 0))
    port_bits = int(module_stat.get("num_port_bits", 0))

    metrics = {
        "total_cells": total_cells,
        "seq_cells": seq_cells,
        "comb_cells": comb_cells,
        "memories": memories,
        "memory_bits": memory_bits,
        "wire_bits": wire_bits,
        "port_bits": port_bits,
        "abc_ands": "",
        "abc_latches": "",
        "abc_levels": "",
        "switching_proxy_nodes": comb_cells,
        "state_proxy_bits": seq_cells + memory_bits,
    }
    return metrics, cell_hist


def parse_abc_stats(output: str) -> dict:
    stats = {}
    for field, aliases in {
        "abc_ands": ("and", "aig", "nd"),
        "abc_latches": ("lat", "latch", "latches"),
        "abc_levels": ("lev", "level", "levels"),
    }.items():
        for alias in aliases:
            match = re.search(rf"\b{re.escape(alias)}\s*=\s*([0-9]+)", output)
            if match:
                stats[field] = int(match.group(1))
                break
    return stats


def run_abc(blif_path: Path, log_path: Path, timeout_seconds: int) -> dict:
    if not blif_path.exists():
        return {}
    command = [
        "yosys-abc",
        "-c",
        f"read_blif {blif_path.resolve()}; strash; print_stats;",
    ]
    rc, _, output = run_logged(command, log_path, timeout_seconds=timeout_seconds)
    if rc != 0:
        return {}
    return parse_abc_stats(output)


def synthesize_module(
    case: dict,
    defaults: dict,
    config: RunConfig,
    variant: str,
    module: str,
    files: list[Path],
    selected_for_aggregate: bool,
) -> dict:
    case_name = case["name"]
    log_path = config.results_dir / "logs" / case_name / variant / f"{module}.log"
    abc_log_path = config.results_dir / "logs" / case_name / variant / f"{module}.abc.log"
    json_path = config.results_dir / "json" / case_name / variant / f"{module}.stat.json"
    blif_path = config.results_dir / "blif" / case_name / variant / f"{module}.blif"
    json_path.parent.mkdir(parents=True, exist_ok=True)
    blif_path.parent.mkdir(parents=True, exist_ok=True)

    command = yosys_args_for_case(case, defaults, module, files, blif_path)
    rc, elapsed, output = run_logged(command, log_path, timeout_seconds=config.timeout_seconds)
    row = base_row(case, variant, "module", module, selected_for_aggregate)
    row.update(
        {
            "elapsed_seconds": f"{elapsed:.6f}",
            "yosys_version": get_yosys_version(),
            "log": rel(log_path),
            "json": rel(json_path),
            "abc_log": rel(abc_log_path),
            "true_power": "UNAVAILABLE_YOSYS_ONLY",
        }
    )

    if rc != 0:
        if rc == -124:
            row["status"] = f"YOSYS_TIMEOUT({config.timeout_seconds})"
            row["status_detail"] = "Yosys command timed out; see log."
        else:
            row["status"] = f"YOSYS_FAIL({rc})"
            row["status_detail"] = "Yosys command failed; see log."
        return row

    stat_json = extract_stat_json(output)
    if stat_json is None:
        row["status"] = "STAT_PARSE_FAIL"
        row["status_detail"] = "Yosys completed but stat -json output was not found."
        return row

    with json_path.open("w") as stat_file:
        json.dump(stat_json, stat_file, indent=2, sort_keys=True)
        stat_file.write("\n")

    try:
        metrics, cell_hist = metrics_from_stat(stat_json, module)
    except ValueError as err:
        row["status"] = "STAT_PARSE_FAIL"
        row["status_detail"] = str(err)
        return row

    abc_metrics = run_abc(blif_path, abc_log_path, config.timeout_seconds)
    metrics.update(abc_metrics)
    if metrics.get("abc_ands") != "":
        metrics["switching_proxy_nodes"] = metrics["abc_ands"]

    row["status"] = "PASS"
    row["status_detail"] = ""
    row.update(metrics)
    row["cell_histogram"] = json.dumps(cell_hist, sort_keys=True)
    return row


def base_row(case: dict, variant: str, row_type: str, module: str, selected: bool) -> dict:
    row = {field: "" for field in CSV_FIELDS}
    row.update(
        {
            "case": case["name"],
            "phase": case["phase"],
            "row_type": row_type,
            "variant": variant,
            "module": module,
            "selected_for_aggregate": "1" if selected else "0",
            "true_power": "UNAVAILABLE_YOSYS_ONLY",
        }
    )
    return row


def precheck_failure_row(case: dict, variant: str, status: str, log_path: Path, detail: str) -> dict:
    row = base_row(case, variant, "aggregate", "aggregate", True)
    row.update(
        {
            "status": status,
            "log": rel(log_path),
            "status_detail": detail,
        }
    )
    return row


def aggregate_rows(case: dict, variant: str, rows: list[dict]) -> dict:
    selected = [row for row in rows if row["variant"] == variant and row["row_type"] == "module" and row["selected_for_aggregate"] == "1"]
    aggregate = base_row(case, variant, "aggregate", "aggregate", True)
    aggregate["true_power"] = "UNAVAILABLE_YOSYS_ONLY"

    if not selected:
        aggregate["status"] = "NO_SELECTED_MODULES"
        aggregate["status_detail"] = "No modules matched aggregate core patterns."
        return aggregate

    pass_rows = [row for row in selected if row["status"] == "PASS"]
    failed = [row["module"] for row in selected if row["status"] != "PASS"]
    aggregate["status"] = "PASS" if not failed else "PARTIAL_FAIL"
    aggregate["status_detail"] = ",".join(failed)
    aggregate["elapsed_seconds"] = f"{sum(float(row.get('elapsed_seconds') or 0.0) for row in selected):.6f}"

    for field in METRIC_FIELDS:
        total = 0
        has_value = False
        for row in pass_rows:
            value = row.get(field)
            if value == "" or value is None:
                continue
            total += int(float(value))
            has_value = True
        aggregate[field] = total if has_value else ""

    hist = Counter()
    for row in pass_rows:
        if not row.get("cell_histogram"):
            continue
        hist.update(json.loads(row["cell_histogram"]))
    aggregate["cell_histogram"] = json.dumps(dict(sorted(hist.items())), sort_keys=True)
    return aggregate


def comparison_row(case: dict, aggregate_rows_by_variant: dict[str, dict]) -> dict | None:
    anvil = aggregate_rows_by_variant.get("anvil")
    sv = aggregate_rows_by_variant.get("sv")
    if not anvil or not sv:
        return None

    row = base_row(case, "comparison", "comparison", "anvil_over_sv", True)
    row["true_power"] = "UNAVAILABLE_YOSYS_ONLY"
    if anvil["status"] != "PASS" or sv["status"] != "PASS":
        row["status"] = "UNAVAILABLE"
        row["status_detail"] = f"anvil={anvil['status']};sv={sv['status']}"
        return row

    row["status"] = "PASS"
    for field in METRIC_FIELDS:
        numerator = anvil.get(field)
        denominator = sv.get(field)
        if numerator in ("", None) or denominator in ("", None) or float(denominator) == 0.0:
            continue
        row[f"{field}_ratio"] = f"{float(numerator) / float(denominator):.6f}"
    return row


def rows_failed(rows: list[dict]) -> bool:
    return any(row.get("status") not in ("PASS", "") for row in rows if row.get("variant") != "comparison")


def rows_for_anvil_case(case: dict, defaults: dict, config: RunConfig) -> list[dict]:
    rows = []
    status, generated_sv, generate_log = generate_anvil(case, config)
    if status != "PASS":
        detail = "Anvil code generation timed out." if status.startswith("TIMEOUT") else "Anvil code generation failed."
        rows.append(precheck_failure_row(case, "anvil", status, generate_log, detail))
        return rows

    modules = discover_modules(generated_sv)
    core_patterns = compile_patterns(case.get("anvil_core_patterns", []))
    ignore_patterns = compile_patterns(defaults.get("anvil_ignore_patterns", []))

    selected_modules = []
    for module in modules:
        is_core = matches_any(module, core_patterns)
        is_ignored = matches_any(module, ignore_patterns)
        if is_core or (config.include_neighbors and is_ignored):
            selected_modules.append((module, is_core))

    isolated_dir = config.results_dir / "generated" / case["name"] / "anvil_isolated"
    for module, is_core in selected_modules:
        module_text = extract_module_text(generated_sv, module)
        if module_text is None:
            # Fall back to the whole file if isolation didn't find a clean
            # module...endmodule span (e.g. an unexpected shape) - safer to
            # keep prior behaviour than to silently synthesize nothing.
            files = [generated_sv]
        else:
            isolated_dir.mkdir(parents=True, exist_ok=True)
            isolated_path = isolated_dir / f"{module}.sv"
            isolated_path.write_text(module_text)
            files = [isolated_path]
        rows.append(synthesize_module(case, defaults, config, "anvil", module, files, is_core))
    rows.append(aggregate_rows(case, "anvil", rows))
    return rows


def rows_for_sv_case(case: dict, defaults: dict, config: RunConfig) -> list[dict]:
    rows = []
    files, missing = prepare_sv_files_for_yosys(case, config)
    if missing:
        log_path = config.results_dir / "logs" / case["name"] / "sv" / "missing_files.log"
        log_path.parent.mkdir(parents=True, exist_ok=True)
        log_path.write_text("\n".join(rel(path) for path in missing) + "\n")
        rows.append(precheck_failure_row(case, "sv", "PRECHECK_FAIL(missing-files)", log_path, "SV input files are missing."))
        return rows

    tops = [(case["sv_top"], True)]
    if config.include_neighbors:
        for top in case.get("sv_neighbor_tops", []):
            tops.append((top, False))

    seen = set()
    for module, selected in tops:
        if module in seen:
            continue
        seen.add(module)
        rows.append(synthesize_module(case, defaults, config, "sv", module, files, selected))
    rows.append(aggregate_rows(case, "sv", rows))
    return rows


def write_summary_files(rows: list[dict], results_dir: Path) -> None:
    results_dir.mkdir(parents=True, exist_ok=True)
    csv_path = results_dir / "summary.csv"
    json_path = results_dir / "summary.json"
    md_path = results_dir / "summary.md"

    with csv_path.open("w", newline="") as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=CSV_FIELDS)
        writer.writeheader()
        for row in rows:
            writer.writerow({field: row.get(field, "") for field in CSV_FIELDS})

    with json_path.open("w") as json_file:
        json.dump(rows, json_file, indent=2, sort_keys=True)
        json_file.write("\n")

    aggregate_rows_only = [row for row in rows if row["row_type"] in ("aggregate", "comparison")]
    with md_path.open("w") as md_file:
        md_file.write("# Yosys Core Performance Summary\n\n")
        md_file.write("True power is unavailable in this Yosys-only flow; power fields are proxy metrics only.\n\n")
        md_file.write("| Case | Variant | Status | Total cells | Seq cells | Comb cells | ABC levels | Notes |\n")
        md_file.write("| --- | --- | --- | ---: | ---: | ---: | ---: | --- |\n")
        for row in aggregate_rows_only:
            notes = row.get("status_detail", "")
            if row["row_type"] == "comparison":
                notes = "ratios are Anvil/SV"
            md_file.write(
                "| {case} | {variant} | {status} | {total} | {seq} | {comb} | {levels} | {notes} |\n".format(
                    case=row["case"],
                    variant=row["variant"],
                    status=row.get("status", ""),
                    total=row.get("total_cells") or row.get("total_cells_ratio", ""),
                    seq=row.get("seq_cells") or row.get("seq_cells_ratio", ""),
                    comb=row.get("comb_cells") or row.get("comb_cells_ratio", ""),
                    levels=row.get("abc_levels") or row.get("abc_levels_ratio", ""),
                    notes=notes.replace("|", "\\|"),
                )
            )


def main() -> int:
    config = parse_args()
    defaults, cases = load_manifest(config.manifest_path)
    selected_cases = select_cases(cases, config)
    if not selected_cases:
        print("No cases selected.", file=sys.stderr)
        return 1

    for tool in ("yosys", "yosys-abc"):
        if shutil.which(tool) is None:
            print(f"Required tool not found on PATH: {tool}", file=sys.stderr)
            return 1

    config.results_dir.mkdir(parents=True, exist_ok=True)
    all_rows = []

    for case in selected_cases:
        print(f"[{case['name']}] collecting {config.variant}", flush=True)
        case_rows = []
        if config.variant in ("anvil", "both"):
            case_rows.extend(rows_for_anvil_case(case, defaults, config))
        if config.variant in ("sv", "both"):
            case_rows.extend(rows_for_sv_case(case, defaults, config))

        aggregates = {
            row["variant"]: row
            for row in case_rows
            if row["row_type"] == "aggregate" and row["variant"] in ("anvil", "sv")
        }
        comp = comparison_row(case, aggregates)
        if comp is not None:
            case_rows.append(comp)
        all_rows.extend(case_rows)

    write_summary_files(all_rows, config.results_dir)
    print(f"Summary CSV: {rel(config.results_dir / 'summary.csv')}")
    print(f"Summary JSON: {rel(config.results_dir / 'summary.json')}")
    print(f"Summary MD: {rel(config.results_dir / 'summary.md')}")

    if config.strict and rows_failed(all_rows):
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
