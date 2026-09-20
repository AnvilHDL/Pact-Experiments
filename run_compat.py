import os
import argparse
import csv
import re
import shutil
import signal
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
COMPILER_DIR = os.path.abspath(os.path.join(BASE_DIR, "..", "Pact"))
COMPILER_PATH = os.path.join(COMPILER_DIR, "_build", "default", "bin", "main.exe")

# Every invocation of this script gets its own timestamped directory so
# concurrent/repeated runs never clobber each other's logs.
RUN_TIMESTAMP = datetime.now().strftime("%Y%m%d_%H%M%S_%f")
RUN_LOG_DIR = os.path.join(LOGS_ROOT, RUN_TIMESTAMP)
HEARTBEAT_SECONDS = 30


# copy the result in error directory by appending error as prefix to the file name
def error_handler(out_log, file_name):
    os.makedirs(ERROR_DIR, exist_ok=True)
    file_base_name = os.path.basename(file_name)
    error_file = os.path.join(ERROR_DIR, "error_" + file_base_name + ".log")
    shutil.copyfile(out_log, error_file)


# Find String with "Game Analysis Completed : %b\n  (%b) is the answer"  ;
def result_handler(out_log, file_name, returncode=0):
    with open(out_log, 'r') as f:
        verdicts = re.findall(r'Compatibility: (true|false|error)\b', f.read())
    # Every pool must succeed; construction errors are not game losses.
    if returncode != 0 or not verdicts or "error" in verdicts:
        result = Result.Error
    elif "false" in verdicts:
        result = Result.Incompatible
    else:
        result = Result.Compatible
    if result != Result.Compatible:
        error_handler(out_log, file_name)
    return result


def exit_description(returncode):
    if returncode is None:
        return "could not start compiler"
    if returncode < 0:
        return f"signal {signal.Signals(-returncode).name} ({returncode})"
    return f"exit status {returncode}"


def run_compat(file, mode, on_wait):
    file_base = os.path.basename(file)

    # Timestamped, per-file log that persists after the run (not a deleted
    # tempfile) so concurrent --jobs N runs each get their own file and the
    # output stays inspectable afterwards.
    os.makedirs(RUN_LOG_DIR, exist_ok=True)
    log_path = os.path.join(RUN_LOG_DIR, f"{file_base}.log")
    artifact_dir = os.path.join(RUN_LOG_DIR, file_base)
    os.makedirs(artifact_dir, exist_ok=True)
    with open(log_path, "w") as log_file:
        try:
            process = subprocess.Popen(
                [COMPILER_PATH, "-disable-lt-checks", "-debug-choice", str(mode), file],
                cwd=artifact_dir,
                stdout=log_file,
                stderr=subprocess.STDOUT,
            )
            while True:
                try:
                    returncode = process.wait(timeout=HEARTBEAT_SECONDS)
                    break
                except subprocess.TimeoutExpired:
                    on_wait(process.pid)
            log_file.write(f"\n[runner] Compiler finished: {exit_description(returncode)}\n")
        except OSError as error:
            returncode = None
            log_file.write(f"\n[runner] Could not start compiler: {error}\n")

    return result_handler(log_path, file, returncode), returncode


def get_type_files(only=None):
    files = os.listdir(TEST_CASES_DIR)
    if only is None:
        return sorted(f for f in files if f.startswith("type_") and f.endswith(".anvil"))

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
        default=min(4, os.cpu_count() or 1),
        help="Number of compatibility checks to run concurrently (default: up to 4)",
    )
    return parser.parse_args()


def write_csv(path, rows):
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    temporary = path + ".tmp"
    with open(temporary, "w", newline="") as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=["file", "result", "elapsed_seconds", "returncode"])
        writer.writeheader()
        writer.writerows(rows)
    os.replace(temporary, path)

def run_one(file, mode, print_lock):
    log_path = os.path.join(RUN_LOG_DIR, file + ".log")
    with print_lock:
        print(f"Running compatibility check on file: {file} (mode {mode})\n  Log: {log_path}", flush=True)
    start_time = time.perf_counter()

    def on_wait(pid):
        elapsed = time.perf_counter() - start_time
        with print_lock:
            print(f"Still running {file}: {elapsed:.0f}s elapsed, PID {pid}; log: {log_path}", flush=True)

    result, returncode = run_compat(os.path.join(TEST_CASES_DIR, file), mode, on_wait)
    elapsed = time.perf_counter() - start_time
    with print_lock:
        detail = f"; {exit_description(returncode)}" if result == Result.Error else ""
        print(f"Result for {file}: {result} ({elapsed:.2f}s{detail})", flush=True)
    return file, result, elapsed, returncode


def main():
    global COMPILER_PATH
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
    csv_path = args.csv or os.path.join(RUN_LOG_DIR, "results.csv")
    print(f"Queued {len(type_files)} benchmarks; running up to {args.jobs} at a time.\n"
          f"Logs: {RUN_LOG_DIR}\nResults (updated after each completion): {csv_path}\n"
          f"Queue: {', '.join(type_files)}", flush=True)
    # Dune exec retains its build lock for the program's lifetime. Build once,
    # then give every worker the same executable and a separate DOT directory.
    subprocess.run(["dune", "build", "bin/main.exe"], cwd=COMPILER_DIR, check=True)
    os.makedirs(RUN_LOG_DIR, exist_ok=True)
    compiler_snapshot = os.path.join(RUN_LOG_DIR, "pact")
    shutil.copy2(COMPILER_PATH, compiler_snapshot)
    COMPILER_PATH = compiler_snapshot
    compat_count = 0
    incompat_count = 0
    error_count = 0
    results_by_file = {}
    print_lock = threading.Lock()
    write_csv(csv_path, [])
    with ThreadPoolExecutor(max_workers=args.jobs) as executor:
        futures = [executor.submit(run_one, file, mode, print_lock) for file in type_files]
        for future in as_completed(futures):
            file, result, elapsed, returncode = future.result()
            results_by_file[file] = {
                "file": file,
                "result": str(result),
                "elapsed_seconds": f"{elapsed:.6f}",
                "returncode": returncode,
            }
            # Preserve input order without waiting for the slowest benchmark.
            write_csv(csv_path, [results_by_file[name] for name in type_files if name in results_by_file])

    for row in results_by_file.values():
        result = Result[row["result"]]
        match result:
            case Result.Compatible:
                compat_count += 1
            case Result.Incompatible:
                incompat_count += 1
            case Result.Error:
                error_count += 1

    print("==================================================================================")
    print("Summary:")
    print("Compatible: " + str(compat_count))
    print("Incompatible: " + str(incompat_count))
    print("Error: " + str(error_count))
    print("Logs written to: " + os.path.relpath(RUN_LOG_DIR, BASE_DIR))
    print("Results written to: " + csv_path)
    print("==================================================================================", flush=True)


if __name__ == "__main__":
    main()
