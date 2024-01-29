
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
    assign add = 0;
    assign sub = 0;
    
    fmuldiv#(svfloat::float32, "mul") fmul(clk, lhs, rhs, mul);
    fmuldiv#(svfloat::float32, "div") fdiv(clk, lhs, rhs, div);
endmodule
