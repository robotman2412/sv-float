
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps



// Optionally pipelined floating-point subtractor.
// Shorthand for negation of RHS preserving NaN and addition.
module svfloat_sub#(
    // Floating-point type as described in the README.
    type                float           = svfloat::float32,
    // Enable pipeline register before adder.
    parameter   bit     plr_pre_add     = 0,
    // Enable pipeline register after adder.
    parameter   bit     plr_post_add    = 0
)(
    // Pipeline clock.
    // Ignored if all pipeline registers are disabled.
    input  logic                clk,
    
    // Left-hand side argument.
    input  float                lhs,
    // Right-hand side argument.
    input  float                rhs,
    // Result.
    output float                res
);
    float nrhs;
    svfloat_neg#(float) fneg(rhs, 1, 1, nrhs);
    svfloat_add#(float, plr_pre_add, plr_post_add) fadd(clk, lhs, nrhs, res);
endmodule
