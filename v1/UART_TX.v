module UART_TX #(
    parameter BAUD_RATE = 115200,
    parameter CLK_FREQ  = 27000000
)(
    input            clk,
    input            start,
    input      [7:0] data_in,
    output reg       tx   = 1'b1,
    output reg       busy = 1'b0
);

localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

reg [15:0] clkcount  = 0;
reg [3:0]  bitcount  = 0;
reg [9:0]  shift_reg = 10'h3FF;

always @(posedge clk) begin
    if (!busy) begin
        tx <= 1'b1;
        if (start) begin
            busy      <= 1'b1;
            clkcount  <= 0;
            bitcount  <= 0;
            shift_reg <= {1'b1, data_in, 1'b0};
            tx        <= 1'b0;
        end
    end else begin
        if (clkcount == CLKS_PER_BIT - 1) begin
            clkcount <= 0;
            tx       <= shift_reg[1];
            shift_reg <= {1'b1, shift_reg[9:1]};

            if (bitcount == 9) begin
                busy <= 1'b0;       // stop bit already in shift_reg[1]
            end else begin
                bitcount <= bitcount + 1;
            end
        end else begin
            clkcount <= clkcount + 1;
        end
    end
end

endmodule