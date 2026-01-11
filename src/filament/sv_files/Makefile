# List all top-level modules (each has its own .sv file)
TOPS = AluAnvil AluFil SAanvil SAfil

TEST_DRIVER = sim_main.cpp
VERILATOR_FLAGS = -j 1

all: $(TOPS:%=obj_dir/V%)

.PHONY: all clean run

# Build each top independently
obj_dir/V%: %.sv %_driver.cpp
	@echo "=== Building $* ==="
	verilator --cc --exe --build $(VERILATOR_FLAGS) --top $* $^ > /dev/null 2>/dev/null

# Generate driver file
%_driver.cpp: $(TEST_DRIVER)
	sed "s/Vtop/V$*/g" $< > $@

# Run every built simulation
run: $(TOPS:%=run-%)

run-%: obj_dir/V%
	@echo "=== Running $* ==="
	@obj_dir/V$* $(TIMEOUT)

clean:
	rm -rf *_driver.cpp obj_dir
