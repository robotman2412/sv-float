
#include "verilated.h"
#include "verilated_fst_c.h"
#include "Vtop.h"

#include <stdio.h>

#include <math.h>

int test[] = {
    0,
    -1,
    128,
    129,
    -400000,
    2000000000,
    -21005040,
    -2147483648,
    2147483647,
};
int test_len = sizeof(test) / sizeof(int);

char               floatbuf[128];
static char const *ftos(float value) {
    uint32_t bits = *(uint32_t *)&value;
    if (bits == 0x80000000) {
        strcpy(floatbuf, "\"-0\"");
    } else if (bits == 0x00000000) {
        strcpy(floatbuf, "\"+0\"");
    } else if (isfinite(value) && (value > 65536 || (value > 0 && value < 1))) {
        snprintf(floatbuf, sizeof(floatbuf) - 1, "\"+2^%d\"", (int)log2f(value));
    } else if (isfinite(value) && (value < -65536 || (value < 0 && value > -1))) {
        snprintf(floatbuf, sizeof(floatbuf) - 1, "\"-2^%d\"", (int)log2f(-value));
    } else {
        snprintf(floatbuf, sizeof(floatbuf) - 1, "\"%+f\"", value);
    }
    return floatbuf;
}

int main(int argc, char **argv) {
    // Create contexts.
    VerilatedContext *contextp = new VerilatedContext;
    char             *dummy    = (char *)"sim";
    contextp->commandArgs(1, &dummy);
    Vtop          *top   = new Vtop{contextp};
    VerilatedFstC *trace = new VerilatedFstC();

    // Set up the trace.
    contextp->traceEverOn(true);
    top->trace(trace, 5);
    trace->open("build/fconv.fst");

    FILE *fd = fopen("build/fconv.csv", "w");
    if (!fd)
        return 1;

    // Run a number of clock cycles.
    fprintf(fd, "int;uint;exp;uexp;res;ures\n");
    for (int i = 0; i <= test_len; i++) {
        top->val = test[i];
        top->eval();
        trace->dump(i * 10);
        fprintf(fd, "\"%+d\";\"+%u\"", test[i], (unsigned int)test[i]);
        fprintf(fd, ";%s", ftos((float)(int)test[i]));
        fprintf(fd, ";%s", ftos((float)(unsigned int)test[i]));
        fprintf(fd, ";%s", ftos(*(float *)&top->itof));
        fprintf(fd, ";%s\n", ftos(*(float *)&top->uitof));
    }

    fclose(fd);

    // Clean up.
    trace->close();

    return 0;
}
