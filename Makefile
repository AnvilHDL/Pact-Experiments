SV_JOBS ?= 4
JOBS ?= 4

.PHONY: all compat modelcheck synthesis equiv check

# Every experiment, shortest first.
all: synthesis equiv compat modelcheck

# Pact compatibility-checking time (mode 3, 1 and 8 threads).
compat:
	python3 scripts/run_timing.py --part pact

# SymbiYosys model checking of the SystemVerilog designs (30 runs, up to 2 h each).
modelcheck:
	python3 scripts/run_timing.py --part sv --sv-jobs $(SV_JOBS)

# Area and timing of Pact and SystemVerilog designs on sky130 cells.
synthesis:
	python3 scripts/run_synthesis.py

# Cycle-level trace comparison of every Pact design with its SystemVerilog design.
# These scripts share the Pact simulation build directory.
equiv:
	bash scripts/run_common_cells_cycle_equiv.sh
	bash scripts/run_axi_demux_read_cycle_equiv.sh
	bash scripts/run_axi_demux_write_cycle_equiv.sh
	bash scripts/run_axi_mux_read_cycle_equiv.sh
	bash scripts/run_axi_mux_write_cycle_equiv.sh
	bash scripts/run_ace_cycle_equiv.sh
	bash scripts/run_tilelink_cycle_equiv.sh

# Session type check of every benchmark process against its interfaces.
check:
	python3 scripts/check_types.py --jobs $(JOBS)
