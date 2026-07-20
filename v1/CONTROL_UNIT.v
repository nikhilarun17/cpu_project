module dummy_control_unit(
    input clk,
    input por,                       // power-on reset: the ONLY hard reset
    input button_reset_unused,       // debounced button, HIGH when released
    output reg [15:0] mem_data_in,
    output reg mem_write_enable,
    output reg [7:0] mem_addr,

    input             inj_active,
    input      [15:0] inj_instr,
    output reg [4:0]  inj_pc,

    input             stall
);

localparam FETCH    = 3'b000;
localparam DECODE   = 3'b001;
localparam EXECUTE  = 3'b010;
localparam MEM_WAIT = 3'b011;
localparam HALT     = 3'b100;

wire button_pressed = ~button_reset_unused;

reg [2:0] state;
reg [7:0] pc;
reg [15:0] instr;
reg instr_is_inj;

wire [3:0] opcode, rd, ra, rb;
wire [7:0] immediate;
wire reg_we, mem_we, mem_re, use_imm, is_halt, is_jump, is_jz, is_int;
wire [15:0] ra_out, rb_out, alu_result, mem_data_out;
wire alu_check;

reg [15:0] reg_write_data;
reg reg_write_enable;

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
    .is_jz(is_jz),
    .is_int(is_int)
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
    .b(use_imm ? {8'b0, immediate} : rb_out),
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

always @(posedge clk) begin
    if (por) begin
        // hard reset 
        pc <= 0;
        inj_pc <= 0;
        instr_is_inj <= 0;
        state <= FETCH;
        reg_write_enable <= 0;
        mem_write_enable <= 0;
    end else begin
        // FSM always runs only being gated by POR (for injected instructions)
        case (state)
            FETCH: begin
                mem_write_enable <= 0;
                reg_write_enable <= 0;
                if (!inj_active)
                    inj_pc <= 0;
                if (!stall) begin
                    mem_addr <= pc;
                    state <= DECODE;
                end
            end

            DECODE: begin
                instr <= inj_active ? inj_instr : mem_data_out;
                instr_is_inj <= inj_active;
                state <= EXECUTE;
            end

            EXECUTE: begin
                reg_write_enable <= 0;
                mem_write_enable <= 0;

                if (is_halt) begin
                    state <= HALT;
                end else if (is_jump) begin
                    pc <= ra_out[7:0];
                    state <= FETCH;
                end else if (is_jz && alu_check) begin
                    pc <= rb_out[7:0];
                    state <= FETCH;
                end else if (mem_re) begin
                    mem_addr <= ra_out[7:0];
                    state <= MEM_WAIT;
                end else if (mem_we) begin
                    mem_addr <= rb_out[7:0];
                    mem_data_in <= ra_out;
                    mem_write_enable <= 1;
                    if (instr_is_inj) inj_pc <= inj_pc + 1;
                    else pc <= pc + 1;
                    state <= FETCH;
                end else begin
                    if (reg_we) begin
                        reg_write_data <= use_imm ? {is_int,7'b0,immediate} : alu_result;
                        reg_write_enable <= 1;
                    end
                    if (instr_is_inj) inj_pc <= inj_pc + 1;
                    else pc <= pc + 1;
                    state <= FETCH;
                end
            end

            MEM_WAIT: begin
                reg_write_data <= mem_data_out;
                reg_write_enable <= 1;
                if (instr_is_inj) inj_pc <= inj_pc + 1;
                else pc <= pc + 1;
                state <= FETCH;
            end

            HALT: begin
                if (inj_active)
                    state <= FETCH;
                else
                    state <= HALT;
            end
        endcase

        if (button_pressed && !inj_active && !instr_is_inj) begin
            pc    <= 0;
            state <= FETCH;
        end
    end
end

endmodule