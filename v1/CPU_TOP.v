module cpu_top (
    input  clk,
    input  button,
    output uart_tx_line
);

    wire reset;

    button_debounce debounce (
        .clk(clk),
        .button_in(button),
        .reset(reset)
    );

    // --- signals coming out of the CPU ---
    wire        mem_write_enable;
    wire [7:0]  mem_addr;
    wire [15:0] mem_data_in;

    dummy_control_unit cpu (
        .clk(clk),
        .reset(reset),
        .mem_write_enable(mem_write_enable),
        .mem_addr(mem_addr),
        .mem_data_in(mem_data_in)
    );

    reg [7:0] buffer [0:31];    
    reg [4:0] write_ptr = 0;    
    reg [4:0] read_ptr  = 0;

    // using 255 as bait and then shifting the storing of the data into the buffer
    wire uart_write = mem_write_enable && (mem_addr == 8'd255);

    always @(posedge clk) begin
        if (reset) begin
            write_ptr <= 0;
        end else if (uart_write) begin
            buffer[write_ptr] <= mem_data_in[7:0];
            write_ptr <= write_ptr + 1; 
        end
    end

    reg       tx_start;
    reg [7:0] tx_data;
    wire      tx_busy;

    always @(posedge clk) begin
        tx_start <= 1'b0;   // default: no pulse this cycle

        if (reset) begin
            read_ptr <= 0;
        end else if (!tx_busy && (read_ptr != write_ptr)) begin
            tx_data  <= buffer[read_ptr];
            tx_start <= 1'b1;
            read_ptr <= read_ptr + 1;     // wraps at 32 automatically
        end
    end

    UART_TX #(.BAUD_RATE(115200), .CLK_FREQ(27000000)) tx_inst (
        .clk     (clk),
        .start   (tx_start),
        .data_in (tx_data),
        .tx      (uart_tx_line),
        .busy    (tx_busy)
    );

endmodule