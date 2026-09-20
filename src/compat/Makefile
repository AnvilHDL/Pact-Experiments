MODULE_NAME ?= top
TOP_MODULE ?= $(MODULE_NAME)
ANVIL ?= dune exec --root $(abspath ../../../Pact) pact --
VERILATOR_FLAGS ?= --top $(MODULE_NAME) -j 1

TEST_DRIVER = sim_main.cpp

all: obj_dir/V$(MODULE_NAME)

.PHONY: run clean debug
.DELETE_ON_ERROR:

ANVIL_FLAGS=
ifdef LTOFF
    ANVIL_FLAGS = -disable-lt-checks -O 2
else
    ANVIL_FLAGS = -O 2
endif

ifeq ($(DEBUG),1)
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

debug:
	python3 debug.py

ifeq ($(DEBUG),1)
$(MODULE_NAME).anvil.sv: debug
endif

obj_dir/V$(MODULE_NAME): $(MODULE_NAME)_driver.cpp $(MODULE_NAME).anvil.sv
ifdef LOG
	env OBJCACHE= verilator --cc --exe --build $(VERILATOR_FLAGS) $^ > /dev/null 2>&1
endif


$(MODULE_NAME).anvil.sv: $(MODULE_NAME).anvil
ifdef SILENT
	$(ANVIL) $(ANVIL_FLAGS) $(abspath $<) > $@ 2> $@.log || { cat $@.log >&2; exit 1; }
else ifdef LOG
	$(ANVIL) $(ANVIL_FLAGS) $(abspath $<) > $@ 2> compile.log
else
	$(ANVIL) $(ANVIL_FLAGS) $(abspath $<) > $@
endif

obj_dir/V$(MODULE_NAME): $(MODULE_NAME)_driver.cpp $(MODULE_NAME).anvil.sv
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
	rm -rf *.anvil.sv *_driver.cpp *.png *.dot *.log obj_dir *.out
