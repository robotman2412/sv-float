
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps



// Floating-point divider.
// Shorthand for `svfloat_divdiv#(.mode("div"))`.
module svfloat_div#(
    // Floating-point type as described in the README.
    type                float           = svfloat::float32,
    // Enable pipeline register before divtiplier.
    parameter   bit     plr_pre_div     = 0,
    // Enable pipeline register after divtiplier.
    parameter   bit     plr_post_div    = 0
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
    svfloat_muldiv#(float, "div", plr_pre_div, plr_post_div) div(
        clk, lhs, rhs, res
    );
endmodule
