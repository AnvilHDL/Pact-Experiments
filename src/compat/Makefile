MODULE_NAME ?= top
TOP_MODULE ?= $(MODULE_NAME)
PACT ?= $(abspath ../../scripts/pact)
VERILATOR_FLAGS ?= --top $(MODULE_NAME) -j 1

TEST_DRIVER = sim_main.cpp

all: obj_dir/V$(MODULE_NAME)

.PHONY: run clean
.DELETE_ON_ERROR:

# Optimisation level (as in synthesis).
PACT_OPT ?= 3
PACT_FLAGS=
ifdef LTOFF
    PACT_FLAGS = -disable-lt-checks -O $(PACT_OPT)
else
    PACT_FLAGS = -O $(PACT_OPT)
endif

ifeq ($(DEBUG),1)
	PACT_FLAGS += -verbose -verbose-max
endif

ifdef NOOPT
	PACT_FLAGS += -O 0
endif

ifdef SESSIONOFF
	PACT_FLAGS += -disable-session-checks
endif

ifdef COMPATOFF
	PACT_FLAGS += -disable-compat-checks
endif

ifdef WTC
	PACT_FLAGS += -weak-typecasts
endif

obj_dir/V$(MODULE_NAME): $(MODULE_NAME)_driver.cpp $(MODULE_NAME).pact.sv
ifdef LOG
	env OBJCACHE= verilator --cc --exe --build $(VERILATOR_FLAGS) $^ > /dev/null 2>&1
endif


$(MODULE_NAME).pact.sv: $(MODULE_NAME).anvil
ifdef SILENT
	$(PACT) $(PACT_FLAGS) $(abspath $<) > $@ 2> $@.log || { cat $@.log >&2; exit 1; }
else ifdef LOG
	$(PACT) $(PACT_FLAGS) $(abspath $<) > $@ 2> compile.log
else
	$(PACT) $(PACT_FLAGS) $(abspath $<) > $@
endif

obj_dir/V$(MODULE_NAME): $(MODULE_NAME)_driver.cpp $(MODULE_NAME).pact.sv
ifdef SILENT
	env OBJCACHE= verilator --cc --exe --build $(VERILATOR_FLAGS) $^ > /dev/null 2>/dev/null
else
	env OBJCACHE= verilator --cc --exe --build $(VERILATOR_FLAGS) $^
endif

$(MODULE_NAME)_driver.cpp: $(TEST_DRIVER)
	sed "s/Vtop/V$(MODULE_NAME)/g" $< > $@

run: obj_dir/V$(MODULE_NAME)
	@ $< $(TIMEOUT)

clean:
	rm -rf *.pact.sv *_driver.cpp *.png *.dot *.log obj_dir *.out
