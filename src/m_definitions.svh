`ifndef M_DEFINITIONS_H
`define M_DEFINITIONS_H

//// INSTRUCTION ANALYSIS

// Define type to detect M operation type
typedef logic [2:0] func3;
// Definitions of M operations
parameter func3 MUL    = 3'b000; // multiplication returning 32 lower bits
parameter func3 MULH   = 3'b001; // multiplication (  signed x   signed) sending 32 upper bits
parameter func3 MULHSU = 3'b010; // multiplication (  signed x unsigned) sending 32 upper bits
parameter func3 MULHU  = 3'b011; // multiplication (unsigned x unsigned) sending 32 upper bits
parameter func3 DIV    = 3'b100; //   signed division
parameter func3 DIVU   = 3'b101; // unsigned division
parameter func3 REM    = 3'b110; // remainder of   signed division
parameter func3 REMU   = 3'b111; // remainder of unsigned division
// Other fields defining the usage of M extension
parameter logic [6:0] OPCODE = 7'b0110011; // ALU operation
parameter logic [6:0] FUNC7 = 7'b0000001;  // M extension

//// Functions to extract important parts from instruction
// Get opcode
function unsigned [6:0] get_ir_opcode(unsigned [31:0]ir);
    return ir[6:0];
endfunction
// Get func3
function func3 get_ir_func3(unsigned [31:0]ir);
    return ir[14:12];
endfunction
// Get func7
function unsigned [6:0] get_ir_func7(unsigned [31:0]ir);
    return ir[31:25];
endfunction
// detect whether it is a multiplication
function logic is_mult(func3 f3);
    return f3[2]==0;
endfunction
// detect whether it is a division
function logic is_div(func3 f3);
    return f3[2]==1 && f3[1]==0;
endfunction
// detect whether it is a remainder
function logic is_rem(func3 f3);
    return f3[2]==1 && f3[1]==1;
endfunction

// Function to determine whether a number is negative (MSB bit check)
function logic is_negative(unsigned [31:0] value);
    return value[31];
endfunction



//// CONTROL SIGNALS

// Multiplexer for R register
`define MUX_R_LENGTH 3 // number of bits needed to declare mux R
// Values
`define MUX_R_KEEP       `MUX_R_LENGTH'd0 // keep previous value
`define MUX_R_A          `MUX_R_LENGTH'd1 // copy value from input
`define MUX_R_A_NEG      `MUX_R_LENGTH'd2 // copy value from input and multiply it by -1
`define MUX_R_SUB_KEEP   `MUX_R_LENGTH'd3 // replace by value obtained in subtractor or keep it (depends on ALU result)
`define MUX_R_MULT_LOWER `MUX_R_LENGTH'd4 // replace by lower 32 bits from multiplier

// Multiplexer for D register
`define MUX_D_LENGTH 2 // number of bits needed to declare mux D
// Values
`define MUX_D_KEEP  `MUX_D_LENGTH'd0 // keep previous value
`define MUX_D_B     `MUX_D_LENGTH'd1 // copy value from input
`define MUX_D_B_NEG `MUX_D_LENGTH'd2 // copy value from input and multiply it by -1
`define MUX_D_SHR   `MUX_D_LENGTH'd3 // replace by value obtained in right shift

// Multiplexer for Z register
`define MUX_Z_LENGTH 2 // number of bits needed to declare mux Z
// Values
`define MUX_Z_KEEP       `MUX_Z_LENGTH'd0 // keep previous value
`define MUX_Z_ZERO       `MUX_Z_LENGTH'd1 // replace by 0
`define MUX_Z_SHL_ADD    `MUX_Z_LENGTH'd2 // replace value by obtained in left shift (and adds 1 depending on ALU result)
`define MUX_Z_MULT_UPPER `MUX_Z_LENGTH'd3 // replace by upper 32 bits from multiplier

// Multiplexer for multA input
`define MUX_MULTA_LENGTH 2 // number of bits needed to declare mux multA
// Values
`define MUX_MULTA_R_UNSIGNED `MUX_MULTA_LENGTH'd0 // use value from first input and extend unsigned
`define MUX_MULTA_R_SIGNED   `MUX_MULTA_LENGTH'd1 // use value from first input and extend signed
`define MUX_MULTA_ZERO       `MUX_MULTA_LENGTH'd2 // keep it in 0 (saves dynamic power)

// Multiplexer for multB input
`define MUX_MULTB_LENGTH 2 // number of bits needed to declare mux multB
// Values
`define MUX_MULTB_D_UNSIGNED `MUX_MULTB_LENGTH'd0 // use value from second input and extend unsigned
`define MUX_MULTB_D_SIGNED   `MUX_MULTB_LENGTH'd1 // use value from second input and extend signed
`define MUX_MULTB_ZERO       `MUX_MULTB_LENGTH'd2 // keep it in 0 (saves dynamic power)

// Multiplexer for output inverter
`define MUX_DIV_REM_LENGTH 1 // number of bits needed to declare mux div_rem
// Values
`define MUX_DIV_REM_R `MUX_DIV_REM_LENGTH'd0 // use R (remainder)
`define MUX_DIV_REM_Z `MUX_DIV_REM_LENGTH'd1 // use Z (quotient)

// Multiplexer for output
`define MUX_OUT_LENGTH 3 // number of bits needed to declare mux output
// Values
`define MUX_OUT_ZERO         `MUX_OUT_LENGTH'd0 // output zero
`define MUX_OUT_DIV_REM      `MUX_OUT_LENGTH'd1 // output value from divider
`define MUX_OUT_DIV_REM_NEG  `MUX_OUT_LENGTH'd2 // output value from divider multiplied by -1
`define MUX_OUT_MULT_LOWER   `MUX_OUT_LENGTH'd3 // output lower bits from multipler
`define MUX_OUT_MULT_UPPER   `MUX_OUT_LENGTH'd4 // output upper bits from multiplier
`define MUX_OUT_ALL1         `MUX_OUT_LENGTH'd5 // output all bits 1
`define MUX_OUT_MINUS_1      `MUX_OUT_LENGTH'd6 // output is -1




`endif // M_DEFINITIONS_H