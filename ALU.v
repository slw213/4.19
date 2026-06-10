`timescale 1ns/1ps
module ALU(
    input           rst,
    input     [3:0]  alu_ct,
    input     [31:0] alu_src1,
    input     [31:0] alu_src2,
    output           alu_zero,
    output reg[31:0] alu_res
);
    assign alu_zero=(alu_res==32'd0)?1'b1:1'b0;
    always@(*) begin
        case(alu_ct)
            4'b0010: alu_res = alu_src1 + alu_src2;           // add
            4'b0110: alu_res = alu_src1 - alu_src2;           // sub
            4'b0100: alu_res = alu_src1 ^ alu_src2;           // xor
            4'b0101: alu_res = $signed(alu_src1) >>> alu_src2[4:0];  // srai (arithmetic right shift)
            default: alu_res = 32'd0;
        endcase
    end
endmodule
