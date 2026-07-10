module button_debounce(
    input clk,
    input button_in,
    output reg reset = 1'b1
);
    reg [15:0] debounce_counter;
    reg button_stable = 1'b1; 

    always @(posedge clk) begin
        if (button_in != button_stable) begin
            debounce_counter <= debounce_counter + 1;
            if (debounce_counter == 16'hFFFF) begin
                button_stable <= button_in;
                reset <= ~button_in; 
            end
        end else begin
            debounce_counter <= 0;
        end
    end 

endmodule
