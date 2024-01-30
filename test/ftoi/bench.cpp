
#include "verilated.h"
#include "verilated_fst_c.h"
#include "Vtop.h"

#include <stdio.h>

#include <math.h>

float test[] = {
    NAN,
    -NAN,
    INFINITY,
    -INFINITY,
    0.0f,
    -0.0f,
    1.0f,
    -1.0f,
    129.0f,
    -129.0f,
    3.4028234663852886e+38,
    -3.4028234663852886e+38,
    1.401298464324817e-45,
    -1.401298464324817e-45,
};
int test_len = sizeof(test) / sizeof(float);

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
    fprintf(fd, "float;exp;uexp;res;ures\n");
    for (int i = 0; i <= test_len; i++) {
        top->val = *(uint32_t *)&test[i];
        top->eval();
        trace->dump(i * 10);
        fprintf(fd, "%s", ftos(test[i]));
        fprintf(fd, ";\"%+d\"", (int)test[i]);
        fprintf(fd, ";\"+%u\"", (unsigned int)test[i]);
        fprintf(fd, ";\"%+d\"", *(int *)&top->ftoi);
        fprintf(fd, ";\"+%u\"\n", *(unsigned int *)&top->ftoui);
    }

    fclose(fd);

    // Clean up.
    trace->close();

    return 0;
}
