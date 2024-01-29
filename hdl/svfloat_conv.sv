
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps



// Fixed-point integer to floating-point number converter.
module itof#(
    // Floating-point type as described in the README.
    type                float       = svfloat::float32,
    // Total number of bits.
    parameter   integer width       = 32,
    // Optional number of fractional bits.
    parameter   integer frac        = 0
)(
    // Integer to convert.
    input  logic[width-1:0] in,
    // Input integer is signed.
    input  logic            issigned,
    // Floating-point representation.
    output float            out
);
    genvar x;
    
    // Number of bits required to represent true exponent.
    localparam  integer ewidth      = $clog2(width) > $bits(out.exponent) + 1 ? $clog2(width) : $bits(out.exponent) + 1;
    // Number of bits required to represent true mantissa.
    localparam  integer mwidth      = $bits(out.mantissa) + 1 > width ? $bits(out.mantissa) + 1 : width;
    // Exponent bias.
    localparam  integer bias        = (1 << ($bits(out.exponent) - 1)) - 1;
    // Maximum stored exponent.
    localparam  integer max_exp     = (1 << $bits(out.exponent)) - 1;
    // Maximum finite true exponent.
    localparam  integer max_texp    = max_exp - bias - 1;
    // Minimum finite true exponent.
    localparam  integer min_texp    = -bias + 1;
    
    // Unsigned version.
    wire                sign = issigned && in[width-1];
    wire [width-1:0]    tmp  = sign ? -in : in;
    logic[width-1:0]    msb_mask;
    generate
        for (x = 0; x < width-1; x = x + 1) begin
            assign msb_mask[x] = tmp[x] && tmp[width-1:x+1] == 0;
        end
        assign msb_mask[width-1] = tmp[width-1];
    endgenerate
    
    // Index of most significant set bit.
    logic[ewidth-1:0]   msb;
    always @(*) begin
        integer i;
        msb = 0;
        for (i = 0; i < width; i = i + 1) begin
            msb |= i * msb_mask[i];
        end
    end
    
    // True exponent.
    wire signed[ewidth-1:0]         exp = msb - frac;
    // Shift left number for mantissa.
    wire signed[$clog2(mwidth)+1:0] shl = $bits(out.mantissa) - msb;
    // True mantissa.
    wire       [mwidth-1:0]         man = shl > 0 ? tmp << shl : tmp >> -shl;
    
    // Output mux.
    always @(*) begin
        if (width - frac - 1 > max_texp && exp > max_texp) begin
            // Edge case: Infinity.
            out = '{sign, max_exp, 0};
        end else if (exp < min_texp) begin
            // Edge case: Denormalized number.
            out = '{sign, 0, man >> (min_texp - exp)};
        end else begin
            // Normal number.
            out = '{sign, exp + bias, man};
        end
    end
endmodule

// Floating-point number to fixed-point integer converter.
// NaN is treated as infinity, which is clipped to the maximum (un)signed value.
module ftoi#(
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
    // Exponent bias.
    localparam  integer bias        = (1 << ($bits(in.exponent) - 1)) - 1;
    // Maximum stored exponent.
    localparam  integer max_exp     = (1 << $bits(in.exponent)) - 1;
    
    // True exponent.
    wire signed[ewidth-1:0]         exp = in.exponent - bias;
    // True mantissa.
    logic      [width-1:0]          man;
    assign      man[width-1:mwidth]     = 0;
    assign      man[mwidth-1]           = in.exponent != 0;
    assign      man[mwidth-2:0]         = in.mantissa;
    // Amount to shift left the mantissa.
    wire signed[$clog2(mwidth)+1:0] shl = exp - $bits(in.mantissa) + frac;
    // Unsigned value of the integer.
    wire       [width-1:0]          tmp = shl > 0 ? (man << shl) : (man >> -shl);
    
    // Output mux.
    always @(*) begin
        if (in.exponent == max_exp || exp >= width - issigned) begin
            // Edge case: NaN / infinity / too big to fit.
            out[width-2:0] = -1;
            out[width-1]   = in.sign || !issigned;
        end else begin
            // Representable as an integer.
            out = issigned && in.sign ? -tmp : tmp;
        end
    end
endmodule
