module bodmos(
    input clk,
    input reset,

    // from UART_RX
    input [7:0] rx_data,
    input       rx_done,

    // echo bytes for the TX buffer (cpu_top arbitrates the actual push)
    output reg [7:0] echo_data,
    output reg       echo_valid,

    // injection interface to the control unit
    output reg        inj_active,
    input      [4:0]  inj_pc,
    output     [15:0] inj_instr
);

    localparam INJ_LEN = 16;
    
    wire inj_pc_valid = (inj_pc != 5'd16);

    //token buffer 
    reg [15:0] rx_buff [0:7];
    reg [2:0]  wr_ptr;

    //  number accumulator for calculating multiple digit numbers using arithmetic before storing
    reg [14:0] int_hold;
    reg        has_digits;

    // operator that arrived on the same byte as a number flush;
    // pushed one cycle later (bytes are ~2300 clks apart at 115200, so safe)
    reg [7:0]  pend_char;
    reg        pend_valid;

    //  extracted expression 
    reg [14:0] opA, opB;
    reg        got_a, got_b, got_op;
    reg [3:0]  op_bits;
    reg [2:0]  scan_idx;

    //  injected instruction construction
    reg [15:0] prog [0:INJ_LEN-1];
    assign inj_instr = inj_pc_valid ? prog[inj_pc[3:0]] : 16'b1100_0000_00000000;

    localparam COLLECT = 3'd0;
    localparam EOL_CR  = 3'd1;   // echo '\r'
    localparam EOL_LF  = 3'd2;   // echo '\n'
    localparam SCAN    = 3'd3;   // walk rx_buff and pull out stuff like A, op, B
    localparam BUILD   = 3'd4;   // write the 16 instructions (including freeing registers)
    localparam RUN     = 3'd5;   // holds inj_active until control unit finished all it needs to do 
    localparam CLEAN   = 3'd6;   // reset buffer and operand

    reg [2:0] state;
    reg prev_cr;   // eradicating/destroying/washing the LF of a CRLF pair

    localparam IDLE_LIMIT = 27'd27000000;   
    reg [26:0] idle_count = 0;
    wire line_in_progress = has_digits || (wr_ptr != 0) || pend_valid;

    wire is_digit = (rx_data >= "0") && (rx_data <= "9");
    wire is_eol   = (rx_data == 8'd13) || (rx_data == 8'd10);
    wire is_space = (rx_data == " ");

    function [3:0] op_map(input [7:0] c);
        case (c)
            "+":     op_map = 4'b0000; // ADD
            "-":     op_map = 4'b0001; // SUB
            "*":     op_map = 4'b1110; // MUL
            "/":     op_map = 4'b1111; // DIV
            default: op_map = 4'b0000;
        endcase
    endfunction

    wire [15:0] token = rx_buff[scan_idx];

    always @(posedge clk) begin
        echo_valid <= 1'b0;

        if (reset) begin
            state      <= COLLECT;
            wr_ptr     <= 0;
            int_hold   <= 0;
            has_digits <= 0;
            pend_valid <= 0;
            inj_active <= 0;
            got_a <= 0; got_b <= 0; got_op <= 0;
            op_bits <= 4'b0000;
            opA <= 0; opB <= 0;
            scan_idx <= 0;
            prev_cr <= 0;
        end else begin
            case (state)

                COLLECT: begin
                    // waiting period
                    if (rx_done)
                        idle_count <= 0;
                    else if (line_in_progress) begin
                        if (idle_count == IDLE_LIMIT) begin
                            idle_count <= 0;
                            wr_ptr     <= 0;
                            int_hold   <= 0;
                            has_digits <= 0;
                            pend_valid <= 0;
                        end else
                            idle_count <= idle_count + 1;
                    end else
                        idle_count <= 0;

                    if (pend_valid) begin
                        // push the operator that was waiting behind a number flush
                        rx_buff[wr_ptr] <= {8'b0, pend_char};
                        wr_ptr <= wr_ptr + 1;
                        pend_valid <= 1'b0;
                    end else if (rx_done) begin
                        if (!is_eol) prev_cr <= 1'b0;
                        if (is_digit) begin
                            int_hold   <= int_hold * 10 + (rx_data - "0");
                            has_digits <= 1'b1;
                            echo_data  <= rx_data;
                            echo_valid <= 1'b1;
                        end else if (is_eol) begin
                            prev_cr <= (rx_data == 8'd13);
                            if (rx_data == 8'd10 && prev_cr) begin
                            end else begin
                            // prevents flushing of enter characters
                            if (has_digits) begin
                                rx_buff[wr_ptr] <= {1'b1, int_hold};
                                wr_ptr <= wr_ptr + 1;
                                int_hold <= 0;
                                has_digits <= 0;
                            end
                            scan_idx <= 0;
                            state <= EOL_CR;
                            end
                        end else if (is_space) begin
                            // spaces flush a pending number but are otherwise ignored
                            if (has_digits) begin
                                rx_buff[wr_ptr] <= {1'b1, int_hold};
                                wr_ptr <= wr_ptr + 1;
                                int_hold <= 0;
                                has_digits <= 0;
                            end
                            echo_data  <= rx_data;
                            echo_valid <= 1'b1;
                        end else begin
                            // operator (takes in only first operator)
                            if (has_digits) begin
                                rx_buff[wr_ptr] <= {1'b1, int_hold};
                                wr_ptr <= wr_ptr + 1;
                                int_hold <= 0;
                                has_digits <= 0;
                                pend_char  <= rx_data;   // push op next cycle
                                pend_valid <= 1'b1;
                            end else begin
                                rx_buff[wr_ptr] <= {8'b0, rx_data};
                                wr_ptr <= wr_ptr + 1;
                            end
                            echo_data  <= rx_data;
                            echo_valid <= 1'b1;
                        end
                    end
                end

                EOL_CR: begin
                    echo_data  <= 8'd13;
                    echo_valid <= 1'b1;
                    state <= EOL_LF;
                end

                EOL_LF: begin
                    echo_data  <= 8'd10;
                    echo_valid <= 1'b1;
                    state <= SCAN;
                end

                SCAN: begin
                    if (scan_idx == wr_ptr) begin
                        // no number at all (bare enter) -> nothing to do
                        state <= got_a ? BUILD : CLEAN;
                    end else begin
                        if (token[15]) begin
                            if (!got_a) begin
                                opA <= token[14:0]; got_a <= 1'b1;
                            end else if (!got_b) begin
                                opB <= token[14:0]; got_b <= 1'b1;
                            end
                        end else if (!got_op) begin
                            op_bits <= op_map(token[7:0]);
                            got_op  <= 1'b1;
                        end
                        scan_idx <= scan_idx + 1;
                    end
                end

                BUILD: begin
                    // opB defaults to 0 and op_bits to ADD. A number sent by itself is sent back basically
                    prog[0]  <= {4'b1100, 4'd7,  opA[7:0]};        // LI   r7, A
                    prog[1]  <= {4'b1100, 4'd8,  opB[7:0]};        // LI   r8, B
                    prog[2]  <= {op_bits, 4'd9,  4'd7, 4'd8};      // OP   r9, r7, r8
                    prog[3]  <= {4'b1101, 4'd10, 8'd0};            // LINT r10, 0
                    prog[4]  <= {4'b0011, 4'd9,  4'd9, 4'd10};     // OR   r9, r9, r10
                    prog[5]  <= {4'b1100, 4'd13, 8'd255};          // LI   r13, 255
                    prog[6]  <= {4'b1001, 4'd0,  4'd9, 4'd13};     // STORE r9 -> [255]
                    prog[7]  <= {4'b1100, 4'd7,  8'd13};           // LI   r7, '\r'
                    prog[8]  <= {4'b1001, 4'd0,  4'd7, 4'd13};     // STORE r7
                    prog[9]  <= {4'b1100, 4'd7,  8'd10};           // LI   r7, '\n'
                    prog[10] <= {4'b1001, 4'd0,  4'd7, 4'd13};     // STORE r7
                    prog[11] <= {4'b1100, 4'd7,  8'd0};            // clear r7
                    prog[12] <= {4'b1100, 4'd8,  8'd0};            // clear r8
                    prog[13] <= {4'b1100, 4'd9,  8'd0};            // clear r9
                    prog[14] <= {4'b1100, 4'd10, 8'd0};            // clear r10
                    prog[15] <= {4'b1100, 4'd13, 8'd0};            // clear r13
                    inj_active <= 1'b1;
                    state <= RUN;
                end

                RUN: begin
                    if (inj_pc == 5'd16) begin
                        inj_active <= 1'b0;
                        state <= CLEAN;
                    end
                end

                CLEAN: begin
                    wr_ptr <= 0;
                    int_hold <= 0;
                    has_digits <= 0;
                    pend_valid <= 0;   // stale pending operator must not leak into the next line
                    got_a <= 0; got_b <= 0; got_op <= 0;
                    op_bits <= 4'b0000;
                    opA <= 0; opB <= 0;
                    scan_idx <= 0;
                    state <= COLLECT;
                end

                default: state <= COLLECT;
            endcase
        end
    end

endmodule