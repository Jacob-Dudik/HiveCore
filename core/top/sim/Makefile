# ==============================================================================
# Makefile for HiveCore Verilator Simulation
# ==============================================================================

# Directories
ROOT_DIR := ../../..
CORE_DIR := $(ROOT_DIR)/core

# SystemVerilog Sources
# NOTE: Packages must be compiled first in order of dependency!
SV_SOURCES := $(CORE_DIR)/pkg/core_pkg.sv \
              $(CORE_DIR)/pkg/interface_struct_pkg.sv \
              $(CORE_DIR)/top/src/core_top.sv \
              $(CORE_DIR)/decode/src/*.sv \
              $(CORE_DIR)/execute/src/*.sv \
              $(CORE_DIR)/fetch/src/*.sv \
              $(CORE_DIR)/writeback/src/*.sv \
              $(CORE_DIR)/control/src/*.sv \
              $(CORE_DIR)/top/src/*.sv

# Include Paths
INCLUDES := -I$(CORE_DIR)/pkg \
            -I$(CORE_DIR)/common_rtl/fifos/sync_param_fifo/src \
            -I$(CORE_DIR)/decode/src \
            -I$(CORE_DIR)/execute/src \
            -I$(CORE_DIR)/fetch/src \
            -I$(CORE_DIR)/writeback/src \
            -I$(CORE_DIR)/control/src \
            -I$(CORE_DIR)/top/src

# Verilator Configuration
VFLAGS := -Wall -Wno-fatal --trace --top-module core_top

# Default target
all: build test-all

# 1. Compile SystemVerilog to C++ and Build the executable
build:
	@echo "========================================"
	@echo "Verilating the HiveCore Processor..."
	@echo "========================================"
	verilator $(VFLAGS) $(INCLUDES) --cc $(SV_SOURCES) --exe core_top_tb.cpp
	@echo "========================================"
	@echo "Compiling the C++ Simulation Model..."
	@echo "========================================"
	$(MAKE) -j -C obj_dir -f Vcore_top.mk

# Default test firmware
TEST ?= custom-test-hex/basic.hex

# 2. Run the simulation
run:
	@echo "========================================"
	@echo "Running the Simulation with test: $(TEST)"
	@echo "========================================"
	@cp $(TEST) firmware.hex
	./obj_dir/Vcore_top

# 3. Run ALL official tests automatically
test-all: build
	@echo "========================================"
	@echo "Running all RISC-V Official Tests..."
	@echo "========================================"
	@rm -f test_results.log
	@failed_tests=0; \
	for test_file in official-test-hex/*.hex; do \
		echo -n "Running $$test_file... "; \
		cp "$$test_file" firmware.hex; \
		output=`./obj_dir/Vcore_top`; \
		if echo "$$output" | grep -q "FAIL"; then \
			echo "FAIL ❌"; \
			echo "  --> $$test_file FAILED" >> test_results.log; \
			failed_tests=$$((failed_tests+1)); \
		elif echo "$$output" | grep -q "PASS"; then \
			echo "PASS ✅"; \
		else \
			echo "TIMEOUT/ERROR ❓"; \
			echo "  --> $$test_file TIMEOUT/ERROR" >> test_results.log; \
			failed_tests=$$((failed_tests+1)); \
		fi \
	done; \
	echo "========================================"; \
	if [ $$failed_tests -gt 0 ]; then \
		echo "$$failed_tests tests FAILED. See test_results.log for details:"; \
		cat test_results.log; \
	else \
		echo "All tests PASSED! 🎉"; \
	fi

# Clean build artifacts
clean:
	rm -rf obj_dir
	rm -f *.vcd
	rm -f firmware.hex
	rm -f *.log *.txt

.PHONY: all build run clean
disassemble:
	@python3 -c "with open('$(TEST)', 'r') as f: data = f.read().split(); open('.temp.bin', 'wb').write(bytes([int(x, 16) for x in data]))"
	@riscv64-unknown-elf-objdump -b binary -m riscv -M numeric -D .temp.bin
	@rm .temp.bin
