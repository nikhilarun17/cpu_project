module dummy_decoder(
    input [15:0] instruction,
    output  [3:0] opcode,
    output  [3:0] rd,
    output  [3:0] ra,
    output  [3:0] rb,
    output [7:0] immediate,
    
    output reg reg_we,
    output reg mem_we,
    output reg mem_re,
    output reg use_imm,
    output reg is_halt,
    output reg is_jump,
    output reg is_jz,
    output reg is_int
);

    assign opcode = instruction[15:12];
    assign rd = instruction[11:8];
    assign ra = instruction[7:4];
    assign rb = instruction[3:0];
    assign immediate = instruction[7:0];

    //control signals

    always @(*) begin
        reg_we = 0;
        mem_we = 0;
        mem_re = 0;
        use_imm = 0;
        is_halt = 0;
        is_jump = 0;
        is_jz = 0;
        is_int = 0;

        case (opcode)
            4'b0000: reg_we = 1; // ADD
            4'b0001: reg_we = 1; // SUB
            4'b0010: reg_we = 1; // AND
            4'b0011: reg_we = 1; // OR
            4'b0100: reg_we = 1; // XOR
            4'b0101: reg_we = 1; // NOT
            4'b0110: reg_we = 1; // LT
            4'b0111: reg_we = 1; // EQ
            
            4'b1000: begin // LOAD
                reg_we = 1;
                mem_re = 1;
            end

            4'b1001: mem_we = 1; // STORE
            4'b1010: is_jump = 1; // JUMP
            4'b1011: is_jz = 1; // JZ
            4'b1100: begin // LI
                reg_we = 1;
                use_imm = 1;
                is_int = 0;
            end
            4'b1101: begin //LINT
                reg_we = 1;
                use_imm = 1;
                is_int = 1;
            end
            4'b1111: is_halt = 1; // HALT   
            default: ;
        endcase
    end
endmodule

