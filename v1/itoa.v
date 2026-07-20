module itoa(
    input clk,
    input start,
    input [15:0] value,
    output reg [7:0] out_digit,
    output reg valid_digit,
    output reg busy,
    output reg done
);

    reg [34:0] total_shift;
    reg [4:0]  shift_count;   // counts up to 15 (for total shifts)
    reg [2:0]  digit_index;   
    reg        seen_nonzero;  // for leading-zero suppression

    localparam IDLE   = 2'b00;
    localparam SHIFT  = 2'b01;
    localparam OUTPUT = 2'b10;
    localparam DONE   = 2'b11;

    reg [1:0] state = IDLE;
    reg [34:0] adjusted;
    reg [3:0] d;
    integer j;

    always @(posedge clk) begin
        valid_digit <= 1'b0; 
        done        <= 1'b0;

        case (state)
            IDLE: begin
                busy <= 1'b0;
                if (start && value[15] == 1'b1) begin
                    total_shift  <= {20'b0, value[14:0]};
                    shift_count  <= 0;
                    digit_index  <= 0;
                    seen_nonzero <= 1'b0;
                    busy         <= 1'b1;
                    state        <= SHIFT;
                end
            end

            SHIFT: begin
                // Double Dabble
                begin
                    adjusted = total_shift;
                    for (j = 0; j < 5; j = j + 1) begin
                        if (get_digit(adjusted, j) >= 4'd5)
                            adjusted[34 - j*4 -: 4] = adjusted[34 - j*4 -: 4] + 4'd3;
                    end
                    total_shift <= adjusted << 1;
                end

                if (shift_count == 5'd14) begin
                    state <= OUTPUT;
                end else begin
                    shift_count <= shift_count + 1;
                end
            end

            OUTPUT: begin
                begin
                    d = total_shift[34-4*digit_index -:4];

                    if (d != 0 || seen_nonzero || digit_index == 4) begin
                        out_digit   <= d + 8'd48;   //(ascii conversion)
                        valid_digit <= 1'b1;
                        seen_nonzero <= 1'b1;
                    end
                end

                if (digit_index == 4) begin
                    state <= DONE;
                end else begin
                    digit_index <= digit_index + 1;
                end
            end

            DONE: begin
                busy <= 1'b0;
                done <= 1'b1;
                state <= IDLE;
            end
        endcase
    end

endmodule