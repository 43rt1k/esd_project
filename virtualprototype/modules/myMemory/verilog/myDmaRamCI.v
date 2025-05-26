`define HI     1'b1  
`define LO     1'b0
`define LO_4   4'b0
`define LO_8   8'b0
`define LO_10 10'b0
`define LO_22 22'b0
`define LO_23 23'b0
`define LO_24 24'b0
`define LO_30 30'b0
`define LO_32 32'b0



module myDmaRam #( parameter [7:0]    customId = 8'h14 )
                 ( input wire         start,
                                      clock,
                                      reset,
                                      
                   input wire [31:0]  valueA, // Address
                                      valueB, // Data
                   input wire [7:0]   ciN,
                   output wire        done,
                   output wire [31:0] result,


                    // Here the required bus signals are defined
                   output wire        requestTransaction,
                   input wire         transactionGranted,
                   input wire         endTransactionIn,
                                      dataValidIn,
                                      busErrorIn,
                                      busyIn,
                   input wire [31:0]  addressDataIn, //
                   output reg         beginTransactionOut, //
                   output reg         readNotWriteOut,
                   output wire        endTransactionOut,
                   output wire        dataValidOut,
                   output reg [3:0]   byteEnablesOut,
                   output reg [7:0]   burstSizeOut,
                   output reg [31:0]  addressDataOut );

  //===============================================================================================
  // Local parameters for internal constants
  //===============================================================================================

  // Address bit ranges for various purposes
  localparam       CF_HI_B            = 12, // High bit for DMA configuration field in address
                   CF_LO_B            = 10, // High bit for DMA configuration field in address
                   WRITE_B            = 9;  // Bit position indicating write operation in address
  // Localparam for read register selection - defines which register is accessed
  localparam [2:0] MEM_DATA           = 3'b000,
                   BUS_START_ADDR     = 3'b001,
                   MEM_START_ADDR     = 3'b010,
                   BLOCK_SIZE         = 3'b011,
                   BURST_SIZE         = 3'b100,
                   STATUS_R           = 3'b101;

  // DMA controller FSM states (3-bit encoding)
  localparam [3:0] IDLE               = 4'd0,
                   INIT               = 4'd1,
                   REQUEST_BUS        = 4'd2,
                   SET_UP_TRANS       = 4'd3,
                   DO_READ            = 4'd4,
                   WAIT_END           = 4'd5,
                   DO_WRITE           = 4'd6,    
                   END_TRANS_ERROR    = 4'd7,
                   END_WRITE_TRANS    = 4'd8;

  // Control bits for DMA direction
  localparam [1:0] START_BUS_TO_MEM   = 2'b01, // Start DMA from bus to memory
                   START_MEM_TO_BUT   = 2'b10; // Start DMA from memory to bus (likely typo 'BUT' means 'BUS')
  localparam       DMA_HI_B           = 1,    // High bit position for control bits
                   DMA_LO_B           = 0;    // Low bit position for control bits
  // Constants for address and burst increments
  localparam [31:0]ADDR_BYTE_INC      = 32'd4;  // Byte increment for address (32-bit word)
  localparam [8:0] ADDR_RAM_INC       = 9'd1;   // RAM address increment (1)
  localparam [9:0] SINGLE_BLOCK       = 10'd1;  // Single block size (1)
  localparam [3:0] BYTE_HI_ALL        = 4'b1111; // Byte enables all high (all bytes enabled)
  
  //=============================================================
  // Internal wires and registers
  //=============================================================
  // A "block" refers to a group of data words to be transferred in a single DMA operation.
  // A "burst" is a subset of a block, representing the number of consecutive data words transferred
  // in one bus transaction. Multiple bursts may be needed to complete a block transfer if the block
  // size exceeds the burst size.
  reg  [31:0] r_busStartAddr,     // Store the starting address for bus transactions
              r_memoryStartAddr,  // Store the starting address for memory transactions
              r_blockSize,        // Store the block size for DMA transfers
              r_usedBurstSize;    // Store the burst size used for DMA transfers

  reg  [31:0] r_addrDataIn,        r_result,           r_busStartAddrShad;
  reg  [9:0]  r_blockSizeShad;
  reg  [8:0]  r_memoryStartAddrShad;
  reg  [3:0]  r_dmaState,          r_dmaNextState;
  reg         r_busError,          r_isSramRead,        r_endTransIn,       r_dataValidIn;
  reg r_valB_bus2mem;
  reg r_dataValidOut;

  reg [8:0] r_wordsWrittenReg;
  reg [31:0] r_busRamData;
  wire [31:0] s_sramDataValue;
  wire [8:0]  s_valA_Addr;
  wire [7:0]  s_usedBurstSize;
  wire [2:0]  s_valA_Config;
  wire [1:0]  s_valB_sendMode;      
  wire                   s_isMyCi,            s_isSramWrite,       s_valA_Write,         
              s_valA_LO,        
              s_ramCiWriteEnable , s_valB_bus2mem;
  wire [31:0] s_busRamData;
  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
  // Assigns
  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

  
  assign result          = r_result;                          // Output result register to result port

  assign s_valA_LO       = (valueA[31:CF_HI_B+1] == `LO_22);  // Check if address bits [31:10] are all zero (indicates local access)
  assign s_valA_Config   = valueA[CF_HI_B:CF_LO_B];           // Extract DMA configuration field from valueA (bits 12:10)
  assign s_valA_Write    = valueA[WRITE_B];                   // Write operation flag from valueA (bit 9)
  assign s_valA_Addr     = valueA[8:0];                       // Address for custom instruction SRAM access (bits 8:0)
  
  assign s_valB_sendMode = valueB[DMA_HI_B:DMA_LO_B];
  assign s_valB_bus2mem  = valueB[DMA_LO_B];
  
  wire [31:0] s_valB_busStartAddr  = valueB;
  wire [31:0] s_valB_memStartAddr  = {`LO_23 ,valueB[8:0]};
  wire [31:0] s_valB_blockSize     = {`LO_22 ,valueB[9:0]};
  wire [31:0] s_valB_usedBurstSize = {`LO_24 ,valueB[7:0]};


  //=============================================================
  // CI Logic
  //=============================================================

  assign s_isMyCi       = start && (ciN == customId);
  assign s_isSramWrite  = s_valA_LO && s_isMyCi && s_valA_Write;
  assign done           = (s_isMyCi & s_valA_Write) | r_isSramRead;


  // Read request for custom instruction interface
  always @(posedge clock) 
      if (reset)         begin r_isSramRead <= `LO;           end 
      else if (s_isMyCi) begin r_isSramRead <= (~s_isSramWrite); end

  // Configuration registers on write from custom instruction interface
  always @(posedge clock) begin
    if (reset) begin
                        r_busStartAddr    <= `LO_32;
                        r_memoryStartAddr <= `LO_32;
                        r_blockSize       <= `LO_32;
                        r_usedBurstSize   <= `LO_32;

    end else if (s_isSramWrite)
      case (s_valA_Config)
        BUS_START_ADDR: r_busStartAddr    <= s_valB_busStartAddr;   //valueB;       //001
        MEM_START_ADDR: r_memoryStartAddr <= s_valB_memStartAddr;   //valueB[8:0];  //010
        BLOCK_SIZE:     r_blockSize       <= s_valB_blockSize;      //valueB[9:0];  //011
        BURST_SIZE:     r_usedBurstSize   <= s_valB_usedBurstSize; //valueB[7:0];  //101
      endcase
  end

  // Result register based on readback selection
  always @(posedge clock)
    if (r_isSramRead)
      case (s_valA_Config)
        MEM_DATA:         r_result <= s_sramDataValue;
        BUS_START_ADDR:   r_result <= r_busStartAddr;
        MEM_START_ADDR:   r_result <= r_memoryStartAddr;
        BLOCK_SIZE:       r_result <= r_blockSize;
        BURST_SIZE:       r_result <= r_usedBurstSize;
        STATUS_R:         r_result <= {`LO_30, r_busError, ~(r_dmaState == IDLE)};
        default:          r_result <= `LO_32;
      endcase
    else
      r_result <= `LO_32;

  //=============================================================
  // BUS Logic
  //=============================================================

  wire [7:0]  _maxBurstSize      = {2'd0, r_usedBurstSize[7:0]} + SINGLE_BLOCK; // Calculate the maximum burst size (used for burst transfers)
  wire [7:0]  _restingBlockSize  = r_blockSizeShad - SINGLE_BLOCK;              // Calculate the remaining block size after a burst
  assign      s_usedBurstSize    = (r_blockSizeShad > _maxBurstSize) ? r_usedBurstSize[7:0] : _restingBlockSize[7:0]; // Select the burst size to use for the current transaction



  assign      s_ramCiWriteEnable = (r_dmaState == DO_READ) && r_dataValidIn;   // Enable SRAM write from DMA when in DO_READ state and data is valid

  // Latch bus interface signals on each clock
  always @(posedge clock) begin
    r_endTransIn  <= endTransactionIn;
    r_dataValidIn <= dataValidIn;
    r_addrDataIn  <= addressDataIn;
  end

  always @(posedge clock)
    if (r_dmaState == DO_WRITE && ~busyIn && ~r_wordsWrittenReg[8])
      r_busRamData <= s_busRamData;

  // Shadow registers for burst/block management and address incrementing
  always @(posedge clock) begin
    if (r_dmaState == IDLE) begin
      r_busStartAddrShad    <= r_busStartAddr;
      r_blockSizeShad       <= r_blockSize;
      r_memoryStartAddrShad <= r_memoryStartAddr[8:0];

    end else if (s_ramCiWriteEnable) begin
      r_busStartAddrShad    <= r_busStartAddrShad    + ADDR_BYTE_INC; //+4
      r_blockSizeShad       <= r_blockSizeShad       - SINGLE_BLOCK;  //-1
      r_memoryStartAddrShad <= r_memoryStartAddrShad + ADDR_RAM_INC;  //+1
    end else if (s_doBusWrite) begin
      r_busStartAddrShad    <= r_busStartAddrShad    + ADDR_BYTE_INC;
      r_blockSizeShad       <= r_blockSizeShad       - SINGLE_BLOCK;
      r_memoryStartAddrShad <= r_memoryStartAddrShad + ADDR_RAM_INC;
      r_wordsWrittenReg     <= r_wordsWrittenReg - 1;
end
  end

  // Output bus transaction control signals based on DMA FSM state
  always @(posedge clock) begin
    if (r_dmaState == SET_UP_TRANS) begin
      beginTransactionOut <= `HI;
      readNotWriteOut <= r_valB_bus2mem;
      byteEnablesOut      <= BYTE_HI_ALL;
      burstSizeOut        <= s_usedBurstSize;
      addressDataOut      <= {r_busStartAddrShad[31:2], 2'd0};
      r_wordsWrittenReg <= {1'b0, s_usedBurstSize};

    end else begin
      beginTransactionOut <= `LO;
      readNotWriteOut     <= `LO;
      byteEnablesOut      <= `LO_4;
      burstSizeOut        <= `LO_8;
      addressDataOut      <= `LO_32;
    end
  end

  assign addressDataOut = (r_dmaState == DO_WRITE) ? r_busRamData : `LO_32;
  assign endTransactionOut = (r_dmaState == END_WRITE_TRANS || r_dmaState == END_TRANS_ERROR);
  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

  wire _dmaDone        = (r_blockSizeShad == `LO_10) || 
                         ((r_blockSizeShad == SINGLE_BLOCK) && r_dataValidIn); // DMA done when all blocks are transferred or last block is completed
  wire _transCompleted = r_endTransIn && _dmaDone;                  // Transaction is completed when endTransactionIn is asserted and DMA is done
  wire _controlBits    = (s_valB_sendMode == START_BUS_TO_MEM) || 
                         (s_valB_sendMode == START_MEM_TO_BUT); // Check if control bits indicate a valid DMA direction
  wire _requestDmaIn   = (s_valA_Config == STATUS_R) && s_isMyCi && s_valB_bus2mem && _controlBits; // Assert _requestDmaIn when a valid DMA request is detected via CI
  
  
  wire s_doBusWrite = (r_dmaState == DO_WRITE) && ~busyIn && ~r_wordsWrittenReg[8];

  always @* begin
    case (r_dmaState)
      //0
      IDLE:         if      (_requestDmaIn)       r_dmaNextState <= INIT;          //1
                    else                          r_dmaNextState <= IDLE;          //0
      //1
      INIT:                                       r_dmaNextState <= REQUEST_BUS;   //2
      //2
      REQUEST_BUS:  if      (transactionGranted)  r_dmaNextState <= SET_UP_TRANS;  //3
                    else                          r_dmaNextState <= REQUEST_BUS;   //2
      //3
      SET_UP_TRANS: if      (r_valB_bus2mem)      r_dmaNextState <= DO_READ;      //4
                    else                          r_dmaNextState <= DO_WRITE;     //6
      //4
      DO_READ:      if      (busErrorIn)          r_dmaNextState <= WAIT_END;      //5
                    else if (_transCompleted)     r_dmaNextState <= IDLE;          //0
                    else if (r_endTransIn)        r_dmaNextState <= REQUEST_BUS;   //2
                    else                          r_dmaNextState <= DO_READ;       //4
      //5
      WAIT_END:     if      (r_endTransIn)        r_dmaNextState <= IDLE;          //0
                    else                          r_dmaNextState <= WAIT_END;      //5

      DO_WRITE:     if      (busErrorIn)          r_dmaNextState <= END_TRANS_ERROR;
                    else if (r_wordsWrittenReg[8] && ~busyIn) r_dmaNextState <= END_WRITE_TRANS;
                    else                          r_dmaNextState <= DO_WRITE;

      END_WRITE_TRANS: if    (_dmaDone)           r_dmaNextState <= IDLE;
                       else                       r_dmaNextState <= REQUEST_BUS;

      default:                                    r_dmaNextState <= IDLE;          //0

    endcase
  end
  // DMA FSM state and error register update

  assign requestTransaction = (r_dmaState == REQUEST_BUS);                 // Assert requestTransaction when the DMA FSM is in the REQUEST_BUS state
  always @(posedge clock) begin
    if (reset) begin
      r_dmaState <= IDLE;
      r_busError <= `LO;
      r_valB_bus2mem   <= 1'b0;  // also reset it

    end else begin
      r_dmaState <= r_dmaNextState;

      if (r_dmaState == INIT) begin 
        r_busError     <= `LO;
        r_valB_bus2mem <= s_valB_bus2mem; // <-- HERE
      
      end else if (r_dmaState == WAIT_END) begin 
        r_busError <= `HI;
      
      end
    end
  end

  always @(posedge clock or posedge reset) begin
    if (reset)
      r_dataValidOut <= `LO;
    else
      r_dataValidOut <= (r_dmaState == DO_WRITE && ~busyIn && ~r_wordsWrittenReg[8]);
  end
  assign dataValidOut = r_dataValidOut;
  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––



  // Dual-ported SRAM instantiation
  // Port A: accessed by custom instruction interface, clocked by 'clock'
  // Port B: accessed by DMA bus interface, clocked by inverted 'clock'
  _mySSRAM #( .bitwidth(32),
              .nrOfEntries(512)) memory
            ( .clockA(clock),
              .clockB(~clock),
              .writeEnableA(s_isSramWrite), // Write enable for port A
              .writeEnableB(s_ramCiWriteEnable), // Write enable for port B
              .addressA(s_valA_Addr),       // Address for port A from custom instruction
              .addressB(r_memoryStartAddrShad),     // Address for port B from DMA controller
              .dataInA(valueB),             // Data input for port A
              .dataInB(r_addrDataIn),     // Data input for port B
              .dataOutA(s_sramDataValue),   // Data output from port A
              .dataOutB(s_busRamData));                 // Data output from port B (unused)


endmodule
