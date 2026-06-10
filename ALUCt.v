`timescale 1ns / 1ps
module ALUCt (
    input        rst,
    input [1:0]  alu_op,
    input [2:0]  funct3,    
    input [6:0]  funct7,    
    output reg [3:0] ct_alu
);

always @(*) begin
    case(alu_op)
        2'b00: ct_alu = 4'b0010;      // add for lw/sw
        2'b01: ct_alu = 4'b0110;      // sub for beq
        2'b10: begin                   // R-type instructions
            if(funct7 == 7'b0000000 && funct3 == 3'b000)
                ct_alu = 4'b0010;     // add
            else if(funct7 == 7'b0000000 && funct3 == 3'b100)
                ct_alu = 4'b0100;     // xor
            else
                ct_alu = 4'b0000;
        end
        2'b11: begin                   // I-type special instructions (srai)
            if(funct7 == 7'b0100000 && funct3 == 3'b101)
                ct_alu = 4'b0101;     // srai
            else
                ct_alu = 4'b0000;
        end
        default: ct_alu = 4'b0000;
    endcase
end
endmodule
