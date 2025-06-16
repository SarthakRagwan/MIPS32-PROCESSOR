# MIPS32-PROCESSOR
IMPLEMENTED MIPS32-PROCESSOR USING PIPELINING 

Author : Sarthak Kumar

This project implements a simple 5-STAGE PIPELINED PROCESSOR in Verilog, including a fully functional testbench to simulate the pipeline behavior. The pipeline stages include Instruction Fetch, Instruction Decode, Execute, Memory Access, and Write Back.

Files :
- `main.v`: Verilog source code for the processor.
- `test.v`: Testbench for simulating the processor with a sample instruction sequence.
- `test.vcd`: Waveform output file.
- `README.md`: Documentation and usage instructions.

Features :
- 5-stage pipeline architecture:
  - Instruction Fetch (IF)
  - Instruction Decode (ID)
  - Execute (EX)
  - Memory Access (MEM)
  - Write Back (WB)
- Register file with 32 general-purpose registers
- 1024-word memory
- Basic instruction support (arithmetic, memory, branch, halt)
- Manual hazard mitigation via NOPs (dummy OR instructions)
- Simple testbench with output verification

How to Run :
Requirements:
- [Icarus Verilog](http://iverilog.icarus.com/)
- GTKWave (optional for waveform viewing)

Run Steps :\
`iverilog -o test.vvp test.v`\
`vvp test.vvp`\
`gtkwave test.vcd`   # optional

Pipeline stages :
IF → ID → EX → MEM → WB

Instruction Set Breakdown:

R-Type Instructions (Register-to-Register ALU Operations)
|Mnemonic 	|  Opcode  |  Format	      |    Description |
|----------|----------|----------------|----------------|
|ADD	      |  000000	 | ADD Rd, Rs, Rt	|  Rd = Rs + Rt  |
|SUB	      |  000001	 | SUB Rd, Rs, Rt	|  Rd = Rs - Rt  |
|AND	      |  000010	 | AND Rd, Rs, Rt	|  Rd = Rs & Rt  |
|OR	      |  000011	 | OR  Rd, Rs, Rt	|  Rd = Rs | Rt  |
|SLT	      |  000100	 | SLT Rd, Rs, Rt	|  Rd = (Rs < Rt) ? 1 : 0 |
|MUL	      |  000101	 | MUL Rd, Rs, Rt	|  Rd = Rs * Rt |

I-Type ALU Instructions (Register + Immediate)
|Mnemonic	|Opcode	  |Format	            |Description|
|---------|---------|-------------------|-----------|
|ADDI	    |001010	  |ADDI Rt, Rs, Imm	  |Rt = Rs + Imm|
|SUBI	    |001011	  |SUBI Rt, Rs, Imm	  |Rt = Rs - Imm|
|SLTI	    |001100	  |SLTI Rt, Rs, Imm	  |Rt = (Rs < Imm) ? 1 : 0|

Memory Instructions
|Mnemonic|	Opcode |	  Format	     |     Description|
|--------|---------|-----------------|-------------|
|LW	      |001000	  |LW Rt, Imm(Rs)	  |Rt = MEM[Rs + Imm]|
|SW	      |001001	  |SW Rt, Imm(Rs)	  |MEM[Rs + Imm] = Rt|

Branch Instructions
|Mnemonic	|  Opcode	 | Format	      |  Description|
|-----|----|-----|------|
|BEQZ	      |001110	  |BEQZ Rs, Imm	  |if (Rs == 0) PC += Imm|
|BNEQZ	     | 001101	 | BNEQZ Rs, Imm	  |if (Rs != 0) PC += Imm|

Halt
|Mnemonic|	  Opcode|	  Format|	  Description|
|---|---|----|----|
|HLT	        |111111	  |HLT	      |Halts the processor|

Instruction Encoding:

R-Type Format:
| 31-26 | 25-21 | 20-16 | 15-11 | 10-0 |
|-------|-------|-------|-------|------|
|Opcode |   Rs  |   Rt  |   Rd  |unused|

I-Type Format:
| 31-26 | 25-21 | 20-16 |       15-0       |
|-------|-------|-------|-------------|
|Opcode |   Rs  |   Rt  |     Immediate    |

Code Execution Flow: Step-by-Step Breakdown

1. Initialization (test.v)\
Clock Setup:\
Two separate clocks (clk1 and clk2) simulate alternate phases of the pipeline. This models real-world hardware where stages are triggered on different clock edges.

Register Initialization:\
All 32 general-purpose registers are initialized to their index values (R0 = 0, R1 = 1, ... R31 = 31).

Memory Initialization:\
A sample instruction sequence is loaded into memory to test basic arithmetic and control flow.

2. Instruction Fetch (IF Stage)\
Executed on clk1:\
The processor fetches the instruction at the PC (Program Counter) address.
It calculates the Next Program Counter (NPC) by incrementing PC.
These are stored in IF_ID_* pipeline registers to forward them to the decode stage.

Branch Logic:\
If a branch is taken (BEQZ, BNEQZ), it overrides normal PC flow and fetches from the target address instead.

3. Instruction Decode (ID Stage)\
Executed on clk2:\
Source register values (Rs and Rt) are read.\
Immediate values are sign-extended to 32 bits.\
Instruction type is classified (RR_ALU, LOAD, BRANCH, etc.) based on opcode.\
All values and type are forwarded to excution stage via ID_EX_* registers.

4. Execute (EX Stage)\
Executed on clk1:\
Performs the actual ALU operation depending on the instruction type:\
RR_ALU: uses A and B (from registers)\
RM_ALU: uses A and Imm\
LOAD: calculates effective memory address using A and Imm\
STORE:calculates effective memory address using Imm\
BRANCH: checks conditions and computes branch target using Imm\

5. Memory Access (MEM Stage)\
Executed on clk2:\
If it’s a LOAD, it reads from memory into the LMD (Load Memory Data).\
If it’s a STORE, it writes data to memory (unless a branch was taken).\
For arithmetic operations, this stage just passes values along unchanged.\
All results go into MEM_WB_* registers.

6. Write Back (WB Stage)\
Executed on clk1:\
Writes the result (either from ALU or memory) back to the destination register.
Halts the processor if the instruction is HLT.

7. Termination and Output\
In the testbench:\
Waits until the HLT instruction sets HALTED flag.

Block Diagram :\




