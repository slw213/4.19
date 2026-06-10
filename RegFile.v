`timescale 1ns/1ps
module RegFile(
    input        clk, //时钟
    input        rf_wen, //写使能（高有效）
    input  [4:0] rf_addr_r1, //读地址1
    input  [4:0] rf_addr_r2,
    input  [4:0] rf_addr_w, //写地址
    input  [31:0] rf_data_w, //写数据
    output  [31:0] rf_data_r1, //读数据1
    output  [31:0] rf_data_r2
);
    reg[31:0] regs[0:31];
    integer i;
    initial begin
        for(i=0;i<32;i=i+1)
            regs[i]=32'd0;
    end
    //读操作
    assign rf_data_r1=(rf_addr_r1==5'd0)?32'd0:regs[rf_addr_r1];
    assign rf_data_r2=(rf_addr_r2==5'd0)?32'd0:regs[rf_addr_r2];
    //写操作
    always@(negedge clk) begin
        // 写使能有效 且 不是写$0寄存器
        if (rf_wen&&(rf_addr_w!=5'd0)) begin
            regs[rf_addr_w]=rf_data_w;
        end
    end
endmodule
