
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps



// Floating-point multiplier.
// Shorthand for `svfloat_muldiv#(.mode("mul"))`.
module svfloat_mul#(
    // Floating-point type as described in the README.
    type                float           = svfloat::float32,
    // Enable pipeline register before multiplier.
    parameter   bit     plr_pre_mul     = 0,
    // Enable pipeline register after multiplier.
    parameter   bit     plr_post_mul    = 0
)(
    // Pipeline clock.
    // Ignored if all pipeline registers are disabled.
    input  wire                 clk,
    
    // Left-hand side argument.
    input  float                lhs,
    // Right-hand side argument.
    input  float                rhs,
    // Result.
    output float                res
);
    svfloat_muldiv#(float, "mul", plr_pre_mul, plr_post_mul) mul(
        clk, lhs, rhs, res
    );
endmodule
