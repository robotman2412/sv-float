
#include "verilated.h"
#include "verilated_fst_c.h"
#include "Vtop.h"

int main(int argc, char **argv) {
    if (argc != 5) {
        printf("Usage: %s <outfile> <dumpfile> <lhs-hex> <rhs-hex>\n", *argv);
        return 1;
    }
    char    *endl;
    char    *endr;
    uint32_t lhs = strtoull(argv[3], &endl, 16);
    uint32_t rhs = strtoull(argv[4], &endr, 16);

    // Create contexts.
    VerilatedContext *contextp = new VerilatedContext;
    char             *dummy    = (char *)"sim";
    contextp->commandArgs(1, &dummy);
    Vtop          *top   = new Vtop{contextp};
    VerilatedFstC *trace = new VerilatedFstC();

    // Set up the trace.
    contextp->traceEverOn(true);
    top->trace(trace, 5);
    trace->open(argv[2]);

    // Run a number of clock cycles.
    top->lhs = lhs;
    top->rhs = rhs;
    for (int i = 0; i <= 10 && !contextp->gotFinish(); i++) {
        top->clk ^= 1;
        top->eval();
        trace->dump(i * 10);
    }

    FILE *fd = fopen(argv[1], "w");
    if (fd) {
        fprintf(fd, "0x%08x 0x%08x 0x%08x 0x%08x\n", top->mul, top->div, top->add, top->sub);
        fflush(fd);
        fclose(fd);
    } else {
        printf("Unable to write %s\n", argv[1]);
        perror("");
    }

    // Clean up.
    trace->close();

    return 0;
}
