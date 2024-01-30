
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps

import svfloat::ffunc;



// Optionally pipelined floating-point adder.
module svfloat_add#(
    // Floating-point type as described in the README.
    type                float           = svfloat::float32,
    // Enable pipeline register before adder.
    parameter   bit     plr_pre_add     = 0,
    // Enable pipeline register after adder.
    parameter   bit     plr_post_add    = 0
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
    // True exponent width.
    localparam  integer texp_width      = $clog2(2 ** (exp_width + 1) + $clog2(man_width));
    // Exponent bias.
    localparam  integer exp_bias        = (1 << ($bits(lhs.exponent) - 1)) - 1;
    // Maximum stored exponent value.
    localparam  integer exp_max         = (1 << $bits(res.exponent)) - 1;
    // Adder result width.
    // Mantissa width + normalized bit + 1 for rounding + 1 for sign.
    localparam  integer add_width       = man_width + 4;
    
    /* ==== Stage 1: Argument preparation ==== */
    // Result sign override.
    logic                           s1_sign_ovr;
    // Result will be infinity.
    logic                           s1_is_inf;
    // Result will be NaN.
    logic                           s1_is_nan;
    // Result will be zero.
    logic                           s1_is_zero;
    // True exponent of left-hand side.
    logic signed[texp_width-1:0]    s1_lhs_exp;
    // True exponent of right-hand side.
    logic signed[texp_width-1:0]    s1_rhs_exp;
    // Normalized mantissa of left-hand side.
    logic       [man_width:0]       s1_lhs_man;
    // Normalized mantissa of right-hand side.
    logic       [man_width:0]       s1_rhs_man;
    
    // Unpacking.
    logic lhs_is_zero, lhs_is_nan, lhs_is_inf;
    svfloat_unpacker#(float) unpack_lhs(
        lhs,
        lhs_is_zero, lhs_is_nan, lhs_is_inf,
        s1_lhs_exp, s1_lhs_man
    );
    logic rhs_is_zero, rhs_is_nan, rhs_is_inf;
    svfloat_unpacker#(float) unpack_rhs(
        rhs,
        rhs_is_zero, rhs_is_nan, rhs_is_inf,
        s1_rhs_exp, s1_rhs_man
    );
    
    // Addition special cases.
    always @(*) begin
        if (lhs_is_nan) begin
            // Addition of NaN.
            s1_is_nan   = 1;
            s1_is_inf   = 'bx;
            s1_is_zero  = 0;
            s1_sign_ovr = lhs.sign;
        end else if (!lhs_is_nan && rhs_is_nan) begin
            // Addition of NaN.
            s1_is_nan   = 1;
            s1_is_inf   = 'bx;
            s1_is_zero  = 0;
            s1_sign_ovr = rhs.sign;
        end else if (lhs_is_inf && rhs_is_inf && lhs.sign != rhs.sign) begin
            // Addition of opposite inifinities.
            s1_is_nan   = 1;
            s1_is_inf   = 'bx;
            s1_is_zero  = 0;
            s1_sign_ovr = 1;
        end else if (lhs_is_inf) begin
            // Addition of infinity.
            s1_is_nan   = 0;
            s1_is_inf   = 1;
            s1_is_zero  = 0;
            s1_sign_ovr = lhs.sign;
        end else if (rhs_is_inf) begin
            // Addition of infinity.
            s1_is_nan   = 0;
            s1_is_inf   = 1;
            s1_is_zero  = 0;
            s1_sign_ovr = rhs.sign;
        end else if (lhs_is_zero && rhs_is_zero && lhs.sign && rhs.sign) begin
            // Addition of -0 and -0.
            s1_is_nan   = 0;
            s1_is_inf   = 0;
            s1_is_zero  = 1;
            s1_sign_ovr = rhs.sign;
        end else begin
            // Finite addition.
            s1_is_nan   = 0;
            s1_is_inf   = 0;
            s1_is_zero  = 0;
            s1_sign_ovr = 'bx;
        end
    end
    
    /* ==== Stage 2: Addition ==== */
    // Buffer of the extracted parameters.
    logic                           s2_sign_ovr;
    logic                           s2_is_inf;
    logic                           s2_is_nan;
    logic                           s2_is_zero;
    logic                           s2_lhs_sign;
    logic signed[texp_width-1:0]    s2_lhs_exp;
    logic       [man_width:0]       s2_lhs_man;
    logic                           s2_rhs_sign;
    logic signed[texp_width-1:0]    s2_rhs_exp;
    logic       [man_width:0]       s2_rhs_man;
    generate
        if (plr_pre_add) begin: s1s2_plr
            always @(posedge clk) begin
                s2_sign_ovr <= s1_sign_ovr;
                s2_is_inf   <= s1_is_inf;
                s2_is_nan   <= s1_is_nan;
                s2_is_zero  <= s1_is_zero;
                s2_lhs_sign <= lhs.sign;
                s2_lhs_exp  <= s1_lhs_exp;
                s2_lhs_man  <= s1_lhs_man;
                s2_rhs_sign <= rhs.sign;
                s2_rhs_exp  <= s1_rhs_exp;
                s2_rhs_man  <= s1_rhs_man;
            end
        end else begin: s1s2_comb
            assign s2_sign_ovr  = s1_sign_ovr;
            assign s2_is_inf    = s1_is_inf;
            assign s2_is_nan    = s1_is_nan;
            assign s2_is_zero   = s1_is_zero;
            assign s2_lhs_sign  = lhs.sign;
            assign s2_lhs_man   = s1_lhs_man;
            assign s2_lhs_exp   = s1_lhs_exp;
            assign s2_rhs_sign  = rhs.sign;
            assign s2_rhs_man   = s1_rhs_man;
            assign s2_rhs_exp   = s1_rhs_exp;
        end
    endgenerate
    
    // Addition LHS shift left.
    logic signed[texp_width-1:0]    s2_lhs_shl;
    // Addition exponent difference.
    wire  signed[texp_width-1:0]    s2_exp_diff = s2_lhs_exp - s2_rhs_exp;
    // Addition LHS temporary.
    wire        [add_width-1:0]     s2_lhs_tmp  = s2_lhs_shl > 0 ? s2_lhs_man << s2_lhs_shl : s2_lhs_man >> -s2_lhs_shl;
    // Addition RHS shift left.
    logic signed[texp_width-1:0]    s2_rhs_shl;
    // Addition RHS temporary.
    wire        [add_width-1:0]     s2_rhs_tmp  = s2_rhs_shl > 0 ? s2_rhs_man << s2_rhs_shl : s2_rhs_man >> -s2_rhs_shl;
    // Addition result exponent.
    logic signed[texp_width-1:0]    s2_res_exp;
    always @(*) begin
        if (s2_lhs_exp > s2_rhs_exp) begin
            // LHS has bigger exponent.
            s2_res_exp = s1_lhs_exp;
            s2_lhs_shl = 1;
            s2_rhs_shl = 1 - s2_exp_diff;
        end else begin
            // RHS has bigger exponent.
            s2_res_exp = s1_rhs_exp;
            s2_lhs_shl = 1 + s2_exp_diff;
            s2_rhs_shl = 1;
        end
    end
    
    // Signed addition result temporary.
    logic signed[add_width-1:0]     s2_res_tmp;
    // Invert sign.
    logic                           s2_sign;
    // Addition result mantissa.
    wire        [add_width-1:0]     s2_res_man  = s2_sign ? -s2_res_tmp : s2_res_tmp;;
    always @(*) begin
        bit[add_width-1:0] lhs;
        bit[add_width-1:0] rhs;
        lhs         = s2_lhs_sign ? -s2_lhs_tmp : s2_lhs_tmp;
        rhs         = s2_rhs_sign ? -s2_rhs_tmp : s2_rhs_tmp;
        s2_res_tmp  = lhs + rhs;
        if (s2_is_inf || s2_is_nan || s2_is_zero) begin
            s2_sign     = s2_sign_ovr;
        end else begin
            s2_sign     = s2_res_tmp < 0;
        end
    end
    
    /* ==== Stage 3: Output normalization ==== */
    // Buffer of the addition result.
    logic                           s3_is_inf;
    logic                           s3_is_nan;
    logic                           s3_is_zero;
    logic                           s3_sign;
    logic signed[texp_width-1:0]    s3_res_exp;
    logic       [add_width-1:0]     s3_res_man;
    generate
        if (plr_pre_add) begin: s2s3_plr
            always @(posedge clk) begin
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
    localparam frac = man_width + 1;
    svfloat_packer#(float, texp_width, add_width, frac) norm(
        s3_is_inf, s3_is_nan, s3_is_zero,
        s3_sign, s3_res_exp, s3_res_man,
        res
    );
endmodule
