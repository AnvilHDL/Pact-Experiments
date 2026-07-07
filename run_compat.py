import os
import subprocess
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


def run_compat(file,mode):
    file_base = os.path.basename(file)
    print("Running compatibility check on file: " + file_base)
    compat_temp_log = os.path.join(BASE_DIR, "compat_temp.txt")
    relative_file = os.path.relpath(file, BASE_DIR)

    with open(compat_temp_log, "w") as log_file:
        subprocess.run(
            ["./run_anvil", "-d", str(mode), relative_file],
            cwd=BASE_DIR,
            stdout=log_file,
            stderr=subprocess.STDOUT,
            check=False,
        )

    return result_handler(compat_temp_log, file)


def get_type_files():
    files = os.listdir(TEST_CASES_DIR)
    return [f for f in files if f.startswith("type_")]

if __name__ == "__main__":
    if len(os.sys.argv) < 2:
        print("Usage: python run_compat.py <mode>")
        print("Mode can be 2 3 4")
        exit(1)
    else:
        mode = os.sys.argv[1]
        if mode not in ["2", "3", "4"]:
            print("Invalid mode. Mode can be 2 3 4")
            exit(1)
    type_files = get_type_files()
    os.system("rm -rf " + ERROR_DIR)
    compat_count = 0
    incompat_count = 0
    error_count = 0
    for file in type_files:

        print("==================================================================================")
        result = run_compat(os.path.join(TEST_CASES_DIR, file), mode)
        match result:
            case Result.Compatible:
                compat_count += 1
            case Result.Incompatible:
                incompat_count += 1
            case Result.Error:
                error_count += 1
        print("Result for " + file + ": " + str(result))
        print("==================================================================================")

    print("==================================================================================")
    print("Summary:")
    print("Compatible: " + str(compat_count))
    print("Incompatible: " + str(incompat_count))
    print("Error: " + str(error_count))
    print("==================================================================================")

