`include "m_definitions.svh"

module m_controller(
    // CONTROL INPUTS
    input logic clk, resetn,
    input logic pcpi_valid, // signal to start process
    // DATA INPUTS
    input logic [31:0] instruction, // instruction to analyze
    input logic [31:0] rs1, rs2, // operands to analyze
    // CONTROL OUTPUTS
    output logic [`MUX_R_LENGTH-1:0] mux_R, // multiplexer for remainder
    output logic [`MUX_D_LENGTH-1:0] mux_D, // multiplexer for divisor
    output logic [`MUX_Z_LENGTH-1:0] mux_Z, // multiplexer for quocient
    output logic [`MUX_MULTA_LENGTH-1:0] mux_multA, // multiplexer for mult input A
    output logic [`MUX_MULTB_LENGTH-1:0] mux_multB, // multiplexer for mult input B
    output logic [`MUX_DIV_REM_LENGTH-1:0] mux_div_rem, // multiplexer for Z/R selection
    output logic [`MUX_OUT_LENGTH-1:0] mux_out, // multiplexer for output
    output logic pcpi_ready,
    output logic pcpi_wr,
    output logic pcpi_busy,
    // DATA OUTPUTS
    output logic [31:0] rs1_neg, rs2_neg
);

// Internal counter signal
logic [4:0] counter;
logic [4:0] counter_next;

// Internal register to store input function
logic [2:0] current_func, next_current_func;

// Comparator (subtractor) for input values
logic rs1_smaller_rs2;
logic [31:0] abs_rs1, abs_rs2;
function logic rs1_is_signed(func3 cur_func3);
    return (cur_func3==MULH || cur_func3==MULHSU || cur_func3==DIV || cur_func3==REM);
endfunction
function logic rs2_is_signed(func3 cur_func3);
    return (cur_func3==MULH || cur_func3==DIV || cur_func3==REM);
endfunction

// CONTROL SIGNALS 
// STATE
typedef enum logic [2:0] {
    IDLE   = 3'b000,
    //VALID  = 3'b001,
    DIVID  = 3'b010,
    SELECT = 3'b011,
    DONE   = 3'b100,
    PRE_MULT = 3'b101,
    MULTIP = 3'b110
} state_t;
state_t state, next_state;


// Create neg values for rs1 and rs2
assign rs1_neg = -rs1;
assign rs2_neg = -rs2;

always_comb begin
    abs_rs1[31:0] = (is_negative(rs1) && rs1_is_signed((state == DONE) ? current_func : next_current_func)) ? rs1_neg : rs1;
    abs_rs2[31:0] = (is_negative(rs2) && rs2_is_signed((state == DONE) ? current_func : next_current_func)) ? rs2_neg : rs2;

    rs1_smaller_rs2 = abs_rs1 < abs_rs2;
end


// SEQUENTIAL BLOCK
always_ff @(posedge clk, negedge resetn) // Asynchronous reset
begin
    if(~resetn) begin
        state <= IDLE;
        counter <= 5'b00000;
        current_func <= '0;
    end
    else begin
        state <= next_state;
        counter <= counter_next;
        current_func <= next_current_func;
    end
end


