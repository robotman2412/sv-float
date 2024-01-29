
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps



// Most-significant bit index finder.
module svfloat_msb#(
    // Width of integer to check.
    parameter   integer width = 32,
    // Bit width of MSB index.
    parameter   integer exp   = $clog2(width)
)(
    // Integer to check.
    input  logic[width-1:0] raw,
    // Index of MSB, if any.
    output logic[exp-1:0]   msb
);
    genvar x;
    
    // Most significant bit.
    logic[width-1:0] msb_mask;
    
    generate
        for (x = 0; x < width - 1; x = x + 1) begin
            assign msb_mask[x] = raw[x] && raw[width-1:x+1] == 0;
        end
        assign msb_mask[width-1] = raw[width-1];
    endgenerate
    
    always @(*) begin
        integer i;
        msb = 0;
        for (i = 0; i < width; i = i + 1) begin
            msb |= i * msb_mask[i];
        end
    end
endmodule
