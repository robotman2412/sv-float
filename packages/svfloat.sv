
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps



package svfloat;
// Bfloat16 alternative half-precision floating-point number.
typedef struct packed {
    // Sign, 1 is negative, 0 is positive.
    bit         sign;
    // Biased exponent; 127 is 2^0.
    bit[7:0]    exponent;
    // Mantissa; fractional part.
    bit[6:0]    mantissa;
} bfloat16;

// IEEE 754 half-precision floating-point number.
typedef struct packed {
    // Sign, 1 is negative, 0 is positive.
    bit         sign;
    // Biased exponent; 15 is 2^0.
    bit[4:0]    exponent;
    // Mantissa; fractional part.
    bit[9:0]    mantissa;
} float16;

// IEEE 754 single-precision floating-point number.
typedef struct packed {
    // Sign, 1 is negative, 0 is positive.
    bit         sign;
    // Biased exponent; 127 is 2^0.
    bit[7:0]    exponent;
    // Mantissa; fractional part.
    bit[22:0]   mantissa;
} float32;

// IEEE 754 double-precision floating-point number.
typedef struct packed {
    // Sign, 1 is negative, 0 is positive.
    bit         sign;
    // Biased exponent; 1023 is 2^0.
    bit[10:0]   exponent;
    // Mantissa; fractional part.
    bit[51:0]   mantissa;
} float64;



// Floating-point number functions following the IEEE 754 pattern.
class ffunc#(
    // Floating-point type.
    type        float       = float16
);
    float dummy;
    // Number of exponent bits.
    parameter   exp_width   = $bits(dummy.exponent);
    // Number of explicit mantissa bits.
    parameter   man_width   = $bits(dummy.mantissa);
    // Total bit width of this type.
    localparam  width       = 1 + exp_width + man_width;
    // Bit offset of mantissa in float64.
    localparam  man_off     = 52 - man_width;
    // Exponent bias.
    parameter   exp_bias    = (1 << (exp_width - 1)) - 1;
    // Maximum exponent value.
    parameter   exp_max     = (1 << exp_width) - 1;
    
    
    
    // Constant: Positive infinity.
    static function automatic float inf();
        return '{0, exp_max, 0};
    endfunction
    
    // Constant: Negative infinity.
    static function automatic float neg_inf();
        return '{1, exp_max, 0};
    endfunction
    
    // Constant: NaN (Not a Number).
    static function automatic float nan();
        return '{0, exp_max, 1};
    endfunction
    
    // Is infinity?
    static function automatic bit is_inf(float value);
        return value.exponent == exp_max && value.mantissa == 0;
    endfunction
    
    // Is NaN?
    static function automatic bit is_nan(float value);
        return value.exponent == exp_max && value.mantissa != 0;
    endfunction
    
    // Is finite and a number?
    static function automatic bit is_finite(float value);
        return value.exponent != exp_max;
    endfunction
    
    // Is normalized number?
    static function automatic bit is_normal(float value);
        return value.exponent != 0;
    endfunction
    
    // Is denormalized number?
    static function automatic bit is_subnormal(float value);
        return value.exponent == 0;
    endfunction
    
    // Get the real exponent value.
    static function automatic integer true_exponent(float value);
        integer exp;
        exp = value.exponent;
        if (exp == 0) exp = exp + 1;
        return exp - exp_bias;
    endfunction
    
    
    // Display the binary value.
    static function void display_bin(float f);
        if (is_inf(f)) begin
            $display("%cinf", f.sign ? "-" : "+");
        end else if (is_nan(f)) begin
            $display("%cnan", f.sign ? "-" : "+");
        end else if (true_exponent(f) < 0) begin
            $display("%c %01b.%b * 10^-%01b", f.sign ? "-" : "+", is_normal(f), f.mantissa, -true_exponent(f));
        end else begin
            $display("%c %01b.%b * 10^%01b",  f.sign ? "-" : "+", is_normal(f), f.mantissa, true_exponent(f));
        end
    endfunction
    
    // Display the decimal value.
    static function void display_dec(float f);
        real man;
        man = f.mantissa / (2.0 ** man_width);
        man = man + is_normal(f);
        if (is_inf(f)) begin
            $display("%cinf", f.sign ? "-" : "+");
        end else if (is_nan(f)) begin
            $display("%cnan", f.sign ? "-" : "+");
        end else begin
            $display("%c %f * 2^%01d", f.sign ? "-" : "+", man, true_exponent(f));
        end
    endfunction
    
    // Convert real to float, used for constants.
    static function automatic float from_real(real raw);
        float value;
        integer exponent;
        bit[63:0] bits;
        
        bits = $realtobits(raw);
        value.sign     = bits[63];
        exponent       = bits[62:52] - 1023 + exp_bias;
        value.mantissa = bits[man_width+man_off-1:man_off];
        
        if (exponent < 0) begin
            value.exponent = 0;
            value.mantissa = 0;
        end else if (bits[62:52] == 2047 && bits[51:0] != 0) begin
            value.exponent = exp_max;
            value.mantissa = 1;
        end else if (exponent >= exp_max) begin
            value.exponent = exp_max;
            value.mantissa = 0;
        end else begin
            value.exponent = exponent;
        end
        
        return value;
    endfunction
    
    // Convert float to real, used in simulation for printing.
    static function automatic real to_real(float value);
        bit[63:0] bits;
        bit[63:0] mantissa;
        integer exponent;
        
        bits     = 0;
        bits[63] = value.sign;
        exponent = value.exponent - exp_bias + 1023;
        mantissa = value.mantissa;
        
        if (exponent < 0) begin
            exponent = 0;
            mantissa = 0;
        end else if (value.exponent == exp_max && value.mantissa != 0) begin
            exponent = 2047;
            mantissa = 1;
        end else if (exponent > 2047 || value.exponent == exp_max) begin
            exponent = 2047;
            mantissa = 0;
        end
        bits[62:52]                       = exponent;
        bits[man_width+man_off-1:man_off] = mantissa;
        
        return $bitstoreal(bits);
    endfunction
endclass
endpackage
