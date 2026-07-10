module dummy_control_unit(
    input clk,
    input reset,
    output reg [15:0] mem_data_in,
    output reg mem_write_enable,
    output reg [7:0] mem_addr
);
// States
localparam FETCH    = 3'b000;
localparam DECODE   = 3'b001;
localparam EXECUTE  = 3'b010;
localparam MEM_WAIT = 3'b011; 
localparam HALT     = 3'b100;

reg [2:0] state;
reg [7:0] pc; // basically counter for the instruction memory
reg [15:0] instr;  // Current instruction

// Wires
wire [3:0] opcode, rd, ra, rb;
wire [7:0] immediate;
wire reg_we, mem_we, mem_re, use_imm, is_halt, is_jump, is_jz;
wire [15:0] ra_out, rb_out, alu_result, mem_data_out; // to hold data after reading from registers and memory
wire alu_check; // ALU result check for zero

reg [15:0] reg_write_data;
reg reg_write_enable;


// Instantiate modules

dummy_decoder decoder (
    .instruction(instr),
    .opcode(opcode),
    .rd(rd),
    .ra(ra),
    .rb(rb),
    .immediate(immediate),
    .reg_we(reg_we),
    .mem_we(mem_we),
    .mem_re(mem_re),
    .use_imm(use_imm),
    .is_halt(is_halt),
    .is_jump(is_jump),
    .is_jz(is_jz)
);      

dummy_reg registers (
    .clk(clk),
    .we(reg_write_enable),
    .wd_addr(rd),
    .wd_data(reg_write_data),
    .ra_addr(ra),
    .rb_addr(rb),
    .ra_out(ra_out),
    .rb_out(rb_out)
);

dummy_alu alu (
    .a(ra_out),
    .b(use_imm ? {8'b0, immediate} : rb_out), // Use immediate if specified
    .op(opcode),
    .result(alu_result),
    .check(alu_check)
);

dummy_memory memory (
    .clk(clk),
    .we(mem_write_enable),
    .addr(mem_addr),
    .data_in(mem_data_in),
    .data_out(mem_data_out)
);

// State machine loopps

always @(posedge clk) begin
    if (reset) begin
        pc <= 0;
        state <= FETCH;
        reg_write_enable <= 0;
        mem_write_enable <= 0;
    end else begin
        case (state)
            FETCH: begin
                mem_addr <= pc;
                state <= DECODE;
            end
            DECODE: begin
                instr <= mem_data_out; 
                // Fetch instruction from memory
                // works cuz decoder is sensitive to instr changes and will update control signals accordingly
                state <= EXECUTE;
            end
            EXECUTE: begin
                // defaults every cycle so nothing stays asserted by accident
                reg_write_enable <= 0;
                mem_write_enable <= 0;

                if (is_halt) begin
                    state <= HALT;
                end else if (is_jump) begin
                    pc <= ra_out[7:0]; // Jump to address in ra (used for loops and stuff)
                    // like each instruction has its own ra and stuff so wont mess with anything
                    state <= FETCH;
                end else if (is_jz && alu_check) begin
                    pc <= rb_out[7:0]; 
                    // is used to jump of loops and like if ra is zero then jump to address in rb else just increment pc
                    state <= FETCH;
                end else if (mem_re) begin
                    // LOAD needs address but only data is there so it shifts to MEM_WAIT
                    mem_addr <= ra_out[7:0];
                    state <= MEM_WAIT;
                end else if (mem_we) begin
                    // STORE ra, rb -> memory[rb] = ra
                    mem_addr <= rb_out[7:0];
                    mem_data_in <= ra_out;
                    mem_write_enable <= 1;
                    pc <= pc + 1;
                    state <= FETCH;
                end else begin
                    // executing alu based on control signals 
                    if (reg_we) begin
                        // use_imm (LI) and normal ALU ops both handled here
                        reg_write_data <= use_imm ? {8'b0, immediate} : alu_result;
                        reg_write_enable <= 1;
                    end
                    pc <= pc + 1; // Increment program counter for next instruction
                    state <= FETCH; // Go back to fetch next instruction
                end
            end
            MEM_WAIT: begin
                // now mem_data_out reflects memory[ra_out] from last cycle
                reg_write_data <= mem_data_out;
                reg_write_enable <= 1;
                pc <= pc + 1;
                state <= FETCH;
            end
            HALT: begin
                state <= HALT; 
            end
        endcase
    end

end

endmodule