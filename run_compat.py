import os
import argparse
import csv
import shutil
import subprocess
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime
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
LOGS_ROOT = os.path.join(BASE_DIR, "logs", "compat")
ERROR_DIR = os.path.join(BASE_DIR, "error_logs")
TEST_CASES_DIR = os.path.join(BASE_DIR, "src/compat")

# Every invocation of this script gets its own timestamped directory so
# concurrent/repeated runs never clobber each other's logs.
RUN_TIMESTAMP = datetime.now().strftime("%Y%m%d_%H%M%S")
RUN_LOG_DIR = os.path.join(LOGS_ROOT, RUN_TIMESTAMP)


# copy the result in error directory by appending error as prefix to the file name
def error_handler(out_log, file_name):
    os.makedirs(ERROR_DIR, exist_ok=True)
    file_base_name = os.path.basename(file_name)
    error_file = os.path.join(ERROR_DIR, "error_" + file_base_name + ".log")
    shutil.copyfile(out_log, error_file)


# Find String with "Game Analysis Completed : %b\n  (%b) is the answer"  ;
def result_handler(out_log, file_name):
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

    # Timestamped, per-file log that persists after the run (not a deleted
    # tempfile) so concurrent --jobs N runs each get their own file and the
    # output stays inspectable afterwards.
    os.makedirs(RUN_LOG_DIR, exist_ok=True)
    log_path = os.path.join(RUN_LOG_DIR, f"{file_base}.log")
    with open(log_path, "w") as log_file:
        subprocess.run(
            ["./run_anvil", "-d", str(mode), relative_file],
            cwd=BASE_DIR,
            stdout=log_file,
            stderr=subprocess.STDOUT,
            check=False,
        )

    return result_handler(log_path, file)


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
    parser.add_argument(
        "--jobs", "-j",
        type=int,
        default=1,
        help="Number of compatibility checks to run concurrently (default: 1, sequential)",
    )
    return parser.parse_args()


def write_csv(path, rows):
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "w", newline="") as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=["file", "result", "elapsed_seconds"])
        writer.writeheader()
        writer.writerows(rows)

def run_one(file, mode, print_lock):
    with print_lock:
        print("==================================================================================")
        print("Running compatibility check on file: " + file)
    start_time = time.perf_counter()
    result = run_compat(os.path.join(TEST_CASES_DIR, file), mode)
    elapsed = time.perf_counter() - start_time
    with print_lock:
        print("Result for " + file + ": " + str(result) + f" ({elapsed:.2f}s)")
        print("==================================================================================")
    return file, result, elapsed


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
    if args.jobs < 1:
        print("Invalid --jobs value. Must be >= 1")
        exit(1)
    only = args.only.split(",") if args.only else None
    type_files = get_type_files(only)
    shutil.rmtree(ERROR_DIR, ignore_errors=True)
    compat_count = 0
    incompat_count = 0
    error_count = 0
    csv_rows = []
    print_lock = threading.Lock()

    if args.jobs == 1:
        results = [run_one(file, mode, print_lock) for file in type_files]
    else:
        results_by_file = {}
        with ThreadPoolExecutor(max_workers=args.jobs) as executor:
            futures = {
                executor.submit(run_one, file, mode, print_lock): file
                for file in type_files
            }
            for future in as_completed(futures):
                file, result, elapsed = future.result()
                results_by_file[file] = (result, elapsed)
        # Preserve the original file ordering in the summary/CSV regardless of completion order.
        results = [(file, *results_by_file[file]) for file in type_files]

    for file, result, elapsed in results:
        match result:
            case Result.Compatible:
                compat_count += 1
            case Result.Incompatible:
                incompat_count += 1
            case Result.Error:
                error_count += 1
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
    print("Logs written to: " + os.path.relpath(RUN_LOG_DIR, BASE_DIR))
    print("==================================================================================")
    if args.csv:
        write_csv(args.csv, csv_rows)
