
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps



module top(
    input  logic[31:0]  val,
    output logic[31:0]  uitof,
    output logic[31:0]  itof
);
    svfloat_itof ufconv(val, 0, uitof);
    svfloat_itof fconv(val, 1, itof);
endmodule
