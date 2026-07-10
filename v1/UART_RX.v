module UART_RX #(
    parameter BAUD_RATE = 115200,
    parameter CLK_FREQ  = 27000000
)(
    input            clk,
    input            rx,
    output reg [7:0] data_out,
    output reg       done
);

localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
localparam HALF_BIT     = CLKS_PER_BIT / 2;

localparam IDLE    = 2'd0;
localparam START   = 2'd1;
localparam RECEIVE = 2'd2;
localparam STOP    = 2'd3;

reg [1:0]  state     = IDLE;
reg [15:0] clkcount  = 0;
reg [2:0]  bitcount  = 0;
reg [7:0]  shift_reg = 0;

always @(posedge clk) begin
    done <= 0;

    case (state)
        IDLE: begin
            clkcount <= 0;
            bitcount <= 0;
            if (rx == 1'b0)
                state <= START;
        end

        START: begin
            if (clkcount == HALF_BIT - 1) begin
                if (rx == 1'b0) begin
                    clkcount <= 0;
                    state    <= RECEIVE;
                end else begin
                    state <= IDLE;
                end
            end else begin
                clkcount <= clkcount + 1;
            end
        end

        RECEIVE: begin
            if (clkcount == CLKS_PER_BIT - 1) begin
                clkcount  <= 0;
                shift_reg <= {rx, shift_reg[7:1]};
                bitcount  <= bitcount + 1;
                if (bitcount == 7)
                    state <= STOP;
            end else begin
                clkcount <= clkcount + 1;
            end
        end

        STOP: begin
            if (clkcount == CLKS_PER_BIT - 1) begin
                if (rx == 1'b1) begin
                    data_out <= shift_reg;
                    done     <= 1;
                end
                clkcount <= 0;
                state    <= IDLE;
            end else begin
                clkcount <= clkcount + 1;
            end
        end
    endcase
end

endmodule