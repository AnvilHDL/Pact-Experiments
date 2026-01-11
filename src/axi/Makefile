MODULE_NAME ?= top
TOP_MODULE ?= $(MODULE_NAME)
VERILATOR_FLAGS ?= --top $(MODULE_NAME) -j 1

TEST_DRIVER = sim_main.cpp

all: obj_dir/V$(MODULE_NAME)

.PHONY: run clean

ANVIL_FLAGS=
ifdef LTOFF
    ANVIL_FLAGS = -disable-lt-checks -O 3
else
    ANVIL_FLAGS = -O 3
endif

ifdef DEBUG
	ANVIL_FLAGS += -verbose -verbose-max
endif

ifdef NOOPT
	ANVIL_FLAGS += -O 0
endif

ifdef SESSIONOFF
	ANVIL_FLAGS += -disable-session-checks
endif
ifdef COMPATOFF
	ANVIL_FLAGS += -disable-compat-checks
endif

ifdef WTC
	ANVIL_FLAGS += -weak-typecasts
endif

$(MODULE_NAME).anvil.sv: $(MODULE_NAME).anvil
ifdef LOG
	anvil $(ANVIL_FLAGS) $< > $@ 2> compile.log
else
	anvil $(ANVIL_FLAGS) $< > $@
endif

ifdef DEBUG
	python3 debug.py
endif

obj_dir/V$(MODULE_NAME): $(MODULE_NAME)_driver.cpp $(MODULE_NAME).anvil.sv
ifdef LOG
	verilator --cc --exe --build $(VERILATOR_FLAGS) $^ > /dev/null 2>&1


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
	rm -rf *.anvil.sv *_driver.cpp *.png *.dot *.log obj_dir