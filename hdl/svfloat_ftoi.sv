
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps



// Floating-point number to fixed-point integer converter.
// NaN is treated as infinity, which is clipped to the maximum (un)signed value.
module svfloat_ftoi#(
    // Floating-point type as described in the README.
    type                float       = svfloat::float32,
    // Total number of bits.
    parameter   integer width       = 32,
    // Optional number of fractional bits.
    parameter   integer frac        = 0
)(
    // Floating-point number to convert.
    input  float            in,
    // Output integer is signed.
    input  logic            issigned,
    // Integer representation.
    output logic[width-1:0] out
);
    // Number of bits required to represent true exponent.
    localparam  integer ewidth      = $bits(in.exponent) + 1;
    // Number of bits required to represent true mantissa.
    localparam  integer mwidth      = $bits(in.mantissa) + 1;
    
    // True exponent.
    wire signed[ewidth-1:0]         exp;
    // True mantissa.
    logic      [mwidth-1:0]         man;
    // Special cases.
    logic is_zero, is_nan, is_inf;
    svfloat_unpacker#(float) unpacker(in, is_zero, is_nan, is_inf, exp, man);
    
    // Amount to shift left the mantissa.
    wire signed[ewidth-1:0]         shl = exp - mwidth + 1 + frac;
    // Unsigned value of number.
    wire       [width-1:0]          tmp = shl > 0 ? man << shl : man >> -shl;
    
    // Output mux.
    always @(*) begin
        if (is_nan || is_inf || exp >= width - 1) begin
            // Edge case: NaN / infinity / too big to fit.
            out[width-2:0] = 0;
            out[width-1] = issigned;
        end else begin
            // Representable as an integer.
            out = in.sign ? -tmp : tmp;
        end
    end
endmodule
