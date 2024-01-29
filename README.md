# SVFloat
An open-source SystemVerilog implementation of IEEE 754 and similar floating-point types.

## Floating-point types
SVFloat supports any floating-point type defined as a packed struct with sign, exponent and mantissa in that order. Four common types are defined: bfloat16, float16, float32 and float64, which are brain float and three sizes of IEEE 754 binary respectively.
