// Verilator driver for the Pact simulations, adapted from the Verilator examples
// (2017, Wilson Snyder, public domain).
// SPDX-License-Identifier: CC0-1.0

#include <memory>

#include <verilated.h>

#include "Vtop.h"

#if VM_TRACE
#include <verilated_vcd_c.h>
#endif

double sc_time_stamp() { return 0; }

// Usage: Vtop [timeout]; the timeout counts simulation steps (two per clock cycle).
int main(int argc, char** argv) {
    unsigned timeout = -1;
    if (argc > 1) {
        timeout = std::atoi(argv[1]);
    }

    Verilated::mkdir("logs");

    const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext};
    contextp->debug(0);
    contextp->randReset(2);
    contextp->traceEverOn(true);
    contextp->commandArgs(argc, argv);

    const std::unique_ptr<Vtop> top{new Vtop{contextp.get(), "TOP"}};

#if VM_TRACE
    std::unique_ptr<VerilatedVcdC> tfp{new VerilatedVcdC};
    top->trace(tfp.get(), 9999);
    tfp->open("logs/waveform.vcd");
    printf("Waveform tracing enabled. Output: logs/waveform.vcd\n");
#endif

    top->clk_i = 0;
    top->rst_ni = !0;

    unsigned time_cnt = 0;

    while (!contextp->gotFinish() && time_cnt < timeout) {
        contextp->timeInc(1);
        top->clk_i = !top->clk_i;

        // Reset is active low and changes on the falling edge.
        if (!top->clk_i) {
            if (contextp->time() > 1 && contextp->time() < 10) {
                top->rst_ni = !1;
            } else {
                top->rst_ni = !0;
            }
        }

        top->eval();

#if VM_TRACE
        tfp->dump(contextp->time());
#endif

        ++ time_cnt;
    }

#if VM_TRACE
    tfp->close();
#endif

    top->final();
    contextp->statsPrintSummary();

    return 0;
}
