
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps

import svfloat::ffunc;



// Floating-point unpacker.
// Creates the true exponent and renormalizes the mantissa of denormalized floats.
module svfloat_unpacker#(
    // Floating-point type as described in the README.
    type                float       = svfloat::float32
)(
    // Float to unpack.
    input  float                    in,
    
    // Float is equal to +/- zero.
    output logic                    is_zero,
    // Float is NaN.
    output logic                    is_nan,
    // Float is infinity.
    output logic                    is_inf,
    
    // True exponent.
    output logic signed
    [ffunc#(float)::texp_width-1:0]   exp,
    // True mantissa.
    output logic
    [$bits(in.mantissa):0]          man
);
    genvar x;
    
    // Bit width of the stored exponent.
    localparam  integer exp_width   = $bits(in.exponent);
    // Bit width of the stored mantissa.
    localparam  integer man_width   = $bits(in.mantissa);
    // Exponent bias.
    localparam  integer exp_bias    = (1 << (exp_width - 1)) - 1;
    // Maximum stored exponent value.
    localparam  integer exp_max     = (1 << exp_width) - 1;
    
    // Special values.
    assign is_zero = in.exponent == 0       && in.mantissa == 0;
    assign is_nan  = in.exponent == exp_max && in.mantissa != 0;
    assign is_inf  = in.exponent == exp_max && in.mantissa == 0;
    
    // Most significant bit of the mantissa.
    logic[man_width-1:0] msb;
    svfloat_msb#(man_width) man_msb(in.mantissa, msb);
    
    // Exponent and mantissa logic.
    always @(*) begin
        if (in.exponent == 0) begin
            exp = 1 - exp_bias - man_width + msb;
            man = in.mantissa << (man_width - msb);
        end else begin
            exp = in.exponent - exp_bias;
            man = {1'b1, in.mantissa};
        end
    end
endmodule
