import os
import argparse
import csv
import shutil
import subprocess
import tempfile
import time
from enum import Enum

class Result(Enum):
    Compatible = 1
    Incompatible = 2
    Error = 3
    def __str__(self):
        if self == Result.Compatible:
            return "Compatible"
        elif self == Result.Incompatible:
            return "Incompatible"
        elif self == Result.Error:
            return "Error"

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
ERROR_DIR = os.path.join(BASE_DIR, "error_logs")
TEST_CASES_DIR = os.path.join(BASE_DIR, "src/compat")

# copy the result in error directory by appending error as prefix to the file name
def error_handler(out_log,file_name):
    if not os.path.exists(ERROR_DIR):
        os.makedirs(ERROR_DIR)
    file_base_name = os.path.basename(file_name)
    error_file = os.path.join(ERROR_DIR, "error_" + file_base_name + ".log")
    os.rename(out_log, error_file)


# Find String with "Game Analysis Completed : %b\n  (%b) is the answer"  ;
def result_handler(out_log,file_name):
    with open(out_log, 'r') as f:
        for line in f:
            if "Compatibility: true" in line:
                return Result.Compatible
            elif "Compatibility: false" in line:
                error_handler(out_log, file_name)
                return Result.Incompatible
    
    error_handler(out_log, file_name)
    return Result.Error


def run_compat(file, mode):
    file_base = os.path.basename(file)
    print("Running compatibility check on file: " + file_base)
    relative_file = os.path.relpath(file, BASE_DIR)

    # Unique per invocation (not a fixed "compat_temp.txt") so concurrent
    # run_compat.py processes - e.g. under scripts/run_comm_safety_timing.py
    # --jobs N - don't race on the same log file.
    fd, compat_temp_log = tempfile.mkstemp(prefix="compat_", suffix=".txt", dir=BASE_DIR)
    os.close(fd)
    try:
        with open(compat_temp_log, "w") as log_file:
            subprocess.run(
                ["./run_anvil", "-d", str(mode), relative_file],
                cwd=BASE_DIR,
                stdout=log_file,
                stderr=subprocess.STDOUT,
                check=False,
            )

        return result_handler(compat_temp_log, file)
    finally:
        if os.path.exists(compat_temp_log):
            os.remove(compat_temp_log)


def get_type_files(only=None):
    files = os.listdir(TEST_CASES_DIR)
    if only is None:
        return [f for f in files if f.startswith("type_")]

    selected = []
    for raw_name in only:
        name = raw_name.strip()
        if not name:
            continue
        if not name.endswith(".anvil"):
            name = name + ".anvil"

        candidates = [name]
        if not name.startswith(("type_", "test_")):
            candidates.append("type_" + name)

        found = None
        for candidate in candidates:
            if candidate in files:
                found = candidate
                break
        if found is None:
            found = candidates[0]
        selected.append(found)

    return selected


def parse_args():
    parser = argparse.ArgumentParser(description="Run Anvil compatibility checks.")
    parser.add_argument("mode", help="Compatibility mode: 2, 3, or 4")
    parser.add_argument(
        "--only",
        help="Comma-separated list of compat files to run, e.g. type_fifo.anvil,type_stream_fifo.anvil",
    )
    parser.add_argument("--csv", help="Write per-file timing/result rows to this CSV path")
    return parser.parse_args()


def write_csv(path, rows):
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "w", newline="") as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=["file", "result", "elapsed_seconds"])
        writer.writeheader()
        writer.writerows(rows)

if __name__ == "__main__":
    args = parse_args()
    if not args.mode:
        print("Usage: python run_compat.py <mode>")
        print("Mode can be 2 3 4")
        exit(1)
    mode = args.mode
    if mode not in ["2", "3", "4"]:
        print("Invalid mode. Mode can be 2 3 4")
        exit(1)
    only = args.only.split(",") if args.only else None
    type_files = get_type_files(only)
    shutil.rmtree(ERROR_DIR, ignore_errors=True)
    compat_count = 0
    incompat_count = 0
    error_count = 0
    csv_rows = []
    for file in type_files:

        print("==================================================================================")
        start_time = time.perf_counter()
        result = run_compat(os.path.join(TEST_CASES_DIR, file), mode)
        elapsed = time.perf_counter() - start_time
        match result:
            case Result.Compatible:
                compat_count += 1
            case Result.Incompatible:
                incompat_count += 1
            case Result.Error:
                error_count += 1
        print("Result for " + file + ": " + str(result))
        print("==================================================================================")
        csv_rows.append({
            "file": file,
            "result": str(result),
            "elapsed_seconds": f"{elapsed:.6f}",
        })

    print("==================================================================================")
    print("Summary:")
    print("Compatible: " + str(compat_count))
    print("Incompatible: " + str(incompat_count))
    print("Error: " + str(error_count))
    print("==================================================================================")
    if args.csv:
        write_csv(args.csv, csv_rows)
