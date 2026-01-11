MODULE_NAME ?= top
TOP_MODULE ?= $(MODULE_NAME)
VERILATOR_FLAGS ?= --top $(MODULE_NAME) -j 1

TEST_DRIVER = sim_main.cpp

all: obj_dir/V$(MODULE_NAME)

.PHONY: run clean

ifdef LTOFF
    ANVIL_FLAGS = -disable-lt-checks -O 3
else
    ANVIL_FLAGS = -O 3
endif



$(MODULE_NAME).anvil.sv: $(MODULE_NAME).anvil
ifdef SILENT
	anvil $(ANVIL_FLAGS) $< > $@ 2>/dev/null
else
	anvil $(ANVIL_FLAGS) $< > $@
endif

obj_dir/V$(MODULE_NAME): $(MODULE_NAME)_driver.cpp $(MODULE_NAME).anvil.sv
ifdef SILENT
	verilator --cc --exe --build $(VERILATOR_FLAGS) $^ > /dev/null 2>/dev/null
else
	verilator --cc --exe --build $(VERILATOR_FLAGS) $^
endif

$(MODULE_NAME)_driver.cpp: $(TEST_DRIVER)
	sed "s/Vtop/V$(MODULE_NAME)/g" $< > $@

run: obj_dir/V$(MODULE_NAME)
	@ $< $(TIMEOUT)

clean:
	rm -rf *.anvil.sv *_driver.cpp obj_dir