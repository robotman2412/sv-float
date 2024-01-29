
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps

import svfloat::ffunc;



// Optionally pipelined floating-point multiplier.
module fmuldiv#(
    // Floating-point type as described in the README.
    type                float           = svfloat::float32,
    // Operating mode, either "mul" or "div".
    parameter   string  mode            = "mul",
    // Enable pipeline register before multiplier / divider.
    parameter   bit     plr_pre_mul     = 0,
    // Enable pipeline register after multiplier / divider.
    parameter   bit     plr_post_mul    = 0
)(
    // Pipeline clock.
    // Ignored if all pipeline registers are disabled.
    input  logic                clk,
    
    // Left-hand side argument.
    input  float                lhs,
    // Right-hand side argument.
    input  float                rhs,
    // Result.
    output float                res
);
    // Exponent width.
    localparam  integer exp_width       = $bits(lhs.exponent);
    // Mantissa width.
    localparam  integer man_width       = $bits(lhs.mantissa);
    // Exponent bias.
    localparam  integer exp_bias        = (1 << ($bits(lhs.exponent) - 1)) - 1;
    // Maximum stored exponent value.
    localparam  integer exp_max         = (1 << $bits(res.exponent)) - 1;
    // Multiplier result width.
    localparam  integer mul_width       = (man_width + 1) * 2;
    
    /* ==== Stage 1: Argument preparation ==== */
    // Result will be infinity.
    logic                       s1_is_inf;
    // Result will be NaN.
    logic                       s1_is_nan;
    // Result will be zero.
    logic                       s1_is_zero;
    // Result sign.
    logic                       s1_sign;
    // True exponent of left-hand side.
    wire  signed[exp_width:0]   s1_lhs_exp  = lhs.exponent - exp_bias;
    // True exponent of right-hand side.
    wire  signed[exp_width:0]   s1_rhs_exp  = rhs.exponent - exp_bias;
    // True exponent of result before multiplier.
    wire  signed[exp_width:0]   s1_res_exp  = s1_lhs_exp + s1_rhs_exp;
    // Normalized mantissa of left-hand side.
    wire        [man_width:0]   s1_lhs_man  = {lhs.exponent != 0, lhs.mantissa};
    // Normalized mantissa of right-hand side.
    wire        [man_width:0]   s1_rhs_man  = {rhs.exponent != 0, rhs.mantissa};
    
    // Special cases.
    generate
        if (mode == "mul") begin: sc_mul
            assign s1_res_exp = s1_lhs_exp + s1_rhs_exp;
            // Multiplication special cases.
            always @(*) begin
                s1_sign = lhs.sign ^ rhs.sign;
                if (ffunc#(float)::is_nan(lhs)) begin
                    // Multiplication by NaN.
                    s1_is_nan  = 1;
                    s1_is_inf  = 'bx;
                    s1_is_zero = 0;
                    s1_sign    = lhs.sign;
                end else if (!ffunc#(float)::is_nan(lhs) && ffunc#(float)::is_nan(rhs)) begin
                    // Multiplication by NaN.
                    s1_is_nan  = 1;
                    s1_is_inf  = 'bx;
                    s1_is_zero = 0;
                    s1_sign    = rhs.sign;
                end else if (ffunc#(float)::is_inf(lhs) && rhs.exponent == 0 && rhs.mantissa == 0) begin
                    // Multiplication of zero and inifity.
                    s1_is_nan  = 1;
                    s1_is_inf  = 'bx;
                    s1_is_zero = 0;
                    s1_sign    = 1;
                end else if (ffunc#(float)::is_inf(rhs) && lhs.exponent == 0 && lhs.mantissa == 0) begin
                    // Multiplication of zero and inifity.
                    s1_is_nan  = 1;
                    s1_is_inf  = 'bx;
                    s1_is_zero = 0;
                    s1_sign    = 1;
                end else if (ffunc#(float)::is_inf(lhs) || ffunc#(float)::is_inf(rhs)) begin
                    // Multiplication by infinity.
                    s1_is_nan  = 0;
                    s1_is_inf  = 1;
                    s1_is_zero = 0;
                end else begin
                    // Finite multiplication.
                    s1_is_nan  = 0;
                    s1_is_inf  = 0;
                    s1_is_zero = 0;
                end
            end
        end else begin: sc_div
            assign s1_res_exp = s1_lhs_exp - s1_rhs_exp;
            // Division special cases.
            always @(*) begin
                s1_sign = lhs.sign ^ rhs.sign;
                if (ffunc#(float)::is_nan(lhs)) begin
                    // Multiplication of NaN.
                    s1_is_nan  = 1;
                    s1_is_inf  = 'bx;
                    s1_is_zero = 0;
                    s1_sign    = lhs.sign;
                end else if (!ffunc#(float)::is_nan(lhs) && ffunc#(float)::is_nan(rhs)) begin
                    // Multiplication by NaN.
                    s1_is_nan  = 1;
                    s1_is_inf  = 'bx;
                    s1_is_zero = 0;
                    s1_sign    = rhs.sign;
                end else if (lhs.exponent == 0 && lhs.mantissa == 0 && rhs.exponent == 0 && rhs.mantissa == 0) begin
                    // Division of zero by zero.
                    s1_is_nan  = 1;
                    s1_is_inf  = 'bx;
                    s1_is_zero = 0;
                    s1_sign    = 1;
                end else if (rhs.exponent == 0 && rhs.mantissa == 0) begin
                    // Division by zero.
                    s1_is_nan  = 0;
                    s1_is_inf  = 1;
                    s1_is_zero = 0;
                end else if (ffunc#(float)::is_inf(lhs) && ffunc#(float)::is_inf(rhs)) begin
                    // Division of infinity by infinity.
                    s1_is_nan  = 1;
                    s1_is_inf  = 'bx;
                    s1_is_zero = 0;
                    s1_sign    = 1;
                end else if (ffunc#(float)::is_inf(lhs)) begin
                    // Division of infinity by finite.
                    s1_is_nan  = 0;
                    s1_is_inf  = 1;
                    s1_is_zero = 0;
                end else if (ffunc#(float)::is_inf(rhs)) begin
                    // Division by inifinity.
                    s1_is_nan  = 0;
                    s1_is_inf  = 0;
                    s1_is_zero = 1;
                end else begin
                    // Finite division.
                    s1_is_nan  = 0;
                    s1_is_inf  = 0;
                    s1_is_zero = 0;
                end
            end
        end
    endgenerate
    
    /* ==== Stage 2: Multiplication ==== */
    // Buffer of the extracted parameters.
    logic                       s2_is_inf;
    logic                       s2_is_nan;
    logic                       s2_is_zero;
    logic                       s2_sign;
    logic signed[exp_width:0]   s2_res_exp;
    logic       [man_width:0]   s2_lhs_man;
    logic       [man_width:0]   s2_rhs_man;
    generate
        if (plr_pre_mul) begin
            always @(posedge clk) begin: s1s2_plr
                s2_is_inf   <= s1_is_inf;
                s2_is_nan   <= s1_is_nan;
                s2_is_zero  <= s1_is_zero;
                s2_sign     <= s1_sign;
                s2_res_exp  <= s1_res_exp;
                s2_lhs_man  <= s1_lhs_man;
                s2_rhs_man  <= s1_rhs_man;
            end
        end else begin: s1s2_comb
            assign s2_is_inf    = s1_is_inf;
            assign s2_is_nan    = s1_is_nan;
            assign s2_is_zero   = s1_is_zero;
            assign s2_sign      = s1_sign;
            assign s2_res_exp   = s1_res_exp;
            assign s2_lhs_man   = s1_lhs_man;
            assign s2_rhs_man   = s1_rhs_man;
        end
    endgenerate
    
    // Multiplication / division result.
    logic       [mul_width-1:0] s2_res_man;
    generate
        if (mode == "mul") begin: mul
            assign s2_res_man = s2_lhs_man * s2_rhs_man;
        end else begin: div
            wire[mul_width-1:0] s2_lhs_tmp = s2_lhs_man << man_width;
            assign s2_res_man = s2_lhs_tmp / s2_rhs_man;
        end
    endgenerate
    
    /* ==== Stage 3: Output normalization ==== */
    // Buffer of the multiplication result.
    logic                       s3_is_inf;
    logic                       s3_is_nan;
    logic                       s3_is_zero;
    logic                       s3_sign;
    logic signed[exp_width:0]   s3_res_exp;
    logic       [mul_width-1:0] s3_res_man;
    generate
        if (plr_pre_mul) begin
            always @(posedge clk) begin: s2s3_plr
                s3_is_inf   <= s2_is_inf;
                s3_is_nan   <= s2_is_nan;
                s3_is_zero  <= s2_is_zero;
                s3_sign     <= s2_sign;
                s3_res_exp  <= s2_res_exp;
                s3_res_man  <= s2_res_man;
            end
        end else begin: s2s3_comb
            assign s3_is_inf    = s2_is_inf;
            assign s3_is_nan    = s2_is_nan;
            assign s3_is_zero   = s2_is_zero;
            assign s3_sign      = s2_sign;
            assign s3_res_exp   = s2_res_exp;
            assign s3_res_man   = s2_res_man;
        end
    endgenerate
    
    // Normalization.
    localparam frac = (mode == "mul") ? (man_width*2) : (man_width);
    svfloat_normalizer#(float, exp_width+1, mul_width, frac) norm(
        s3_is_inf, s3_is_nan, s3_is_zero,
        s3_sign, s3_res_exp, s3_res_man,
        res
    );
endmodule