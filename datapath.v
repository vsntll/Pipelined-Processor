`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: The Pennsylvania State University
// Engineer: Avie Vasantlal
// 
// Create Date: 08/14/2024 05:07:58 PM
// Design Name: 
// Module Name: datapath
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module datapath(
    input clk
    );

    wire [31:0] pc, nextPc, inst, inst_d, regOut1, regOut2, imm32, aluIn2, aluOut, memOut, writeData;
    wire [31:0] regOut1_x, regOut2_x, imm32_x, aluOut_m, regOut2_m, memOut_b, aluOut_b;
    wire [4:0] readAddr1, readAddr2, writeAddr, rt_d, rd_d, rs_d, rt_x, rd_x, rs_x, writeAddr_m, writeAddr_b;
    wire [5:0] op, func;
    wire [3:0] aluControl, aluControl_x;
    wire regWrite, memToReg, memWrite, aluSrc, regDst, memRead;
    wire regWrite_x, memToReg_x, memWrite_x, aluSrc_x, regDst_x, memRead_x;
    wire regWrite_m, memToReg_m, memWrite_m, memRead_m;
    wire regWrite_b, memToReg_b;
    wire [1:0] forwardA, forwardB;
    wire [31:0] forwardedA, forwardedB;
    wire stall;

    // fetch
    program_counter pcmodule(.clk(clk),.nextPc(nextPc), .stall(stall), .pc(pc));
    pc_adder pa(.pc(pc), .offset(32'd4), .nextPc(nextPc));
    inst_mem imem(.pc(pc), .inst(inst));

    IF_ID ifid(.clk(clk), .inst(inst), .inst_d(inst_d), .stall(stall));
    register_file rf(.readAddr1(inst_d[25:21]), .readAddr2(inst_d[20:16]), .writeAddr(writeAddr_b),
                     .writeData(writeData), .clk(clk), .regWrite(regWrite_b), .regOut1(regOut1), .regOut2(regOut2));
    control_unit cu(.op(inst_d[31:26]), .func(inst_d[5:0]), .regWrite(regWrite), .memToReg(memToReg), .stall(stall),
                    .memWrite(memWrite), .aluSrc(aluSrc), .regDst(regDst), .memRead(memRead), .aluControl(aluControl));
    imm_extend immext(.imm(inst_d[15:0]), .imm32(imm32));

    ID_EX idex(.clk(clk), .regWrite(regWrite), .memToReg(memToReg), .memWrite(memWrite), .aluSrc(aluSrc),
               .regDst(regDst), .memRead(memRead), .regOut1(regOut1), .regOut2(regOut2), .imm32(imm32),
               .rt(inst_d[20:16]), .rd(inst_d[15:11]), .rs(inst_d[25:21]), .aluControl(aluControl),
               .regWrite_x(regWrite_x), .memToReg_x(memToReg_x), .memWrite_x(memWrite_x), .aluSrc_x(aluSrc_x),
               .regDst_x(regDst_x), .memRead_x(memRead_x), .regOut1_x(regOut1_x), .regOut2_x(regOut2_x),
               .imm32_x(imm32_x), .rt_x(rt_x), .rd_x(rd_x), .rs_x(rs_x), .aluControl_x(aluControl_x));

    // executables
    FWunit fwd(.rs_x(rs_x), .rt_x(rt_x), .writeAddr_m(writeAddr_m), .writeAddr_b(writeAddr_b),
                        .regWrite_m(regWrite_m), .regWrite_b(regWrite_b),
                        .forwardA(forwardA), .forwardB(forwardB));

    mux_3x1_32b muxA(.in0(regOut1_x), .in1(aluOut_m), .in2(writeData), .sel(forwardA), .out(forwardedA));
    mux_3x1_32b muxB(.in0(regOut2_x), .in1(aluOut_m), .in2(writeData), .sel(forwardB), .out(forwardedB));

    mux_2x1_32b alumux(.in0(forwardedB), .in1(imm32_x), .sel(aluSrc_x), .out(aluIn2));
    alu alu_mod(.aluIn1(forwardedA), .aluIn2(aluIn2), .aluControl(aluControl_x), .aluOut(aluOut));
    mux_2x1_5b writeAddrMux(.in0(rt_x), .in1(rd_x), .sel(regDst_x), .out(writeAddr));

    EX_MEM exmem(.clk(clk), .regWrite_x(regWrite_x), .memToReg_x(memToReg_x), .memWrite_x(memWrite_x),
                 .memRead_x(memRead_x), .aluOut(aluOut), .regOut2_x(forwardedB), .writeAddr(writeAddr),
                 .regWrite_m(regWrite_m), .memToReg_m(memToReg_m), .memWrite_m(memWrite_m),
                 .memRead_m(memRead_m), .aluOut_m(aluOut_m), .regOut2_m(regOut2_m), .writeAddr_m(writeAddr_m));
    data_mem dmem(.clk(clk), .memWrite(memWrite_m), .memRead(memRead_m), .addr(aluOut_m),
                  .memIn(regOut2_m), .memOut(memOut));

    MEM_WB memwb(.clk(clk), .regWrite_m(regWrite_m), .memToReg_m(memToReg_m),
                 .aluOut_m(aluOut_m), .memOut(memOut), .writeAddr_m(writeAddr_m),
                 .regWrite_b(regWrite_b), .memToReg_b(memToReg_b),
                 .aluOut_b(aluOut_b), .memOut_b(memOut_b), .writeAddr_b(writeAddr_b));

    //write back
    mux_2x1_32b writeDataMux(.in0(aluOut_b), .in1(memOut_b), .sel(memToReg_b), .out(writeData));
    
    HZunit hu(.rt_x(rt_x), .rt_d(inst_d[20:16]), .rs_d(inst_d[25:21]), .memRead_x(memRead_x), .stall(stall));

endmodule
/* ================= Modules to implement for HW1 =====================*/
module program_counter(
    input clk,stall,
    input [31:0] nextPc,
    output reg [31:0] pc
    );
    initial begin
        pc = 32'd96; // PC initialized to start from 100.
    end
    // ==================== Students fill here BEGIN ====================
    always @(posedge clk) begin
        if (stall==0) begin
            pc <= nextPc; // update if no stall
        end
    end
    // ==================== Students fill here END ======================
endmodule

module pc_adder(
    input [31:0] pc, offset,
    output reg [31:0] nextPc
    );
    // ==================== Students fill here BEGIN ====================
    always @(*) begin
        nextPc = pc + offset;
    end
    // ==================== Students fill here END ======================
endmodule

/* ================= Modules to implement for HW3 =====================*/
module inst_mem(
    input [31:0] pc,
    output reg [31:0] inst
    );
    
    // This is an instruction memory that holds 64 instructions, 32b each.
    reg [31:0] memory [0:63];
    
    // Initializing instruction memory.
    initial begin       
        memory[25] = {6'b100011, 5'd0, 5'd1, 16'd0};
        memory[26] = {6'b100011, 5'd0, 5'd2, 16'd4};
        memory[27] = {6'b000000, 5'd1, 5'd2, 5'd3, 11'b00000100010};
        memory[28] = {6'b100011, 5'd3, 5'd4, 16'hFFFC};
        
//        memory[25] = {6'b100011, 5'd0, 5'd1, 16'd0};
//        memory[26] = {6'b100011, 5'd0, 5'd2, 16'd4};
//        memory[27] = {6'b100011, 5'd0, 5'd3, 16'd8};
//        memory[28] = {6'b100011, 5'd0, 5'd4, 16'd16};
//        memory[29] = {6'b000000, 5'd1, 5'd2, 5'd5, 11'b00000100000};
//        memory[30] = {6'b100011, 5'd3, 5'd6, 16'hFFFC};
//        memory[31] = {6'b000000, 5'd4, 5'd3, 5'd7, 11'b00000100010};

//    memory[25] = {6'b100011, 5'd0, 5'd1, 16'd0};
//    memory[26] = {6'b100011, 5'd0, 5'd2, 16'd4};
//    memory[27] = {6'b100011, 5'd0, 5'd4, 16'd16};
//    memory[28] = {6'b000000, 5'd1, 5'd2, 5'd3, 11'b00000100010};
//    memory[29] = {6'b100011, 5'd3, 5'd4, 16'hFFFC};

    end
    // ==================== Students fill here BEGIN ====================
    always @(*) begin
        inst = memory[pc[31:2]];
    end

    // ==================== Students fill here END ======================
endmodule

module register_file(
    input [4:0] readAddr1, readAddr2, writeAddr,
    input [31:0] writeData,
    input regWrite, clk,
    output reg [31:0] regOut1, regOut2
    );
    
    // Initializing registers. Do not touch here.
    reg [31:0] register [0:31]; // 32 registers, 32b each.
    integer i;
    initial begin
        for (i=0; i<32; i=i+1) begin
            register[i] = 32'd0; // Initialize to zero
        end
    end
    // ==================== Students fill here BEGIN ====================
    
    always @(*) begin
        regOut1= register[readAddr1];
        regOut2= register[readAddr2];
    end
    always @(negedge clk) begin
        case (regWrite)
        1:    register[writeAddr] <= writeData;
        endcase
        end
    
    // ==================== Students fill here END ======================
endmodule

module control_unit(
    input [5:0] op, func,
    input stall,
    output reg regWrite, memToReg, memWrite, aluSrc, regDst, memRead,
    output reg [3:0] aluControl
    );
    // ==================== Students fill here BEGIN ====================
    always@(*) begin 
        if (stall==1) begin
            regWrite=0;
            memToReg=0;
            memWrite=0;
            aluSrc=0;
            regDst=0;
            memRead=0;
            aluControl= 4'b0000;
         end else begin 
            
        case(op)
            6'b100011: begin //lw
            regDst = 1'b0;
            regWrite = 1'b1;
            aluSrc = 1'b1;
            aluControl = 4'b0010;
            memWrite = 1'b0;
            memRead = 1'b1;
            memToReg = 1'b1;
            end
    
            6'b101011: begin //sw
            regDst = 1'bx;
            regWrite = 1'b0;
            aluSrc = 1'b1;
            aluControl = 4'b0010;
            memWrite = 1'b1;
            memRead = 1'b0;
            memToReg = 1'bx;
            end
    
            6'b000000: begin //add/sub
                case(func)
                6'b100000: begin //add
                regDst = 1'b1;
                regWrite = 1'b1;
                aluSrc = 1'b0;
                aluControl = 4'b0010;
                memWrite = 1'b0;
                memRead = 1'b0;
                memToReg = 1'b0;
                end
        
            6'b100010: begin //sub
                regDst = 1'b1;
                regWrite = 1'b1;
                aluSrc = 1'b0;
                aluControl = 4'b0110;
                memWrite = 1'b0;
                memRead = 1'b0;
                memToReg = 1'b0;
            end
            endcase
        
        end
    
        default: begin  //dc
        regDst = 1'bx;
        regWrite = 1'bx;
        aluSrc = 1'bx;
        aluControl = 4'bx;
        memWrite = 1'bx;
        memRead = 1'bx;
        memToReg = 1'bx;
        end
        endcase
end
end 
     
    // ==================== Students fill here END ======================
endmodule

/* ================= Modules to implement for HW4 =====================*/
module imm_extend(
    input [15:0] imm,
    output reg [31:0] imm32
    );
    // ==================== Students fill here BEGIN ====================
    always @(*) begin
        imm32= {{16{imm[15]}}, imm};
        end
    // ==================== Students fill here END ======================
endmodule

module mux_2x1_32b(
    input [31:0] in0, in1,
    input sel,
    output reg [31:0] out
    );
    // ==================== Students fill here BEGIN ====================
    always @(*) begin
        case(sel)
        0: begin
        out = in0;
        end
        1: begin
        out=in1;
        end
        default: 
        out=5'b0;
        endcase
     end
    // ==================== Students fill here END ======================
endmodule

module alu(
    input [31:0] aluIn1, aluIn2,
    input [3:0] aluControl,
    output reg [31:0] aluOut
    );

    // ==================== Students fill here BEGIN ====================
    always @(*) begin
        aluOut=32'bx;
        case (aluControl)
            4'b0010:begin
            aluOut = aluIn1 + aluIn2; //add
            end
            
            4'b0110: begin
            aluOut = aluIn1 - aluIn2; //sub
            end
            default: begin
            aluOut = 32'b0; //0 is all else fails
            end
        endcase
    end
    // ==================== Students fill here END ======================
endmodule

module data_mem(
    input clk, memWrite, memRead,
    input [31:0] addr, memIn,
    output reg [31:0] memOut
    );
    
    reg [31:0] memory [0:63]; // 64x32 memory
    
    // Initialize data memory. Do not touch this part.
    initial begin
        memory[0] = 32'd16817;
        memory[1] = 32'd16801;
        memory[2] = 32'd16;
        memory[3] = 32'hDEAD_BEEF;
        memory[4] = 32'h4242_4242;
    end
    
    // ==================== Students fill here BEGIN ====================
    always @(*) begin
        case(memRead)
        1: memOut= memory[addr[31:2]];
        0: memOut= 32'bx;
        default: memOut = 32'bx;
        endcase
        end
    always @(negedge clk) begin 
        case (memWrite)
        1: memory[addr[31:2]] <= memIn;
        endcase 
    end
    
    // ==================== Students fill here END ======================
endmodule

/* ================= Modules to implement for HW5 =====================*/
module mux_2x1_5b(
    input [4:0] in0, in1,
    input sel,
    output reg [4:0] out
    );
    // ==================== Students fill here BEGIN ====================
    always @(*) begin
        case(sel)
        0: begin
        out = in0;
        end
        1: begin
        out=in1;
        end
        default: 
        out=5'b0;
        endcase
    end 
    // ==================== Students fill here END ======================
endmodule

module IF_ID(
    input clk, stall,
    input [31:0] inst,
    output reg [31:0] inst_d
);
    initial begin
        inst_d = 32'd0;
    end
    always @(posedge clk) begin
        if (stall==0) begin
            inst_d <= inst; 
        end
    end
endmodule

module ID_EX(
    input clk,
    input regWrite, memToReg, memWrite, aluSrc, regDst, memRead,
    input [31:0] regOut1, regOut2, imm32,
    input [4:0] rt, rd,rs,
    input [3:0] aluControl,
    output reg regWrite_x, memToReg_x, memWrite_x, aluSrc_x, regDst_x, memRead_x,
    output reg [31:0] regOut1_x, regOut2_x, imm32_x,
    output reg [4:0] rt_x, rd_x,rs_x,
    output reg [3:0] aluControl_x
    );
    
    always @(posedge clk) begin
        regWrite_x <= regWrite;
        memToReg_x <= memToReg;
        memWrite_x <= memWrite;
        aluSrc_x <= aluSrc;
        regDst_x <= regDst;
        memRead_x <= memRead;
        regOut1_x <= regOut1;
        regOut2_x <= regOut2;
        imm32_x <= imm32;
        rt_x <= rt;
        rd_x <= rd;
        rs_x <= rs;
        aluControl_x <= aluControl;
    end
 endmodule
 
 
 module EX_MEM(
    input clk,
    input regWrite_x, memToReg_x, memWrite_x, memRead_x,
    input [31:0] aluOut, regOut2_x,
    input [4:0]  writeAddr,
    output reg regWrite_m, memToReg_m, memWrite_m, memRead_m,
    output reg [31:0] aluOut_m, regOut2_m,
    output reg [4:0] writeAddr_m
    );
    
    always @(posedge clk) begin 
        regWrite_m <= regWrite_x;
        memToReg_m <= memToReg_x;
        memWrite_m <= memWrite_x;
        memRead_m <= memRead_x;
        aluOut_m <= aluOut;
        regOut2_m <= regOut2_x;
        writeAddr_m <= writeAddr;
    end
    endmodule

module MEM_WB (
    input clk,
    input regWrite_m, memToReg_m,
    input [31:0] aluOut_m, memOut,
    input [4:0] writeAddr_m,
    output reg regWrite_b, memToReg_b,
    output reg [31:0] aluOut_b, memOut_b, 
    output reg [4:0] writeAddr_b
    );
    
    always @(posedge clk) begin
        regWrite_b <= regWrite_m;
        memToReg_b <= memToReg_m;
        aluOut_b <= aluOut_m;
        memOut_b <= memOut;
        writeAddr_b <= writeAddr_m;
    end
    endmodule

module FWunit (
    input [4:0] rs_x, rt_x, writeAddr_m, writeAddr_b,
    input regWrite_m, regWrite_b,
    output reg [1:0] forwardA, forwardB
    );
    
    always @(*) begin
        //default
        forwardA= 2'b00;
        forwardB= 2'b00;
        
        //MEM
        if (regWrite_m && (writeAddr_m != 0) && (writeAddr_m == rs_x)) begin
            forwardA = 2'b01; 
        //WB
        end else if (regWrite_b && (writeAddr_b != 0) && (writeAddr_b == rs_x)) begin
            forwardA = 2'b10;
        end
        
        //MEM
        if (regWrite_m && (writeAddr_m != 0) && (writeAddr_m == rt_x)) begin
            forwardB = 2'b01;
        //WB 
        end else if (regWrite_b && (writeAddr_b != 0) && (writeAddr_b == rt_x)) begin
            forwardB = 2'b10;
        end
    end
    endmodule

module mux_3x1_32b(
    input [31:0] in0, in1, in2,
    input [1:0] sel,
    output reg [31:0] out
);
    always @(*) begin
        case (sel)
            2'b00: out = in0; // Default
            2'b01: out = in1; // MEM
            2'b10: out = in2; // WB
            default: out = 32'bx; // UND
        endcase
    end
    endmodule

    
module HZunit(
    input [4:0] rt_x, rt_d, rs_d,
    input memRead_x,
    output reg stall
 );
    always @(*) begin
       stall = 0; //no stall
       
       if (memRead_x && ((rt_x == rs_d) || (rt_x == rt_d))) begin //ripped from lecture
       stall = 1; //stall
       end
       end
       endmodule
       
  