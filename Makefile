MODE ?= 3
JOBS ?= 4

.PHONY: check compat equiv

check:
	python3 scripts/check_types.py --jobs $(JOBS)

compat:
	python3 run_compat.py $(MODE) --jobs $(JOBS)

# These scripts share the PACT simulation build directory.
equiv:
	bash scripts/run_common_cells_cycle_equiv.sh
	bash scripts/run_axi_demux_read_cycle_equiv.sh
	bash scripts/run_axi_demux_write_cycle_equiv.sh
	bash scripts/run_axi_mux_read_cycle_equiv.sh
	bash scripts/run_axi_mux_write_cycle_equiv.sh
	bash scripts/run_ace_cycle_equiv.sh
	bash scripts/run_tilelink_cycle_equiv.sh
