
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps



// Floating-point normalizer.
module svfloat_normalizer#(
    // Floating-point type as described in the README.
    type                float       = svfloat::float32,
    // Width of the input exponent.
    parameter   integer ewidth      = 9,
    // Width of the input mantissa.
    parameter   integer width       = 46,
    // Fractional part width.
    parameter   integer frac        = 23
)(
    // Override: Infinity.
    input  logic                    is_inf,
    // Override: NaN.
    input  logic                    is_nan,
    // Override: Zero.
    input  logic                    is_zero,
    
    // Sign of the float.
    input  logic                    d_sign,
    // Unbiased exponent to normalize.
    input  logic signed[ewidth-1:0] d_exp,
    // Mantissa to normalize.
    input  logic       [width-1:0]  d_man,
    
    // Result.
    output float                    res
);
    genvar x;
    
    // Exponent width.
    localparam  integer exp_width       = $bits(res.exponent);
    // Mantissa width.
    localparam  integer man_width       = $bits(res.mantissa);
    // Exponent bias.
    localparam  integer exp_bias        = (1 << ($bits(res.exponent) - 1)) - 1;
    // Maximum stored exponent value.
    localparam  integer exp_max         = (1 << $bits(res.exponent)) - 1;
    // Maximum true exponent value.
    localparam  integer max_texp        = exp_max - 1 - exp_bias;
    // Minimum true exponent value.
    localparam  integer min_texp        = 1 - exp_bias;
    
    // Most significant set bit in the input mantissa.
    logic       [width-1:0]         msb_mask;
    generate
        for (x = 0; x < width - 1; x = x + 1) begin
            assign msb_mask[x] = d_man[x] && d_man[width-1:x+1] == 0;
        end
        assign msb_mask[width-1] = d_man[width-1];
    endgenerate
    // Index of the most significant bit.
    logic       [$clog2(width)-1:0] msb;
    always @(*) begin
        integer i;
        msb = 0;
        for (i = 0; i < width; i = i + 1) begin
            msb |= i * msb_mask[i];
        end
    end
    
    // Widen exponent.
    wire  signed[exp_width+1:0]     w_exp   = d_exp;
    // Amount to shift left input to create true mantissa.
    wire  signed[$clog2(width)-1:0] shl     = man_width - msb;
    // Normalized true exponent.
    wire  signed[exp_width+1:0]     exp     = w_exp - frac + msb;
    // Normalized true mantissa.
    wire        [man_width:0]       man     = shl > 0 ? d_man << shl : d_man >> -shl;
    
    // Output mux.
    always @(*) begin
        if (is_inf || is_nan) begin
            // Value overriden.
            res = '{d_sign, exp_max, is_nan};
        end else if (is_zero) begin
            // Value overridden.
            res = '{d_sign, 0, 0};
        end else if (exp > max_texp) begin
            // Edge case: Infinity.
            res = '{d_sign, exp_max, 0};
        end else if (d_man == 0) begin
            // Edge case: Zero.
            res = '{d_sign, 0, 0};
        end else if (exp < min_texp) begin
            // Edge case: Denormalized.
            res = '{d_sign, 0, man >> (min_texp - exp)};
        end else begin
            // Finite float.
            res = '{d_sign, exp + exp_bias, man};
        end
    end
endmodule
