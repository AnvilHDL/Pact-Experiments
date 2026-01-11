import os
import sys


# Tests to Run

#  1. FIFO
#  2. Spill Register
#  3. Stream FIFO
#  4. AXI Lite MUX ROUTER
#  5. AXI Lite DEMUX ROUTER
#  6. Filament Benchmarks
#  7. CVA6 Benchmarks



ROOT_DIR = os.path.dirname(os.path.abspath(__file__))
SRC_DIR = os.path.join(ROOT_DIR, "src")
SCRIPTS_DIR = os.path.join(ROOT_DIR, "scripts")
COMMON_CELLS = os.path.join(SRC_DIR, "common_cells")
AXI = os.path.join(SRC_DIR, "axi")
OUT_DIR = os.path.join(ROOT_DIR, "out")
AXI_BASE = os.path.join(ROOT_DIR, "axi/src/")
FILAMENT = os.path.join(SRC_DIR, "filament")
CVA6_DIR = os.path.join(ROOT_DIR, "cva6_ariane")
AES_SRC = os.path.join(ROOT_DIR, "opentitan/hw/ip/aes/rtl")
AES_ANVIl = os.path.join(SRC_DIR, "aes")

GREEN="\033[92m"
Yellow="\033[93m"
Blue="\033[94m"
RED="\033[91m"

if not os.path.exists(OUT_DIR):
    os.makedirs(OUT_DIR)
else :
    os.system(f"rm -rf {OUT_DIR}/*")


def print_log(msg):
    print(f"{GREEN}[INFO] {msg}")



def fifo_benchmarks():
    print_log("Running FIFO Benchmarks...")
    os.chdir(COMMON_CELLS)
    os.system("make clean > /dev/null 2>&1")
    os.system(f"make run SILENT=1 MODULE_NAME=fifo_top > {OUT_DIR}/fifo_benchmarks.log 2>&1")
    print_log("FIFO Benchmarks Completed! Check logs in out/fifo_benchmarks.log\n")

def spill_register_benchmarks():
    print_log("Running Spill Register Benchmarks...")
    os.chdir(COMMON_CELLS)
    os.system("make clean > /dev/null 2>&1")
    os.system(f"make run SILENT=1 MODULE_NAME=spill_reg_top > {OUT_DIR}/spill_register_benchmarks.log 2>&1")
    print_log("Spill Register Benchmarks Completed! Check logs in out/spill_register_benchmarks.log\n")

def stream_fifo_benchmarks():
    print_log("Running Stream FIFO Benchmarks...")
    os.chdir(COMMON_CELLS)
    os.system("make clean > /dev/null 2>&1")
    os.system(f"make run SILENT=1 MODULE_NAME=stream_fifo_top > {OUT_DIR}/stream_fifo_benchmarks.log 2>&1")
    print_log("Stream FIFO Benchmarks Completed! Check logs in out/stream_fifo_benchmarks.log\n")

def run_axi_lite_default():
    os.system(f"python3 create_testbench.py axi_lite_mux_top axi_lite_mux > /dev/null 2>&1")
    os.system(f"cp {SCRIPTS_DIR}/run_axi_veri.sh {AXI_BASE}/")
    os.chdir(AXI_BASE)
    os.system(f"bash run_axi_veri.sh axi_lite_mux_top >> {OUT_DIR}/axi_lite_mux_router_benchmarks.log 2>&1")

def axi_lite_mux_router_benchmarks():
    print_log("Running AXI Lite MUX ROUTER Benchmarks...")
    os.chdir(AXI)
    os.system("make clean > /dev/null 2>&1")
    os.system(f"echo \"====Running AXI Lite MUX ROUTER Testbench for Anvil======== \\n\\n\\n \" > {OUT_DIR}/axi_lite_mux_router_benchmarks.log 2>&1")
    print_log("Running AXI Lite MUX ROUTER Testbench for Anvil")
    os.system(f"make run SILENT=1 MODULE_NAME=axi_lite_mux_top >> {OUT_DIR}/axi_lite_mux_router_benchmarks.log 2>&1")
    os.system(f"echo \"====Running AXI Lite MUX ROUTER Testbench for SV(Baseline)========\\n\\n\\n \" >> {OUT_DIR}/axi_lite_mux_router_benchmarks.log 2>&1")
    print_log("Running AXI Lite MUX ROUTER Testbench for SV(Baseline)")
    run_axi_lite_default()
    print_log("AXI Lite MUX ROUTER Benchmarks Completed! Check logs in out/axi_lite_mux_router_benchmarks.log\n")

def run_axi_lite_default_demux():
    os.system(f"python3 create_testbench.py axi_router_top axi_demux > /dev/null 2>&1")
    os.system(f"cp {SCRIPTS_DIR}/run_axi_veri.sh {AXI_BASE}/")
    os.chdir(AXI_BASE)
    os.system(f"bash run_axi_veri.sh axi_router_top >> {OUT_DIR}/axi_lite_demux_router_benchmarks.log 2>&1")

def axi_lite_demux_router_benchmarks():
    print_log("Running AXI Lite DEMUX ROUTER Benchmarks...")
    os.chdir(AXI)
    os.system("make clean > /dev/null 2>&1")
    os.system(f"echo \"====Running AXI Lite DEMUX ROUTER Testbench for Anvil======== \\n\\n\\n \" > {OUT_DIR}/axi_lite_demux_router_benchmarks.log 2>&1")
    print_log("Running AXI Lite DEMUX ROUTER Testbench for Anvil")
    os.system(f"make run SILENT=1 MODULE_NAME=axi_router_top >> {OUT_DIR}/axi_lite_demux_router_benchmarks.log 2>&1")
    os.system(f"echo \"====Running AXI Lite DEMUX ROUTER Testbench for SV(Baseline)========\\n\\n\\n \" >> {OUT_DIR}/axi_lite_demux_router_benchmarks.log 2>&1")
    print_log("Running AXI Lite DEMUX ROUTER Testbench for SV(Baseline)")
    run_axi_lite_default_demux()
    print_log("AXI Lite DEMUX ROUTER Benchmarks Completed! Check logs in out/axi_lite_demux_router_benchmarks.log\n")


