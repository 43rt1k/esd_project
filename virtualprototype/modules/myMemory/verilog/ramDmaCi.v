`define LO(value) (value)'d0

module ramDmaCi #( parameter [7:0]    customId = 8'h00 )
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

  localparam HI = 1'b1;  // Logical high value
  localparam LO = `LO(1); // Logical low value, defined as 0

  // Address bit ranges for various purposes
  localparam ADDR_HI_BIT = 31;  // Highest bit of address bus
  localparam ADDR_LO_BIT = 10;  // Lowest bit used for address indexing
  localparam ADDR_ZERO   = `LO(22); // Constant zero for address comparison (22 bits)

  localparam ADDR_WIDTH  = 9;   // Width of RAM address bus (9 bits)
  localparam WRITE_BIT   = 9;   // Bit position indicating write operation in address
  localparam BIT_WIDTH   = 32;  // Data bus width (32 bits)

  localparam integer NUM_ENTRIES = (1 << ADDR_WIDTH); // Number of entries in RAM (512)
  localparam DMA_CONF_HI_BIT     = 12; // High bit for DMA configuration field in address

  // Localparam for read register selection - defines which register is accessed
  localparam [2:0] MEMORY_DATA        = 3'b000;
  localparam [2:0] BUS_START_ADDR     = 3'b001;
  localparam [2:0] MEMORY_START_ADDR  = 3'b010;
  localparam [2:0] BLOCK_SIZE         = 3'b011;
  localparam [2:0] BURST_SIZE         = 3'b100;
  localparam [2:0] STATUS_R           = 3'b101;

  // DMA controller FSM states (3-bit encoding)
  localparam [2:0] IDLE               = 3'd0;
  localparam [2:0] INIT               = 3'd1;
  localparam [2:0] REQUEST_BUS        = 3'd2;
  localparam [2:0] SET_UP_TRANS       = 3'd3;
  localparam [2:0] DO_READ            = 3'd4;
  localparam [2:0] WAIT_END           = 3'd5;

  // Control bits for DMA direction
  localparam [1:0] CTRL_START_BUS_TO_MEM = 2'b01; // Start DMA from bus to memory
  localparam [1:0] CTRL_START_MEM_TO_BUT = 2'b10; // Start DMA from memory to bus (likely typo 'BUT' means 'BUS')
  localparam       CTRL_DMA_HI_BIT       = 1;    // High bit position for control bits
  localparam       CTRL_DMA_LO_BIT       = 0;    // Low bit position for control bits
  
  // Constants for address and burst increments
  localparam [31:0] ADDR_BYTE_INC = 32'd4;  // Byte increment for address (32-bit word)
  localparam [8:0]  ADDR_RAM_INC  = 9'd1;   // RAM address increment (1)
  localparam [9:0]  SINGLE_BLOCK  = 10'd1;  // Single block size (1)
  localparam [3:0]  BYTE_HI_ALL   = 4'b1111; // Byte enables all high (all bytes enabled)
  
  //=============================================================
  // Custom instruction helper conditions
  //=============================================================

  // Check if the address portion of valueA equals zero (for custom instruction)
  wire BR_isValueA_ADDR_ZERO  = (valueA[ADDR_HI_BIT:ADDR_LO_BIT] == ADDR_ZERO);
  // Check if the write bit of valueA is set when the custom instruction is active
  wire BR_isValueA_WRITE_BIT  = (s_isMyCi & valueA[WRITE_BIT]);
  // Check if the read bit of valueA is set when the custom instruction is active
  wire BR_isValueA_READ_BIT   = (s_isMyCi & ~valueA[WRITE_BIT]);

  // Conditions for writing to specific registers based on address and custom instruction
  wire BR_BusStartAddr_r_W    = ((valueA[DMA_CONF_HI_BIT:WRITE_BIT] == {BUS_START_ADDR,    HI}) & (s_isMyCi));
  wire BR_memoryStartAddr_r_W = ((valueA[DMA_CONF_HI_BIT:WRITE_BIT] == {MEMORY_START_ADDR, HI}) & (s_isMyCi));
  wire BR_BlockSize_r_W       = ((valueA[DMA_CONF_HI_BIT:WRITE_BIT] == {BLOCK_SIZE,        HI}) & (s_isMyCi));
  wire BR_UsedBurstSize_r_W   = ((valueA[DMA_CONF_HI_BIT:WRITE_BIT] == {BURST_SIZE,        HI}) & (s_isMyCi));
  wire BR_Control_r_W         = ((valueA[DMA_CONF_HI_BIT:WRITE_BIT] == {STATUS_R,          HI}) & (s_isMyCi));

  // Conditions for block size shadow register values
  wire BR_blockSizeShad_r_LO  = s_blockSizeShad_r == `LO(10);      // Block size zero
  wire BR_blockSizeShad_r_LAST= s_blockSizeShad_r == SINGLE_BLOCK; // Block size one (last block)

  //=============================================================
  // DMA controller FSM helper conditions
  //=============================================================

  // State check signals for FSM states
  wire STATE_IDLE                = (s_dmaState_r == IDLE);
  wire STATE_INIT                = (s_dmaState_r == INIT);
  wire STATE_WAIT_END            = (s_dmaState_r == WAIT_END);
  wire STATE_REQUEST_BUS         = (s_dmaState_r == REQUEST_BUS);
  wire STATE_SET_UP_TRANSACTION  = (s_dmaState_r == SET_UP_TRANS);
  wire STATE_DO_READ             = (s_dmaState_r == DO_READ);

  //=============================================================
  // Internal wires and registers
  //=============================================================

  wire [BIT_WIDTH-1:0] s_sramDataValue; // Data output from SRAM

  reg [8:0] s_ramCiAddr_r;   // RAM address register for custom instruction interface
  wire      s_ramCiWriteEnable; // Write enable signal for RAM from bus interface

  // SDRAM control registers to hold DMA configuration parameters
  reg [31:0] s_busStartAddr_r;   // Bus start address register
  reg [8:0]  s_memoryStartAddr_r; // Memory start address register (RAM address)
  reg [9:0]  s_blockSize_r;      // Block size register (number of blocks to transfer)
  reg [7:0]  s_usedBurstSize_r;  // Burst size register (number of words per burst)

  // Bus input shadow registers to synchronize bus signals
  reg        s_endTransIn_r,    // Register to hold end of transaction signal
             s_dataValidIn_r;  // Register to hold data valid signal
  reg [31:0] s_AddrDataIn_r;    // Register to hold incoming address/data from bus

  // DMA finite-state machine (FSM) state registers
  reg [2:0] s_dmaState_r,       // Current FSM state
            s_dmaNextState_r;   // Next FSM state
  reg       s_busError_r;       // Bus error flag register

  // Output result register for custom instruction readback
  reg [31:0] s_result_r;

