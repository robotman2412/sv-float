
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
    localparam  exp_width   = $bits(dummy.exponent);
    // Number of explicit mantissa bits.
    localparam  man_width   = $bits(dummy.mantissa);
    // Total bit width of this type.
    localparam  width       = 1 + exp_width + man_width;
    // Bit offset of mantissa in float64.
    localparam  man_off     = 52 - man_width;
    // Exponent bias.
    localparam  exp_bias    = (1 << (exp_width - 1)) - 1;
    // Maximum exponent value.
    localparam  exp_max     = (1 << exp_width) - 1;
    
    
    
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
            $display("%c %01b.%01b * 10^-%01b", f.sign ? "-" : "+", is_normal(f), f.mantissa, -true_exponent(f));
        end else begin
            $display("%c %01b.%01b * 10^%01b",  f.sign ? "-" : "+", is_normal(f), f.mantissa, true_exponent(f));
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

// Real to float16.
function automatic float16 realtof16(real raw);
    return ffunc#(float16)::from_real(raw);
endfunction

// Real to float32.
function automatic float32 realtof32(real raw);
    return ffunc#(float32)::from_real(raw);
endfunction

// Real to float64.
function automatic float64 realtof64(real raw);
    return ffunc#(float64)::from_real(raw);
endfunction
endpackage

// Fixed-point integer to floating-point number converter.
module itof#(
    // Floating-point type as described in the README.
    type                float       = svfloat::float32,
    // Total number of bits.
    parameter   integer width       = 32,
    // Optional number of fractional bits.
    parameter   integer frac        = 0,
    // Whether the input number is signed.
    parameter   bit     issigned    = 1
)(
    // Integer to convert.
    input  logic[width-1:0] in,
    // Floating-point representation.
    output float            out
);
    genvar x;
    
    // Number of bits required to represent true exponent.
    localparam  integer ewidth      = $clog2(width) > $bits(out.exponent) ? $clog2(width) : $bits(out.exponent);
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
    wire signed[$clog2(mwidth)-1:0] shl = $bits(out.mantissa) - msb;
    // True mantissa.
    logic      [mwidth-1:0]         man = shl > 0 ? tmp << shl : tmp >> -shl;
    
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
