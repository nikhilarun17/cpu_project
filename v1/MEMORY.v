// Similar to RAM
// differnet from register which is like a scratch space and needs more entry points.. this has like 1 entry point for read and write.. so we can use it for memory
// data is fetched from here is worked in the ALU+reg (sort of like a scratch space) and then written back to memory if needed.

module dummy_memory (
    input             clk,
    input             we,          // write enable
    input      [7:0]  addr,        
    input      [15:0] data_in,     
    output reg [15:0] data_out     
);

    reg [15:0] mem [0:255];  
    // dummy_memory.v (you write this ONCE, never touch again)
    // initial begin
    //     `include "program_init.v"
    // end

    always @(posedge clk) begin
        if (we)
            mem[addr] <= data_in;
    end

    always @(*) begin
        data_out = mem[addr];
    end

endmodule