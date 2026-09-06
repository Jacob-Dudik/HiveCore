#include <iostream>
#include <iomanip>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vcore_top.h"
#include "Vcore_top___024root.h"

void print_regs(Vcore_top* top) {
    std::cout << "--- Register File ---" << std::endl;
    for (int i = 0; i < 32; i++) {
        uint64_t val = top->rootp->core_top__DOT__u_decode__DOT__regfile__DOT__regs[i];
        
        std::cout << "x" << std::dec << std::setw(2) << std::setfill('0') << i << ": 0x" 
                  << std::hex << std::setw(16) << std::setfill('0') << val;
        if ((i + 1) % 4 == 0) {
            std::cout << std::endl;
        } else {
            std::cout << "    ";
        }
    }
    std::cout << "---------------------" << std::endl;
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);

    Vcore_top* top = new Vcore_top;
    VerilatedVcdC* tfp = new VerilatedVcdC;

    top->trace(tfp, 99);
    tfp->open("core_top.vcd");

    top->clk = 0;
    top->rst_n = 0;
    top->ext_flush_i = 0;

    int time = 0;
    
    // Hold reset for 5 cycles
    while (time < 10) {
        top->clk = !top->clk;
        top->eval();
        tfp->dump(time);
        time++;
    }

    top->rst_n = 1;

    std::cout << "\n[Before Simulation]" << std::endl;
    print_regs(top);

    bool ecall_detected = false;
    int ecall_wait_cycles = 0;

    // Run simulation (increased timeout for longer tests)
    while (time < 100000 && !Verilated::gotFinish()) {
        top->clk = !top->clk;
        top->eval();
        tfp->dump(time);
        
        // Evaluate logic on the rising edge
        if (top->clk == 1 && top->rst_n == 1) {
            // Check if ecall (0x00000073) is in the decode stage
            if (!ecall_detected && top->rootp->core_top__DOT__if_id_valid && top->rootp->core_top__DOT__if_id_instr == 0x00000073) {
                ecall_detected = true;
                ecall_wait_cycles = 5; // Wait 5 cycles to ensure previous instructions finish writing to the register file
            }
            
            if (ecall_detected) {
                if (ecall_wait_cycles == 0) {
                    uint64_t x3 = top->rootp->core_top__DOT__u_decode__DOT__regfile__DOT__regs[3];
                    std::cout << "\n===================================" << std::endl;
                    if (x3 == 1) {
                        std::cout << "[TEST RESULT] PASS!" << std::endl;
                    } else {
                        std::cout << "[TEST RESULT] FAIL at test case " << std::dec << (x3 >> 1) << std::endl;
                    }
                    std::cout << "===================================" << std::endl;
                    break; // End simulation
                }
                ecall_wait_cycles--;
            }
        }
        
        time++;
    }

    std::cout << "\n[After Simulation]" << std::endl;
    print_regs(top);

    std::cout << "\nSimulation complete at time " << time << "! Open core_top.vcd in GTKWave to view the registers." << std::endl;

    tfp->close();
    delete top;
    delete tfp;
    return 0;
}
