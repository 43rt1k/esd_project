`define HI 1'b1;  
`define LO 1'b0;

`define LO_(value) (value)'d0


module myDmaRam #( parameter [7:0]    customId = 8'h14 )
                 ( input wire         start,
                                      clock,
                                      reset,
                                      
                   input wire [31:0]  valueA, // Address
                                      valueB, // Data
                   input wire [7:0]   ciN,
                   output wire        done,
                   output wire [31:0] result,

                   // Bus interface signals
                   output wire        requestTransaction,
                   input wire         transactionGranted,
                   input wire         endTransactionIn,
                                      dataValidIn,
                                      busErrorIn,
                   input wire [31:0]  addressDataIn,
                   output reg         beginTransactionOut,
                   output reg         readNotWriteOut,
                   output reg [3:0]   byteEnablesOut,
                   output reg [7:0]   burstSizeOut,
                   output reg [31:0]  addressDataOut );

  //===============================================================================================
  // Local parameters for internal constants
  //===============================================================================================

  // Address bit ranges for various purposes
  localparam       LO_ADDR_HI_B       = 31,  // Highest bit of address bus
                   LO_ADDR_LO_B       = 10,  // Lowest bit used for address indexing
                   CF_HI_B            = 12, // High bit for DMA configuration field in address
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
  localparam [2:0] IDLE               = 3'd0,
                   INIT               = 3'd1,
                   REQUEST_BUS        = 3'd2,
                   SET_UP_TRANS       = 3'd3,
                   DO_READ            = 3'd4,
                   WAIT_END           = 3'd5;
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
  reg  [31:0] r_busStartAddr,      r_memoryStartAddr,  r_blockSize,         r_usedBurstSize;
  reg  [31:0] r_AddrDataIn,        r_result,           r_busStartAddrShad;
  reg  [9:0]  r_blockSizeShad;
  reg  [8:0]  r_ramCiAddr;
  reg  [2:0]  r_dmaState,          r_dmaNextState;
  reg         r_busError,          r_isSramRead,        r_endTransIn,       r_dataValidIn;

  wire [31:0] s_sramDataValue;
  wire [8:0]  s_dmaAddrCI;
  wire [7:0]  s_usedBurstSize;
  wire [2:0]  s_dmaConfig;
  wire        s_dmaDone,            s_isMyCi,            s_isSramWrite,       s_dmaWrite,         
              s_dmaIsAddrLO,        s_requestDmaIn,      s_ramCiWriteEnable,  s_transCompleted;

  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
  // Assigns
  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

  assign s_dmaConfig      = valueA[CF_HI_B:CF_LO_B];
  assign s_dmaWrite       = valueA[WRITE_B];
  assign s_dmaAddrCI      = valueA[8:0];

  assign s_dmaIsAddrLO    = (valueA[LO_ADDR_HI_B:LO_ADDR_LO_B] == `LO_(LO_ADDR_HI_B - LO_ADDR_LO_B + 1));
  assign result           = r_result;

  //=============================================================
  // CI Logic
  //=============================================================

  assign s_isMyCi       = start && (ciN == customId);
  assign s_isSramWrite  = s_dmaIsAddrLO && s_isMyCi && s_dmaWrite;
  assign done           = (s_isMyCi & s_dmaWrite) | r_isSramRead;
  
  // Read request for custom instruction interface
  always @(posedge clock) 
      if (reset)         begin r_isSramRead <= `LO;           end 
      else if (s_isMyCi) begin r_isSramRead <= (~s_dmaWrite); end

  // Configuration registers on write from custom instruction interface
  always @(posedge clock) begin
    if (reset) begin
                        r_busStartAddr    <= `LO_(32);
                        r_memoryStartAddr <= `LO_(32);
                        r_blockSize       <= `LO_(32);
                        r_usedBurstSize   <= `LO_(32);

    end else if (s_isMyCi && s_dmaWrite)
      case (s_dmaConfig)
        BUS_START_ADDR: r_busStartAddr         <= valueB;
        MEM_START_ADDR: r_memoryStartAddr[8:0] <= valueB[8:0];
        BLOCK_SIZE:     r_blockSize[9:0]       <= valueB[9:0];
        BURST_SIZE:     r_usedBurstSize[7:0]   <= valueB[7:0];
      endcase
  end

  // Result register based on readback selection
  always @(posedge clock)
    if (r_isSramRead)
      case (s_dmaConfig)
        MEM_DATA:         r_result <= s_sramDataValue;
        BUS_START_ADDR:   r_result <= r_busStartAddr;
        MEM_START_ADDR:   r_result <= r_memoryStartAddr;
        BLOCK_SIZE:       r_result <= r_blockSize;
        BURST_SIZE:       r_result <= r_usedBurstSize;
        STATUS_R:         r_result <= {`LO_(30), r_busError, ~(r_dmaState != IDLE)};
        default:          r_result <= `LO_(32);
      endcase
    else
      r_result <= `LO_(32);

  //=============================================================
  // BUS Logic
  //=============================================================

  wire[7:0]_maxBurstSize     = {2'd0, r_usedBurstSize[7:0]} + SINGLE_BLOCK;
  wire[7:0]_restingBlockSize = r_blockSizeShad - SINGLE_BLOCK;
  assign s_usedBurstSize    = (r_blockSizeShad > _maxBurstSize) ? r_usedBurstSize[7:0] :  _restingBlockSize[7:0];

  assign requestTransaction = r_dmaState == REQUEST_BUS;

  wire[2:0]_controlBits      = valueB[DMA_HI_B:DMA_LO_B];
  wire[2:0]_controlBitsValid = (_controlBits == START_BUS_TO_MEM) || (_controlBits == START_MEM_TO_BUT);

  assign s_requestDmaIn     = (s_dmaConfig == STATUS_R) && s_isMyCi && _controlBitsValid && valueB[0];
  assign s_dmaDone          = (r_blockSizeShad == `LO_(10)) || ((r_blockSizeShad == SINGLE_BLOCK) && r_endTransIn && r_dataValidIn);
  assign s_ramCiWriteEnable = (r_dmaState == DO_READ) && r_dataValidIn;
  assign s_transCompleted   = r_endTransIn && s_dmaDone;

  always @(posedge clock) 
    if (reset) begin
      r_dmaState <= IDLE;
      r_busError <= `LO;
    end else begin
      
      r_dmaState <= r_dmaNextState;
      if      (r_dmaState == INIT)     begin r_busError <= `LO; end 
      else if (r_dmaState == WAIT_END) begin r_busError <= `HI; end
    end
    


  always @(posedge clock) begin
    r_endTransIn  <= endTransactionIn;
    r_dataValidIn <= dataValidIn;
    r_AddrDataIn  <= addressDataIn;
  end

  always @(posedge clock) begin
    if (r_dmaState == IDLE) begin
      r_busStartAddrShad <= r_busStartAddr;
      r_blockSizeShad    <= r_blockSize[9:0];
      r_ramCiAddr        <= r_memoryStartAddr[8:0];

    end else if (s_ramCiWriteEnable) begin
      r_busStartAddrShad <= r_busStartAddrShad + ADDR_BYTE_INC;
      r_blockSizeShad    <= r_blockSizeShad - SINGLE_BLOCK;
      r_ramCiAddr        <= r_ramCiAddr + ADDR_RAM_INC;
    end
  end

  always @(posedge clock) begin
    if (r_dmaState == SET_UP_TRANS) begin
      beginTransactionOut <= `HI;
      readNotWriteOut     <= `HI;
      byteEnablesOut      <= BYTE_HI_ALL;
      burstSizeOut        <= s_usedBurstSize;
      addressDataOut      <= {r_busStartAddrShad[31:2], 2'd0};

    end else begin
      beginTransactionOut <= `LO;
      readNotWriteOut     <= `LO;
      byteEnablesOut      <= `LO_(4);
      burstSizeOut        <= `LO_(8);
      addressDataOut      <= `LO_(32);
    end
  end

  //=============================================================
  // Next state logic for DMA FSM
  //=============================================================

  always @(posedge clock)
    case (r_dmaState)
      INIT:                                       r_dmaNextState <= REQUEST_BUS;

      IDLE:         if      (s_requestDmaIn)      r_dmaNextState <= INIT;
                    else                          r_dmaNextState <= IDLE;

      REQUEST_BUS:  if      (transactionGranted)  r_dmaNextState <= SET_UP_TRANS;
                    else                          r_dmaNextState <= REQUEST_BUS;

      SET_UP_TRANS:                               r_dmaNextState <= DO_READ;

      DO_READ:      if      (busErrorIn)          r_dmaNextState <= WAIT_END;
                    else if (s_transCompleted)    r_dmaNextState <= IDLE;
                    else if (r_endTransIn)        r_dmaNextState <= REQUEST_BUS;
                    else                          r_dmaNextState <= DO_READ;

      WAIT_END:     if      (r_endTransIn)        r_dmaNextState <= IDLE;
                    else                          r_dmaNextState <= WAIT_END;

      default:                                    r_dmaNextState <= IDLE;

    endcase

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
                .addressA(s_dmaAddrCI),       // Address for port A from custom instruction
                .addressB(r_ramCiAddr),     // Address for port B from DMA controller
                .dataInA(valueB),             // Data input for port A
                .dataInB(r_AddrDataIn),     // Data input for port B
                .dataOutA(s_sramDataValue),   // Data output from port A
                .dataOutB());                 // Data output from port B (unused)


endmodule
