
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps



module top(
    input  logic[31:0]  val,
    output logic[31:0]  ftoi,
    output logic[31:0]  ftoui
);
    svfloat_ftoi fconv(val, 1, ftoi);
    svfloat_ftoi ufconv(val, 0, ftoui);
endmodule
