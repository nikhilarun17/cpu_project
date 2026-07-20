module button_debounce(
    input clk,
    input button_in,
    output reg reset = 1'b1
);
    reg [19:0] debounce_counter = 0;
    reg button_stable = 1'b1;
    reg sync0 = 1'b1, sync1 = 1'b1;   // two-stage synchronizer

    always @(posedge clk) begin
        // synchronize the raw button signal first (avoids metastability)
        sync0 <= button_in;
        sync1 <= sync0;

        if (sync1 != button_stable) begin
            debounce_counter <= debounce_counter + 1;
            if (debounce_counter == 20'hFFFFF) begin
                button_stable <= sync1;
                reset <= ~sync1;
                debounce_counter <= 0;   // reset counter immediately after accepting
            end
        end else begin
            debounce_counter <= 0;
        end
    end

endmodule