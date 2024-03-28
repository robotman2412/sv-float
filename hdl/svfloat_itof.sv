
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps



// Fixed-point integer to floating-point number converter.
module svfloat_itof#(
    // Floating-point type as described in the README.
    type                float       = svfloat::float32,
    // Total number of bits.
    parameter   integer width       = 32,
    // Optional number of fractional bits.
    parameter   integer frac        = 0
)(
    // Integer to convert.
    input  wire [width-1:0] in,
    // Input integer is signed.
    input  wire             issigned,
    // Floating-point representation.
    output float            out
);
    genvar x;
    
    // Number of bits required to represent true exponent.
    localparam  integer ewidth      = $clog2(width) + 1 > $bits(out.exponent) + 1 ? $clog2(width) + 1 : $bits(out.exponent) + 1;
    
    // Unsigned version.
    wire                sign = issigned && in[width-1];
    wire [width-1:0]    tmp  = sign ? -in : in;
    
    // Output packer.
    svfloat_packer#(float, ewidth, width, frac) packer(0, 0, 0, sign, 0, tmp, out);
endmodule
