`timescale 1ps/1ps
`include "main.v"

module test();
  reg clk1, clk2;
  integer k;

  // Instantiate the processor module
  mips32 mips(clk1, clk2);

  // Clock generation block
  // clk1 and clk2 alternate with a delay of 5 time units each
  initial begin
    clk1 = 0; clk2 = 0;
    mips.HALTED=0;
    mips.BRANCH_TAKEN=0;
    mips.PC=0;

    repeat (50) begin
      #5 clk1 = 1; #5 clk1 = 0;
      #5 clk2 = 1; #5 clk2 = 0;
    end
  end

  // Test stimulus block
  initial begin
        mips.MEM[200]=8;
        mips.REG[7]=0;

        mips.MEM[0]=32'h280a00c8; // ADDI R10,R0,200
        mips.MEM[1]=32'h28010001; // ADDI R1,R0,1
        mips.MEM[2]=32'h0ce77800;//DUMMY INSTRUCTION : OR R7,R7,R7
        mips.MEM[3]=32'h21420000;//LW R2 0(R10)
        mips.MEM[4]=32'h0ce77800;//DUMMY INSTRUCTION : OR R7,R7,R7
        mips.MEM[5]=32'h14410800;//MUL R1,R2,R1
        mips.MEM[6]=32'h2c420001;//SUBI R2,R2,1
        mips.MEM[7]=32'h0ce77800;//DUMMY INSTRUCTION : OR R7,R7,R7
        mips.MEM[8]=32'h3440fffc;// BNEQZ R2,LOOP(offset of -4)
        mips.MEM[9]=32'h2541fffe;//SW R1, -2(R10)
        mips.MEM[10]=32'hfc000000;//HLT
wait(mips.HALTED);
#10
    $display("MEM[200] : %d : MEM[198] : %d",mips.MEM[200],mips.MEM[198]);

  end

  // VCD (waveform) dump block
  initial begin
    $dumpfile("test.vcd");     // Output file for waveform data
    $dumpvars(0, test);        // Dump all variables in module 'test'
    $monitor("REG[1] : %d ",mips.REG[1]);
    #5000$finish;             // End simulation after 1000 time units
  end
endmodule