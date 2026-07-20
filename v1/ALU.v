module dummy_alu(
    input [15:0] a,
    input [15:0] b,
    input [3:0] op,
    output reg [15:0] result,
    output reg check
);

always @(*) begin
    case(op)
        4'b0000: result = a + b; 
        4'b0001: result = a - b;
        4'b0010: result = a & b; 
        4'b0011: result = a | b; 
        4'b0100: result = a ^ b; 
        4'b0101: result = ~a;    
        4'b0110: result = (a < b) ? 16'd1 : 16'd0; 
        4'b0111: result = (a == b) ? 16'd1 : 16'd0;
        4'b1011: result = a; //jz check
        4'b1110: result = a * b;                      
        4'b1111: result = (b == 0) ? 16'd0 : a / b;    // DIV (div-by-zero -> 0)

        default: result = 0;
    endcase
    check = (result == 0); // for jump cases later on
end

endmodule