def run_filament_benchmarks():
    print_log("Running Filament Benchmarks...")
    os.chdir(f"{FILAMENT}/sv_files")
    os.system("make clean > /dev/null 2>&1")
    os.system(f"make run SILENT=1 all > {OUT_DIR}/filament_benchmarks.log 2>&1")
    print_log("Filament Benchmarks Completed! Check logs in out/filament_benchmarks.log\n")

def run_cva6_benchmarks():
    print_log("Running CVA6 Benchmarks...")
    os.chdir(SCRIPTS_DIR)
    date = os.popen("date +%Y-%m-%d").read().strip()
    os.system(f"echo \"====Running CVA6 with baseline (SV)======== \\n\\n\\n \" > {OUT_DIR}/cva6_benchmarks.log 2>&1")
    print_log("Running CVA6 with baseline (SV)")
    os.system(f"rm -rf {CVA6_DIR}/verif/sim/out_*")
    os.system(f"bash run-cva6-tests.sh > /dev/null 2>&1")
    os.system(f"cat {CVA6_DIR}/verif/sim/out_{date}/iss_regr.log >> {OUT_DIR}/cva6_benchmarks.log")
    os.system(f"rm -rf {CVA6_DIR}/verif/sim/out_*")
    os.system(f"echo \"\\n\\n====Running CVA6 with Anvil PTW and TLB======== \\n\\n\\n \" >> {OUT_DIR}/cva6_benchmarks.log 2>&1")
    print_log("Running CVA6 with Anvil PTW and TLB\n")
    os.system(f"bash run-cva6-tests.sh --anvil > /dev/null 2>&1")
    os.system(f"cat {CVA6_DIR}/verif/sim/out_{date}/iss_regr.log >> {OUT_DIR}/cva6_benchmarks.log")
    date = os.popen("date +%Y-%m-%d").read().strip()


def run_aes_default():
    os.system(f"python3 create_testbench.py aes_cipher_core_tb  aes_cipher_core --cleanup  > /dev/null 2>&1")
    os.system(f"cp {SCRIPTS_DIR}/run_testbench.sh {AES_SRC}/")
    os.chdir(AES_SRC)
    os.system(f"bash run_testbench.sh aes_cipher_core_tb >> {OUT_DIR}/aes_benchmarks.log 2>&1")

def run_aes_benchmarks():
    print_log("Running AES Benchmarks...")
    os.chdir(AES_ANVIl)
    os.system("make clean > /dev/null 2>&1")
    os.system(f"echo \"====Running AES Testbench for Anvil======== \\n\\n\\n \" > {OUT_DIR}/aes_benchmarks.log 2>&1")
    print_log("Running AES Testbench for Anvil")
    os.system(f"make run SILENT=1 MODULE_NAME=aes_cipher_core_tb >> {OUT_DIR}/aes_benchmarks.log 2>&1")    
    os.system(f"echo \"====Running AES Testbench for SV(Baseline)========\\n\\n\\n \" >> {OUT_DIR}/aes_benchmarks.log 2>&1")
    print_log("Running AES Testbench for SV(Baseline)")
    run_aes_default()
    print_log("AES Benchmarks Completed! Check logs in out/aes_benchmarks.log\n")
def get_input(msg):
    input(f"{Yellow}[Input] " + msg + " Press Enter to continue...")

def print_line():
    print(f"{RED}======================================================================================================================={RED}\n")

    
if __name__ == "__main__":

    print_log(f"{Blue}Interactive Script for Running Artefacts{Blue}\n")

#   1. FIFO
    print_line()
    get_input("Starting FIFO Benchmarks: (Expected < 1 min) ")
    fifo_benchmarks()
    print_line()

#   2. Spill Register
    print_line()
    get_input("Starting Spill Register Benchmarks: (Expected < 1 min) ")
    spill_register_benchmarks()
    print_line()

#   3. Stream FIFO
    print_line()
    get_input("Starting Stream FIFO Benchmarks: (Expected < 1 min) ")
    stream_fifo_benchmarks()
    print_line()

# 4. Filament Benchmarks
    print_line()
    get_input("Starting Filament Benchmarks: (Expected < 1 min) ")
    run_filament_benchmarks()
    print_line()

#5  AXI Lite MUX ROUTER

    print_line()
    get_input("Starting AXI Lite MUX ROUTER Benchmarks: (Expected < 3 min) ")
    axi_lite_mux_router_benchmarks()
    print_line()    

#6  AXI Lite DEMUX ROUTER
    print_line()
    get_input("Starting AXI Lite DEMUX ROUTER Benchmarks: (Expected < 3 min) ")
    axi_lite_demux_router_benchmarks()
    print_line()

#7. AES Benchmarks
    print_line()
    get_input("Starting AES Benchmarks: (Expected < 3 min) ")
    run_aes_benchmarks()
    print_line()

# 7. CVA6 Benchmarks
    print_line()
    get_input("Starting CVA6 Benchmarks: (Expected < 10 min) ")
    run_cva6_benchmarks()
    print_line()

    print_log(f"{Blue}All Benchmarks Completed!")

