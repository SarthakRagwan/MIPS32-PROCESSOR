module mips32 (
    input CLK1, CLK2 // Two-phase clock: CLK1 (Fetch, Execute, Writeback), CLK2 (Decode, Memory)
);

    // === General Purpose Register File and Memory ===
    reg [31:0] REG [0:31];         // 32 general purpose registers (32-bit each)
    reg [31:0] MEM [0:1023];       // 1024-word memory (32-bit each)

    // === Program Counter and Pipeline Registers ===
    reg [31:0] PC;                 // Program counter
    reg [31:0] IF_ID_IR, IF_ID_NPC;                 // IF/ID pipeline registers
    reg [31:0] ID_EX_A, ID_EX_B, ID_EX_IMM;         // ID/EX operand/data registers
    reg [31:0] ID_EX_IR, ID_EX_NPC;                 // ID/EX instruction and next PC
    reg [31:0] EX_MEM_ALUOUT, EX_MEM_IR, EX_MEM_B;  // EX/MEM pipeline registers
    reg [31:0] MEM_WB_LOAD_DATA, MEM_WB_ALUOUT;     // MEM/WB data from memory or ALU
    reg [31:0] MEM_WB_IR;                           // MEM/WB instruction

    // === Control Signals ===
    reg EX_MEM_COND;           // Branch condition result (from Execute stage)
    reg HALTED;                // Processor halted flag
    reg BRANCH_TAKEN;          // Branch taken flag for avoiding incorrect memory writes

    // === Instruction Type (for control decoding) ===
    reg [2:0] ID_EX_INSTRU_TYPE, EX_MEM_INSTRU_TYPE, MEM_WB_INSTRU_TYPE;

    // === Opcode Definitions ===
    parameter ADD = 6'b000000, SUB = 6'b000001, AND = 6'b000010, OR = 6'b000011;
    parameter SLT = 6'b000100, MUL = 6'b000101, HLT = 6'b111111;
    parameter LW  = 6'b001000, SW = 6'b001001;
    parameter ADDI=6'b001010, SUBI=6'b001011, SLTI=6'b001100;
    parameter BNEQZ=6'b001101, BEQZ=6'b001110;

    // === Instruction Type Classification ===
    parameter RR_ALU = 3'b000, RM_ALU = 3'b001, LOAD = 3'b010;
    parameter STORE  = 3'b011, BRANCH = 3'b100, HALT = 3'b101;

    // === Instruction Fetch Stage (IF) ===
    // Triggered on CLK1. Fetches instruction and calculates NPC.
    always @(posedge CLK1) begin
        if (!HALTED) begin
            if ((EX_MEM_IR[31:26] == BEQZ && EX_MEM_COND) || (EX_MEM_IR[31:26] == BNEQZ && !EX_MEM_COND))begin
                // Branch taken: override PC with target address
                IF_ID_IR <= MEM[EX_MEM_ALUOUT];
                PC <= EX_MEM_ALUOUT+1;
                IF_ID_NPC <= EX_MEM_ALUOUT + 1;
                BRANCH_TAKEN <= 1'b1;
            end else begin
                // Normal fetch
                IF_ID_IR <= MEM[PC];
                IF_ID_NPC <= PC + 1;
                PC <= PC + 1;
                BRANCH_TAKEN <= 1'b0;
            end
        end
    end

    // === Instruction Decode Stage (ID) ===
    // Triggered on CLK2. Decodes opcode, fetches operands, calculates immediate.
    always @(posedge CLK2) begin
        if (!HALTED) begin
            ID_EX_IR <= IF_ID_IR;
            ID_EX_NPC <= IF_ID_NPC;

            // Register operands[REG[0] IS FIXED TO 32'b0]
            if(IF_ID_IR[25:21]==5'b00000)ID_EX_A <=32'b0;
            else ID_EX_A <= REG[IF_ID_IR[25:21]];
            if(IF_ID_IR[20:16]==5'b00000)ID_EX_B <=32'b0;
            else ID_EX_B <= REG[IF_ID_IR[20:16]];

            // Sign-extended immediate value to 32-bits
            ID_EX_IMM <= {{16{IF_ID_IR[15]}}, IF_ID_IR[15:0]};

            // Determine instruction type for control
            case (IF_ID_IR[31:26])
                ADD, SUB, AND, OR, SLT, MUL : ID_EX_INSTRU_TYPE <= RR_ALU;//REGISTER-REGISTER TYPE INSTRUCTION
                ADDI, SUBI, SLTI            : ID_EX_INSTRU_TYPE <= RM_ALU;//REGISTER-IMMEDIATE TYPE INSTRUCTION
                LW                          : ID_EX_INSTRU_TYPE <= LOAD;//REGISTER-IMMEDIATE TYPE INSTRUCTION
                SW                          : ID_EX_INSTRU_TYPE <= STORE;//REGISTER-IMMEDIATE TYPE INSTRUCTION
                BEQZ,BNEQZ                  : ID_EX_INSTRU_TYPE <= BRANCH;//REGISTER-IMMEDIATE TYPE INSTRUCTION
                HLT                         : ID_EX_INSTRU_TYPE <= HALT;//REGISTER-IMMEDIATE TYPE INSTRUCTION
                default                     : ID_EX_INSTRU_TYPE <= HALT; // Treat unknown as halt
            endcase
        end
    end

    // === Execute Stage (EX) ===
    // Triggered on CLK1. Performs ALU operations, address calculation, and branch evaluation.
    always @(posedge CLK1) begin
        if (!HALTED) begin
            EX_MEM_IR <= ID_EX_IR;
            EX_MEM_INSTRU_TYPE <= ID_EX_INSTRU_TYPE;
            BRANCH_TAKEN <= 1'b0;

            case (ID_EX_INSTRU_TYPE)
                RR_ALU: begin
                    case (ID_EX_IR[31:26])
                        ADD: EX_MEM_ALUOUT <= ID_EX_A + ID_EX_B;
                        SUB: EX_MEM_ALUOUT <= ID_EX_A - ID_EX_B;
                        MUL: EX_MEM_ALUOUT <= ID_EX_A * ID_EX_B;
                        SLT: EX_MEM_ALUOUT <= (ID_EX_A < ID_EX_B) ? 32'd1 : 32'd0;
                        AND: EX_MEM_ALUOUT <= ID_EX_A & ID_EX_B;
                        OR : EX_MEM_ALUOUT <= ID_EX_A | ID_EX_B;
                        default: EX_MEM_ALUOUT <= 32'hxxxxxxxx;
                    endcase
                end

                RM_ALU: begin
                    case (ID_EX_IR[31:26])
                        ADDI: EX_MEM_ALUOUT <= ID_EX_A + ID_EX_IMM;
                        SUBI: EX_MEM_ALUOUT <= ID_EX_A - ID_EX_IMM;
                        SLTI: EX_MEM_ALUOUT <= (ID_EX_A < ID_EX_IMM) ? 32'd1 : 32'd0;
                        default: EX_MEM_ALUOUT <= 32'hxxxxxxxx;
                    endcase
                end

                LOAD, STORE: begin
                    // Compute effective memory address
                    EX_MEM_ALUOUT <= ID_EX_A + ID_EX_IMM;
                    EX_MEM_B <= ID_EX_B;
                end

                BRANCH: begin
                    EX_MEM_COND <= (ID_EX_A == 0); // Only for BEQZ and BNEQZ here
                    EX_MEM_ALUOUT <= ID_EX_NPC + ID_EX_IMM;
                end
            endcase
        end
    end

    // === Memory Access Stage (MEM) ===
    // Triggered on CLK2. Performs memory read/write if required.
    always @(posedge CLK2) begin
        if (!HALTED) begin
            MEM_WB_IR <= EX_MEM_IR;
            MEM_WB_INSTRU_TYPE <= EX_MEM_INSTRU_TYPE;

            case (EX_MEM_INSTRU_TYPE)
                RR_ALU, RM_ALU: begin
                    MEM_WB_ALUOUT <= EX_MEM_ALUOUT;
                end
                LOAD: begin
                    MEM_WB_LOAD_DATA <= MEM[EX_MEM_ALUOUT]; // Load from memory
                end
                STORE: begin
                    if (!BRANCH_TAKEN) MEM[EX_MEM_ALUOUT] <= EX_MEM_B; // Avoid storing after branch taken
                end
            endcase
        end
    end

    // === Writeback Stage (WB) ===
    // Triggered on CLK1. Writes results to registers or halts processor.
    always @(posedge CLK1) begin
        if (!BRANCH_TAKEN) begin
            case (MEM_WB_INSTRU_TYPE)
                RR_ALU: REG[MEM_WB_IR[15:11]] <= MEM_WB_ALUOUT;
                RM_ALU: REG[MEM_WB_IR[20:16]] <= MEM_WB_ALUOUT;
                LOAD  : REG[MEM_WB_IR[20:16]] <= MEM_WB_LOAD_DATA;
                HALT  : HALTED <= 1'b1;
            endcase
        end
    end

endmodule
