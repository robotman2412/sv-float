
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps



// Floating-point negator.
module svfloat_neg#(
    // Floating-point type as described in the README.
    type                float           = svfloat::float32
)(
    // Argument.
    input  float                val,
    // Negate the sign.
    input  wire                 neg,
    // Preserve sign on NaN.
    input  wire                 presv_nan,
    // Result.
    output float                res
);
    assign res = '{presv_nan && svfloat::ffunc#(float)::is_nan(val) ? val.sign : val.sign ^ neg, val.exponent, val.mantissa};
endmodule
