module ramDmaCi #( parameter [7:0]    customId = 8'h00 )
                 ( input wire         start,
                                      clock,
                                      reset,
                   input wire [31:0]  valueA, // Address
                                      valueB, // Data
                   input wire [7:0]   ciN,
                   output wire        done,
                   output wire [31:0] result );

  //=============================================================
  // Local parameters for internal constants
  //=============================================================
  localparam TRUE           = 1'b1;
  localparam FALSE          = 1'b0;

  localparam ADDR_HIGH_BIT  = 31;
  localparam ADDR_LOW_BIT   = 10;
  localparam ADDR_ZERO      = 22'd0;

  localparam WRITE_BIT_POS  = 9;
  localparam ADDRESS_WIDTH  = 9;          // 512 entries → 2^9 = 512

  localparam BIT_WIDTH      = 32;

  localparam integer NUM_ENTRIES = (1 << ADDRESS_WIDTH);

  //=============================================================
  // Internal wires and registers
  //=============================================================
  wire [BIT_WIDTH-1:0] s_sramDataValue;

  //=============================================================
  // Custom instruction helpers
  //=============================================================
  wire COND_isValueA_ADDR_ZERO     = (valueA[ADDR_HIGH_BIT:ADDR_LOW_BIT] == ADDR_ZERO);
  wire COND_isValueA_WRITE_BIT_POS = (s_isMyCi & valueA[WRITE_BIT_POS]);
  wire COND_isValueA_READ_BIT_POS  = (s_isMyCi & ~valueA[WRITE_BIT_POS]);
  wire _isSramReadReg_TRUE        = (s_isSramReadReg == TRUE);

  //=============================================================
  // Custom instruction control logic
  //=============================================================
  wire s_isMyCi         = (ciN == customId) ? start : FALSE;
  wire s_isSramWrite    = COND_isValueA_ADDR_ZERO ? COND_isValueA_WRITE_BIT_POS : FALSE;
  wire s_isSramRead     = COND_isValueA_READ_BIT_POS;
  reg  s_isSramReadReg;

  assign done           = COND_isValueA_WRITE_BIT_POS | s_isSramReadReg;
  assign result         = _isSramReadReg_TRUE ? s_sramDataValue : 32'd0;

  always @(posedge clock) s_isSramReadReg <= ~reset & s_isSramRead;

  //=============================================================
  // Mapping the dual-ported memory (dualPortSSRAM instance)
  //=============================================================
  dualPortSSRAM #( .bitwidth(BIT_WIDTH),
                   .nrOfEntries(NUM_ENTRIES),
                   .readAfterWrite(0) ) memory
                 ( .clockA(clock),
                   .clockB(1'b0),
                   .writeEnableA(s_isSramWrite),
                   .writeEnableB(1'b0),
                   .addressA(valueA[ADDRESS_WIDTH-1:0]),
                   .addressB({ADDRESS_WIDTH{1'b0}}),
                   .dataInA(valueB),
                   .dataInB({BIT_WIDTH{1'b0}}),
                   .dataOutA(s_sramDataValue),
                   .dataOutB());

endmodule