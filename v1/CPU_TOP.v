module cpu_top (
    input  clk,
    input  button,
    input  uart_rx_line,
    output uart_tx_line
);

    reg [15:0] por_counter = 0;
    reg        por         = 1'b1;
    always @(posedge clk) begin
        if (por_counter != 16'hFFFF) por_counter <= por_counter + 1;
        else                         por         <= 1'b0;
    end

    wire button_reset_unused;
    button_debounce debounce (
        .clk(clk),
        .button_in(button),
        .reset(button_reset_unused)
    );

    wire reset = por | button_reset_unused;
    // Signals from the control unit
    wire        mem_write_enable;
    wire [7:0]  mem_addr;
    wire [15:0] mem_data_in;
    
    // communication from bodmos to the control unit
    wire        inj_active;
    wire [15:0] inj_instr;
    wire [4:0]  inj_pc;
    wire        cpu_stall;

    dummy_control_unit cpu (
        .clk(clk),
        .por(por),
        .button_reset_unused(button_reset_unused),
        .mem_write_enable(mem_write_enable),
        .mem_addr(mem_addr),
        .mem_data_in(mem_data_in),
        .inj_active(inj_active),
        .inj_instr(inj_instr),
        .inj_pc(inj_pc),
        .stall(cpu_stall)
    );


    // rx syncing
    reg rx_sync0 = 1'b1, rx_sync1 = 1'b1;
    always @(posedge clk) begin
        rx_sync0 <= uart_rx_line;
        rx_sync1 <= rx_sync0;
    end

    wire [7:0] rx_data;
    wire       rx_done;

    UART_RX #(.BAUD_RATE(115200), .CLK_FREQ(27000000)) rx_inst (
        .clk(clk),
        .rx(rx_sync1),
        .data_out(rx_data),
        .done(rx_done)
    );

    wire [7:0] echo_data;
    wire       echo_valid;

    bodmos bodmos_inst (
        .clk(clk),
        .reset(por),
        .rx_data(rx_data),
        .rx_done(rx_done),
        .echo_data(echo_data),
        .echo_valid(echo_valid),
        .inj_active(inj_active),
        .inj_pc(inj_pc),
        .inj_instr(inj_instr)
    );

    //ITOA Part

    reg         itoa_start;
    reg  [15:0] itoa_value;
    wire [7:0]  itoa_digit;
    wire        itoa_valid;
    wire        itoa_busy;
    wire        itoa_done;

    itoa itoa_inst (
        .clk(clk),
        .start(itoa_start),
        .value(itoa_value),
        .out_digit(itoa_digit),
        .valid_digit(itoa_valid),
        .busy(itoa_busy),
        .done(itoa_done)
    );

    // freeze the CPU's fetch while itoa is converting so raw-char stores
    assign cpu_stall = itoa_busy || itoa_start;

    reg [7:0] buffer [0:31];    
    reg [4:0] write_ptr = 0;    
    reg [4:0] read_ptr  = 0;

    // using 255 as bait and then shifting the storing of the data into the buffer
    wire uart_write = mem_write_enable && (mem_addr == 8'd255);
    reg uart_write_prev = 0;

    always @(posedge clk) begin
        itoa_start <= 1'b0;
        uart_write_prev <= uart_write;

        if (por) begin
            write_ptr <= 0;
        end else begin
            if (itoa_valid) begin
                buffer[write_ptr] <= itoa_digit;
                write_ptr <= write_ptr + 1;
            end else if (uart_write && !uart_write_prev) begin
                if (mem_data_in[15] == 1'b1) begin
                    // integer-flagged: convert to decimal first
                    itoa_value <= mem_data_in;
                    itoa_start <= 1'b1;
                end else begin
                    // raw ascii byte
                    buffer[write_ptr] <= mem_data_in[7:0];
                    write_ptr <= write_ptr + 1;
                end
            end
            
        end
    end

    reg       tx_start;
    reg [7:0] tx_data;
    wire      tx_busy;

    always @(posedge clk) begin
        tx_start <= 1'b0;  

        if (por) begin
            read_ptr <= 0;
        end else if (!tx_busy && !tx_start && (read_ptr != write_ptr)) begin
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