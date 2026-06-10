`timescale 1ns/1ps
module IFU(
    input        clk,
    input        rst,
    input        alu_zero,
    input        ct_branch,
    input        ct_jump,
    input  [31:0] ext_data,  
    output [31:0] inst
);
    reg [31:0] pc;
    reg [31:0] instRom [65535:0];

initial begin
    $readmemh("inst.data",instRom);
end

assign inst = instRom[pc[17:2]];

always@(posedge clk) begin
    if(!rst) begin
        pc <= 32'd0;
    end else begin
        if(ct_jump) begin
            pc <= pc + ext_data;  
        end else if(ct_branch && alu_zero) begin
            pc <= pc + ext_data;  
        end else begin
            pc <= pc + 32'd4;
        end
    end
end

endmodule