//–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
//–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
//–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
  
  // Dual-ported SRAM instantiation
  // Port A: accessed by custom instruction interface, clocked by 'clock'
  // Port B: accessed by DMA bus interface, clocked by inverted 'clock'
  dualPortSSRAM #( .bitwidth(32),
                   .nrOfEntries(512)) memory
                 ( .clockA(clock),
                   .clockB(~clock),
                   .writeEnableA(s_isSramWrite), // Write enable for port A
                   .writeEnableB(s_ramCiWriteEnable), // Write enable for port B
                   .addressA(valueA[8:0]),       // Address for port A from custom instruction
                   .addressB(s_ramCiAddr_r),     // Address for port B from DMA controller
                   .dataInA(valueB),             // Data input for port A
                   .dataInB(s_AddrDataIn_r),     // Data input for port B
                   .dataOutA(s_sramDataValue),   // Data output from port A
                   .dataOutB());                 // Data output from port B (unused)

//–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
//–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
//–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
  
  // Custom instruction control logic
  // Determine if current operation is for this custom instruction based on ID and start signal
  wire s_isMyCi         = (ciN == customId) ? start : LO;
  // Determine if SRAM write operation is requested by custom instruction (address zero and write bit set)
  wire s_isSramWrite    = BR_isValueA_ADDR_ZERO ? BR_isValueA_WRITE_BIT : LO;
  // Determine if SRAM read operation is requested by custom instruction (read bit set)
  wire s_isSramRead     = BR_isValueA_READ_BIT;
  reg  s_isSramRead_r; // Registered version of read signal for timing alignment

  // 'done' signal is asserted when a write or read operation completes
  assign done = BR_isValueA_WRITE_BIT | s_isSramRead_r;

  // Register read signal on clock, reset active low
  always @(posedge clock) s_isSramRead_r <= reset == LO & s_isSramRead;

  //=============================================================
  // Custom instruction output result
  //=============================================================

  // Multiplex output result based on address field [12:10] to select register to read
  always @*
    case (valueA[12:10])

      MEMORY_DATA       : s_result_r <= s_sramDataValue; // SRAM data output
      BUS_START_ADDR    : s_result_r <= s_busStartAddr_r; // Bus start address register
      MEMORY_START_ADDR : s_result_r <= {`LO(23), s_memoryStartAddr_r}; // Memory start address with upper bits zeroed
      BLOCK_SIZE        : s_result_r <= {`LO(22), s_blockSize_r}; // Block size with upper bits zeroed
      BURST_SIZE        : s_result_r <= {`LO(24), s_usedBurstSize_r}; // Burst size with upper bits zeroed
      STATUS_R          : s_result_r <= {`LO(30), s_busError_r, s_dmaIsBusy}; // Status register with error and busy flags

      default           : s_result_r <= `LO(32); // Default output zero

    endcase

  // Output result is valid only during SRAM read operation, else zero
  assign result = s_isSramRead_r == HI ? s_result_r : `LO(32);

