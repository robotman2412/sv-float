
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include <math.h>
#include <string.h>

#define SIM_EXEC "obj_dir/sim"

char  floatbuf[128];
float test[] = {
    NAN,
    -NAN,
    INFINITY,
    -INFINITY,
    0.0f,
    -0.0f,
    1.0f,
    -1.0f,
    3.4028234663852886e+38,
    -3.4028234663852886e+38,
    1.401298464324817e-45,
    -1.401298464324817e-45,
};
size_t test_len = sizeof(test) / sizeof(float);

#define TEST_CASE(oper, func, fd)                                                                                      \
    fprintf(fd, "\n");                                                                                                 \
    fprintf(fd, "\"" #oper "\"");                                                                                      \
    for (size_t x = 0; x < test_len; x++) {                                                                            \
        fprintf(fd, ";%s", ftos(test[x]));                                                                             \
    }                                                                                                                  \
    fprintf(fd, "\n");                                                                                                 \
    for (size_t y = 0; y < test_len; y++) {                                                                            \
        fprintf(fd, "%s", ftos(test[y]));                                                                              \
        for (size_t x = 0; x < test_len; x++) {                                                                        \
            fprintf(fd, ";%s", func(test[y], test[x]));                                                                \
        }                                                                                                              \
        fprintf(fd, "\n");                                                                                             \
    }

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

static inline char const *c_mul(float a, float b) {
    return ftos(a * b);
}
static inline char const *c_div(float a, float b) {
    return ftos(a / b);
}
static inline char const *c_add(float a, float b) {
    return ftos(a + b);
}
static inline char const *c_sub(float a, float b) {
    return ftos(a - b);
}

typedef struct {
    float mul, div, add, sub;
} sim_res_t;

static sim_res_t run_sim(float a, float b) {
    uint32_t bits_a = *(uint32_t *)&a;
    uint32_t bits_b = *(uint32_t *)&b;

    // Run simulation.
    char pathbuf[128];
    snprintf(pathbuf, sizeof(pathbuf) - 1, "build/0x%08x/0x%08x.txt", bits_a, bits_b);
    char sysbuf[512];
    snprintf(sysbuf, sizeof(sysbuf) - 1, "mkdir -p build/0x%08x", bits_a);
    system(sysbuf);
    snprintf(sysbuf, sizeof(sysbuf) - 1, "%s %s %s.fst %08x %08x", SIM_EXEC, pathbuf, pathbuf, bits_a, bits_b);
    system(sysbuf);
    FILE *fd = fopen(pathbuf, "r");
    if (!fd) {
        printf("Unable to read %s\n", pathbuf);
        exit(1);
    }

    // Parse file.
    uint32_t bits_mul, bits_div, bits_add, bits_sub;
    int      res = fscanf(fd, "0x%08x 0x%08x 0x%08x 0x%08x\n", &bits_mul, &bits_div, &bits_add, &bits_sub);
    if (res != 4) {
        printf("Unable to parse %s\n", pathbuf);
        perror("");
        exit(1);
    }
    fclose(fd);

    return (sim_res_t){
        *(float *)&bits_mul,
        *(float *)&bits_div,
        *(float *)&bits_add,
        *(float *)&bits_sub,
    };
}

static inline char const *sim_mul(float a, float b) {
    return ftos(run_sim(a, b).mul);
}
static inline char const *sim_div(float a, float b) {
    return ftos(run_sim(a, b).div);
}
static inline char const *sim_add(float a, float b) {
    return ftos(run_sim(a, b).add);
}
static inline char const *sim_sub(float a, float b) {
    return ftos(run_sim(a, b).sub);
}

static inline char const *diff(int *diffptr, float x, float q) {
    uint32_t bits_x = *(uint32_t *)&x;
    uint32_t bits_q = *(uint32_t *)&q;
    if (bits_x == bits_q) {
        return "";
    } else if (isnan(x) && isnan(q) && (((bits_x ^ bits_q) & 0x80000000) != 0)) {
        (*diffptr)++;
        return "sign";
    } else if (isnan(x) && isnan(q) && (bits_x != bits_q)) {
        return "enc";
    } else if (isnan(x) && isnan(q)) {
        return "";
    } else if (bits_x == (bits_q ^ 0x80000000)) {
        (*diffptr)++;
        return "sign";
    } else if (isnan(x) && isinf(q)) {
        (*diffptr)++;
        return "nan/inf";
    } else if (isnan(q) && isinf(x)) {
        (*diffptr)++;
        return "inf/nan";
    } else {
        (*diffptr)++;
        return "value";
    }
}

static int diffcount_mul = 0;
static int diffcount_div = 0;
static int diffcount_add = 0;
static int diffcount_sub = 0;

static inline char const *diff_mul(float a, float b) {
    return diff(&diffcount_mul, a * b, run_sim(a, b).mul);
}
static inline char const *diff_div(float a, float b) {
    return diff(&diffcount_div, a / b, run_sim(a, b).div);
}
static inline char const *diff_add(float a, float b) {
    return diff(&diffcount_add, a + b, run_sim(a, b).add);
}
static inline char const *diff_sub(float a, float b) {
    return diff(&diffcount_sub, a - b, run_sim(a, b).sub);
}

int main(int argc, char **argv) {
    FILE *fd = fopen("build/expected.csv", "w");
    if (!fd)
        return 1;
    TEST_CASE(*, c_mul, fd)
    TEST_CASE(/, c_div, fd)
    TEST_CASE(+, c_add, fd)
    TEST_CASE(-, c_sub, fd)
    fflush(fd);
    fclose(fd);

    fd = fopen("build/result.csv", "w");
    if (!fd)
        return 1;
    TEST_CASE(*, sim_mul, fd)
    TEST_CASE(/, sim_div, fd)
    TEST_CASE(+, sim_add, fd)
    TEST_CASE(-, sim_sub, fd)
    fflush(fd);
    fclose(fd);

    fd = fopen("build/difference.csv", "w");
    if (!fd)
        return 1;
    TEST_CASE(*, diff_mul, fd)
    TEST_CASE(/, diff_div, fd)
    TEST_CASE(+, diff_add, fd)
    TEST_CASE(-, diff_sub, fd)
    fflush(fd);
    fclose(fd);

    printf(
        "Number of differences:\nMul: %d\nDiv: %d\nAdd: %d\nSub: %d\n",
        diffcount_mul,
        diffcount_div,
        diffcount_add,
        diffcount_sub
    );

    return 0;
}
