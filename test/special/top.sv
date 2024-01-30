
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps



module top(
    input  logic clk,
    
    input  logic[31:0]  lhs,
    input  logic[31:0]  rhs,
    
    output logic[31:0]  mul,
    output logic[31:0]  div,
    output logic[31:0]  add,
    output logic[31:0]  sub
);
    svfloat_mul fmul(clk, lhs, rhs, mul);
    svfloat_div fdiv(clk, lhs, rhs, div);
    svfloat_add fadd(clk, lhs, rhs, add);
    svfloat_sub fsub(clk, lhs, rhs, sub);
endmodule
