module dummy_reg(
    input clk,
    input we, // write enable. basically us choosing if we write or not (blocks of next two inputs)
    input [3:0] wd_addr, // write address.
    input [15:0] wd_data,

    // read address and data for two registers
    input [3:0] ra_addr, 
    input [3:0] rb_addr,

    // read outputs
    output reg [15:0] ra_out,
    output reg [15:0] rb_out
);

    reg [15:0] registers [0:15]; 

    always @(posedge clk) begin
        if (we && wd_addr != 0) begin
            registers[wd_addr] <= wd_data; // write data to the specified register
        end
    end
    
    always @(*) begin
    ra_out = (ra_addr == 0) ? 16'b0 : registers[ra_addr];
    rb_out = (rb_addr == 0) ? 16'b0 : registers[rb_addr];
    end

endmodule


