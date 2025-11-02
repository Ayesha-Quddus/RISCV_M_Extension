`include "../src/m_definitions.svh"

module test_m_registers;

// CONTROL INPUTS
logic clk, resetn;
//input logic ALU_neg, // whether the result in the ALU is negative. Not needed
logic [`MUX_MULTA_LENGTH-1:0]   mux_multA;
logic [`MUX_MULTB_LENGTH-1:0]   mux_multB;
logic [`MUX_R_LENGTH-1:0] mux_R; // multiplexer selection for remainder
logic [`MUX_D_LENGTH-1:0] mux_D; // multiplexer selection for divisor
logic [`MUX_Z_LENGTH-1:0] mux_Z; // multiplexer selection for quotient
logic sub_neg;
// DATA INPUTS
logic [31:0] rs1, rs2; // registers at the input
logic [31:0] rs1_neg, rs2_neg;
logic [31:0] sub_result; // result from the subtractor
logic [65:0] product;
// CONTROL OUTPUTS
// DATA OUTPUTS
logic signed [32:0] mult_a;
logic signed [32:0] mult_b;
logic [31:0] R; // remainder
logic [62:0] D; // divisor
logic [31:0] Z; // quotient

m_registers registers(.*);

logic [31:0] D_lower, D_upper;
assign D_lower = D[31:0];
assign D_upper = D[62:31];
logic [31:0] test_Z;

assign sub_neg = sub_result[31];
assign rs1_neg = -rs1;
assign rs2_neg = -rs2;

initial begin
    clk = '0;    
    forever #5ns clk = ~clk;
end

initial begin
    // Set all inputs initially to 0 (avoid X or Z)
    mux_multA = '0;
    mux_multB = '0;
    mux_R = '0;
    mux_D = '0;
    mux_Z = '0;
    rs1 = '0;
    rs2 = '0;
    sub_result = '0;
    test_Z = '0;
    product = '0;

    resetn = '1;
    #10ns resetn = '0;
    #10ns resetn = '1;
    #4ns

    //// TEST R
    // R should get from input
    mux_R = `MUX_R_A;
    rs1 = 32'd789;
    @(posedge clk) @(clk) assert(R == rs1) else $error("R = %d, rs1 = %d", R, rs1);
    #4ns

    // R should negate input's value
    mux_R = `MUX_R_A_NEG;
    rs1 = -32'd7890;
    @(posedge clk) @(clk) assert(R == -rs1) else $error("R = %d, rs1 = %d", R, rs1);
    #4ns

    // R should keep previous value
    mux_R = `MUX_R_KEEP;
    @(posedge clk) @(clk) assert(R == -rs1) else $error("R = %d, rs1 = %d", R, rs1);
    #4ns

    // R should keep previous value since sub_result is negative
    mux_R = `MUX_R_SUB_KEEP;
    sub_result = -32'd123;
    @(posedge clk) @(clk) assert(R == -rs1) else $error("R = %d, rs1 = %d", R, rs1);
    #4ns

    // R should get value from sub_result since it's negative
    mux_R = `MUX_R_SUB_KEEP;
    sub_result = 32'd123;
    @(posedge clk) @(clk) assert(R == sub_result) else $error("R = %d, rs2 = %d", R, rs2);
    #4ns

    mux_R = `MUX_R_MULT_LOWER;
    product = -65'd357;
    @(posedge clk) @(posedge clk) @(clk) assert(R == product[31:0]) else $error("R = %d, rs2 = %d", R, rs2);
    #4ns



    //// TEST D
    // D should get value from input
    mux_D = `MUX_D_B;
    rs2 = 32'd456;
    @(posedge clk) @(clk) assert(D[62:31] == rs2) else $error("D[62:31] = %d, rs2 = %d", D, rs2);
    #4ns

    // D should keep the value from input
    mux_D = `MUX_D_KEEP;
    @(posedge clk) @(clk) assert(D[62:31] == rs2) else $error("D[62:31] = %d, rs2 = %d", D, rs2);
    #4ns

    // D should negate the value from input
    mux_D = `MUX_D_B_NEG;
    rs2 = -32'd4567;
    @(posedge clk) @(clk) assert(D[62:31] == -rs2) else $error("D[62:31] = %d, rs2 = %d", D, rs2);
    #4ns

    // D should shift right by 1 bit
    mux_D = `MUX_D_SHR;
    @(posedge clk) @(clk) assert(D[61:30] == -rs2) else $error("D[61:30] = %d, rs2 = %d", D, rs2);
    #4ns


    //// TEST Z
    // Z should be set to 0
    mux_Z = `MUX_Z_ZERO;
    test_Z = 32'd0;
    @(posedge clk) @(clk) assert(Z == test_Z) else $error("Z = %d, test_Z = %d", Z, test_Z);
    #4ns

    // Z should be 1
    mux_Z = `MUX_Z_SHL_ADD;
    sub_result = 32'd123;
    test_Z = (test_Z << 1) + 1;
    @(posedge clk) @(clk) assert(Z == test_Z) else $error("Z = %d, test_Z = %d", Z, test_Z);
    #4ns

    // Z should keep current value
    mux_Z = `MUX_Z_KEEP;
    sub_result = 32'd123;
    @(posedge clk) @(clk) assert(Z == test_Z) else $error("Z = %d, test_Z = %d", Z, test_Z);
    #4ns

    // Z should double
    mux_Z = `MUX_Z_SHL_ADD;
    sub_result = -32'd123;
    test_Z = (test_Z << 1);
    @(posedge clk) @(clk) assert(Z == test_Z) else $error("Z = %d, test_Z = %d", Z, test_Z);
    #4ns

    // Z should double and add by 1
    mux_Z = `MUX_Z_SHL_ADD;
    sub_result = 32'd123;
    test_Z = (test_Z << 1) + 1;
    @(posedge clk) @(clk) assert(Z == test_Z) else $error("Z = %d, test_Z = %d", Z, test_Z);
    #4ns

    // Z should double and add by 1
    mux_Z = `MUX_Z_SHL_ADD;
    sub_result = 32'd123;
    test_Z = (test_Z << 1) + 1;
    @(posedge clk) @(clk) assert(Z == test_Z) else $error("Z = %d, test_Z = %d", Z, test_Z);
    #4ns

    // Z should double and add by 1
    mux_Z = `MUX_Z_SHL_ADD;
    sub_result = 32'h80000000;
    test_Z = (test_Z << 1);
    @(posedge clk) @(clk) assert(Z == test_Z) else $error("Z = %d, test_Z = %d", Z, test_Z);
    #4ns

    mux_Z = `MUX_Z_MULT_UPPER;
    mux_multA = `MUX_MULTA_R_SIGNED;
    product = -65'd357;
    @(posedge clk) @(posedge clk) @(clk) assert(Z == {product[65],product[62:32]}) else $error("Z = %d, product = %d", Z, product);
    #4ns

    $stop;

end

endmodule