// COMBINATORIAL BLOCK
// State machine to handle whole design
always_comb
begin
    // Set all outputs to default (avoid latches)
    mux_R = `MUX_R_KEEP;
    mux_D = `MUX_D_KEEP;
    mux_Z = `MUX_Z_KEEP;
    mux_multA = `MUX_MULTA_ZERO;
    mux_multB = `MUX_MULTB_ZERO;
    mux_div_rem = `MUX_DIV_REM_R;
    mux_out = `MUX_OUT_ZERO;
    pcpi_ready = '0;
    pcpi_wr = '0;
    pcpi_busy = '0;
    next_current_func = current_func;
    counter_next = '0;
    
    // setting registers to previous state
    next_state = state;

    // State machine control
    unique case (state)
        IDLE: begin
            // Reset output signals
            pcpi_ready = 1'b0;
            pcpi_wr = 1'b0;
            pcpi_busy = 1'b0;

            // Set multiplier mux to zero to save dynamic power
            mux_multA = `MUX_MULTA_ZERO;
            mux_multB = `MUX_MULTB_ZERO;

            // Reset the counter
            counter_next = '0;

            // Input conditions for valid co-processor instruction
            if (pcpi_valid && (get_ir_opcode(instruction) == OPCODE) 
                            && (get_ir_func7(instruction) == FUNC7)) begin            
                //next_state = VALID;
                // Get the current func3
                next_current_func = get_ir_func3(instruction);

                // reset quotient mux
                mux_Z = `MUX_Z_ZERO;

                // Mux selection for signed DIV and REM and negative rs1
                if ((next_current_func == DIV || next_current_func == REM) 
                            && is_negative(rs1)) begin
                    mux_R = `MUX_R_A_NEG;
                end else begin
                    mux_R = `MUX_R_A;
                end

                // Mux selection for signed DIV and REM and negative rs2
                if ((next_current_func == DIV || next_current_func == REM) 
                            && is_negative(rs2)) begin
                    mux_D = `MUX_D_B_NEG;
                end else begin
                    mux_D = `MUX_D_B;
                end

                // Next state logic
                // Same state for DIV/REM and different for MUL
                if (is_div(next_current_func) || is_rem(next_current_func)) begin
                    if(rs2 == '0) begin
                        mux_R = `MUX_R_A;
                        next_state = DONE;
                    end else if (rs1_smaller_rs2) begin
                        mux_R = `MUX_R_A; // get rs1 to return in case of REM
                        next_state = DONE;
                    // Overflow
                    end else if ((next_current_func == DIV || next_current_func == REM) && rs1 == {-32'd1} && rs2 == {32{1'b1}}) begin
                        next_state = DONE;
                    end else begin
                        next_state = DIVID;
                    end
                end else begin
                    next_state = SELECT;
                end

            end else begin
                next_state = IDLE;
            end      
        end

        /*VALID: begin
            // Set busy to 1showing computation is in process
            pcpi_busy = 1'b1;
            next_state = IDLE;
            
        end*/

        DIVID: begin
            pcpi_busy = 1'b1;

            //  Updating the R, D, Z signals using mux
            mux_R = `MUX_R_SUB_KEEP;
            mux_D = `MUX_D_SHR;
            mux_Z = `MUX_Z_SHL_ADD;

            // Next state logic
            // If counter is 31, it means we have ran the loop from 0 to 31
            if (counter < 5'b11111) begin
                next_state = DIVID;
                // Incrementing the counter
                counter_next = counter + 5'b00001;
            end else begin
                next_state = SELECT;
            end
        end

        SELECT: begin
            pcpi_busy = 1'b1;

            // Selection for div or rem mux
            mux_div_rem = is_div(current_func) ? `MUX_DIV_REM_Z : `MUX_DIV_REM_R;

            // Selection for mul mux
            if (is_mult(current_func)) begin
                unique case(current_func)
                    // For MULH both inputs should be signed
                    MULH: begin
                        mux_multA = `MUX_MULTA_R_SIGNED;
                        mux_multB = `MUX_MULTB_D_SIGNED;
                    end
            
                    // For MULHSU first input is signed and second unsigned
                    MULHSU: begin
                        mux_multA = `MUX_MULTA_R_SIGNED;
                        mux_multB = `MUX_MULTB_D_UNSIGNED;
                    end

                    // For MUL & MULHU both inputs are unsigned
                    default: begin
                        mux_multA = `MUX_MULTA_R_UNSIGNED;
                        mux_multB = `MUX_MULTB_D_UNSIGNED;
                    end
                endcase
                next_state = PRE_MULT;
            end else begin
                next_state = DONE;
            end
        end

        PRE_MULT: begin
            pcpi_busy = 1'b1;
            next_state = MULTIP;
        end

        MULTIP: begin
            pcpi_busy = 1'b1;
            if (current_func == MUL) begin
                mux_R = `MUX_R_MULT_LOWER;
                mux_div_rem = `MUX_DIV_REM_R;
            end else begin
                mux_Z = `MUX_Z_MULT_UPPER;
                mux_div_rem = `MUX_DIV_REM_Z;
            end
            next_state = DONE;
        end

        DONE: begin
            // Output mux logic
            // Check if it is multiplication
            if (is_mult(current_func)) begin
                // If function is MUL then we use lower bits otherwise upper bits
                if (current_func == MUL) begin
                    mux_div_rem = `MUX_DIV_REM_R;
                end else begin
                    mux_div_rem = `MUX_DIV_REM_Z;
                end
                mux_out = `MUX_OUT_DIV_REM;

            // If its not multiplication, it must be division or remainder
            end else begin
                // Checking condition of signed DIV or REM and also negative output conditions
                // Quotient is negative if sign of rs1 is not equal to sign of rs2
                // Remainder has the same sign as the dividend
                
                // Selection for div or rem mux
                mux_div_rem = is_div(current_func) ? `MUX_DIV_REM_Z : `MUX_DIV_REM_R;

                if ((current_func == DIV && (is_negative(rs1) != is_negative(rs2)))
                        || (current_func == REM && is_negative(rs1))) begin
                    mux_out = `MUX_OUT_DIV_REM_NEG;
                end else begin
                    mux_out = `MUX_OUT_DIV_REM;
                end

                // Evaluate especial cases
                if (rs2 == '0) begin // division by 0 cases
                    if(is_rem(current_func)) begin
                        mux_out = `MUX_OUT_DIV_REM;
                    end else if (current_func == DIV) begin
                        mux_out = `MUX_OUT_MINUS_1;
                    end else if (current_func == DIVU) begin
                        mux_out = `MUX_OUT_ALL1;
                    end
                end else if(rs1_smaller_rs2) begin
                    mux_out = is_div(current_func) ? `MUX_OUT_ZERO : `MUX_OUT_DIV_REM;
                end else if (rs1 == {-32'd1} && rs2 == {32{1'b1}}) begin // Overflow
                    if (current_func == DIV) begin
                        mux_out = `MUX_OUT_DIV_REM;
                    end else if (current_func == REM) begin
                        mux_out = `MUX_OUT_ZERO;
                    end
                end
            end

            // Set output signals
            pcpi_ready = 1'b1;
            pcpi_wr = 1'b1;
            pcpi_busy = 1'b0;

            next_state = IDLE;
            next_current_func = '0;
        end

        default:
            next_state = IDLE;
    endcase

end

endmodule