//–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
//–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
//–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
  
  //=============================================================
  // DMA Configuration Registers (Bus to RAM)
  //=============================================================

  // Registers to hold DMA configuration parameters updated by custom instruction writes
  always @(posedge clock) begin

    if (reset) begin 
      // Reset all configuration registers to zero
      s_busStartAddr_r    <= `LO(32);
      s_memoryStartAddr_r <= `LO(9);
      s_blockSize_r       <= `LO(10);
      s_usedBurstSize_r   <= `LO(8);

    end else begin 

      // Update registers if corresponding write enable signals are active
      s_busStartAddr_r    <= BR_BusStartAddr_r_W       ? valueB      : s_busStartAddr_r;
      s_memoryStartAddr_r <= BR_memoryStartAddr_r_W    ? valueB[8:0] : s_memoryStartAddr_r;
      s_blockSize_r       <= BR_BlockSize_r_W          ? valueB[9:0] : s_blockSize_r;
      s_usedBurstSize_r   <= BR_UsedBurstSize_r_W      ? valueB[7:0] : s_usedBurstSize_r;

    end 
  end

  // FSM state and bus error registers update
  always @(posedge clock) begin
    
    if (reset) begin 
      s_dmaState_r <= IDLE;  // Reset FSM to IDLE
      s_busError_r <= LO;    // Clear bus error flag

    end else begin 

      s_dmaState_r <= s_dmaNextState_r; // Update FSM state to next state
      // Bus error flag is cleared on INIT state, set on WAIT_END state, else holds previous value
      s_busError_r <= STATE_INIT ? LO : STATE_WAIT_END ? HI : s_busError_r;

    end 
  end

  
  //=============================================================
  // DMA FSM: next-state logic
  //=============================================================

  // Extract control bits from valueB for DMA start commands
  wire [1:0] controlBits  = valueB[CTRL_DMA_HI_BIT:CTRL_DMA_LO_BIT];
  // Check if control bits correspond to valid DMA start commands
  wire controlBitsValid   = (controlBits == CTRL_START_BUS_TO_MEM) || (controlBits == CTRL_START_MEM_TO_BUT); 
  // DMA start signal is asserted when control register is written with valid control bits and start bit set
  wire s_requestDmaIn     = BR_Control_r_W && s_isMyCi && controlBitsValid && valueB[0];

  // DMA busy flag is high when not in IDLE state
  wire s_dmaIsBusy = STATE_IDLE ? LO : HI;;
  wire s_dmaDone;

  // Next state logic for DMA FSM
  always @* 
    case (s_dmaState_r)
      IDLE         : s_dmaNextState_r <= s_requestDmaIn ? INIT : IDLE; // Wait for DMA start request
      INIT         : s_dmaNextState_r <= REQUEST_BUS;                  // Initialize DMA, then request bus
      REQUEST_BUS  : s_dmaNextState_r <= transactionGranted ? SET_UP_TRANS : REQUEST_BUS; // Wait for bus grant
      SET_UP_TRANS : s_dmaNextState_r <= DO_READ;                     // Setup transaction, then start read
      DO_READ      : s_dmaNextState_r <= busErrorIn ? WAIT_END :      // On bus error, go to wait end
                                              (s_endTransIn_r && s_dmaDone) ? IDLE : // If end of transaction and done, go idle
                                              (s_endTransIn_r) ? REQUEST_BUS : DO_READ; // Else if end of transaction, request bus again, else continue read
      WAIT_END     : s_dmaNextState_r <= (s_endTransIn_r) ? IDLE : WAIT_END; // Wait for end of transaction to go idle
      default      : s_dmaNextState_r <= IDLE;                         // Default to IDLE state
    endcase


  //=============================================================
  // Bus Input Synchronization Registers
  //=============================================================

  // Synchronize bus input signals to internal registers on clock edge
  always @(posedge clock) begin
    s_endTransIn_r  <= endTransactionIn; // Shadow end of transaction input
    s_dataValidIn_r <= dataValidIn;      // Shadow data valid input
    s_AddrDataIn_r  <= addressDataIn;    // Shadow address/data input
  end

  //=============================================================
  // DMA Transfer Progress Registers
  //=============================================================

  reg [31:0] s_busStartAddrShad_r; // Shadow register for bus start address during DMA
  reg [9:0]  s_blockSizeShad_r;    // Shadow register for block size during DMA

  // Update shadow registers and RAM address register based on FSM state and write enable
  always @(posedge clock) begin

      if (s_dmaState_r == INIT) begin
        // On INIT state, load shadow registers from configuration registers
        s_busStartAddrShad_r <= s_busStartAddr_r;
        s_blockSizeShad_r    <= s_blockSize_r;
        s_ramCiAddr_r        <= s_memoryStartAddr_r; // Initialize RAM address for DMA

      end else if (s_ramCiWriteEnable) begin 
        // On write enable, increment bus start address and RAM address, decrement block size
        s_busStartAddrShad_r <= s_busStartAddrShad_r + ADDR_BYTE_INC;
        s_blockSizeShad_r    <= s_blockSizeShad_r - SINGLE_BLOCK;
        s_ramCiAddr_r        <= s_ramCiAddr_r + ADDR_RAM_INC;

      end else begin 
        // Otherwise hold current values
        s_busStartAddrShad_r <=  s_busStartAddrShad_r;
        s_blockSizeShad_r    <=  s_blockSizeShad_r;
        s_ramCiAddr_r        <=  s_ramCiAddr_r;

    end
  end
  
  // DMA done signal is asserted when block size is zero or last block and transaction ended with valid data
  assign s_dmaDone = BR_blockSizeShad_r_LO || 
                    (BR_blockSizeShad_r_LAST && s_endTransIn_r && s_dataValidIn_r);

  // RAM write enable is asserted during DO_READ state when data is valid
  assign s_ramCiWriteEnable = (STATE_DO_READ && s_dataValidIn_r);
  //=============================================================
  // DMA Bus Transaction Control Signals
  //=============================================================
  
  // Calculate maximum burst size as used burst size plus single block
  wire [9:0] s_maxBurstSize = {2'd0, s_usedBurstSize_r} + SINGLE_BLOCK;
  // Calculate remaining block size after subtracting single block
  wire [9:0] s_restingBlockSize = s_blockSizeShad_r - SINGLE_BLOCK;
  // Determine burst size to use based on remaining block size and max burst size
  wire [7:0] s_usedBurstSize = (s_blockSizeShad_r > s_maxBurstSize) ? s_usedBurstSize_r : s_restingBlockSize[7:0];

  // Request bus transaction when in REQUEST_BUS state
  assign requestTransaction = STATE_REQUEST_BUS;

  // Output control signals for bus transaction, updated on clock edge
  always @(posedge clock) begin

    if (STATE_SET_UP_TRANSACTION) begin
      // During SET_UP_TRANS state, assert signals to start transaction
      beginTransactionOut <= HI; 
      readNotWriteOut     <= HI; // Read operation
      byteEnablesOut      <= BYTE_HI_ALL; // Enable all bytes
      burstSizeOut        <= s_usedBurstSize; // Set burst size
      addressDataOut      <= {s_busStartAddrShad_r[31:2], 2'd0}; // Align address to word boundary
    
    end else begin
      // Otherwise, deassert signals and clear outputs
      beginTransactionOut <= LO;
      readNotWriteOut     <= LO;
      byteEnablesOut      <= `LO(4);
      burstSizeOut        <= `LO(8);
      addressDataOut      <= `LO(32);

    end
  end


endmodule
