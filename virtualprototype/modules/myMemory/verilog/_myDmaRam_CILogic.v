module dmaCiInterface #(
  parameter [7:0] CUSTOM_ID = 8'h14,
  parameter [2:0] MEM_DATA       = 3'b000,
  parameter [2:0] BUS_START_ADDR = 3'b001,
  parameter [2:0] MEM_START_ADDR = 3'b010,
  parameter [2:0] BLOCK_SIZE     = 3'b011,
  parameter [2:0] BURST_SIZE     = 3'b100,
  parameter [2:0] STATUS_R       = 3'b101
)(
  input  wire        clk,
  input  wire        reset,
  input  wire [7:0]  ciN,
  input  wire        start,
  input  wire [31:0] valueA,
  input  wire [31:0] valueB,
  input  wire [2:0]  dmaState,
  input  wire [2:0]  dmaConfig,
  input  wire        s_dmaWrite,
  input  wire        s_dmaIsAddrLO,
  input  wire [31:0] s_sramDataValue,
  output wire        s_isMyCi,
  output wire        s_isSramWrite,
  output wire        done,
  output reg         r_isSramRead,
  output reg  [31:0] r_busStartAddr,
  output reg  [31:0] r_memoryStartAddr,
  output reg  [31:0] r_blockSize,
  output reg  [31:0] r_usedBurstSize,
  output reg  [31:0] r_result,
  input  wire        r_busError
);

  // Check if this CI belongs to us
  assign s_isMyCi      = start && (ciN == CUSTOM_ID);
  assign s_isSramWrite = s_dmaIsAddrLO && s_isMyCi && s_dmaWrite;
  assign done          = (s_isMyCi && s_dmaWrite) || r_isSramRead;

  // Update read state
  always @(posedge clk)
    if (reset)
      r_isSramRead <= 1'b0;
    else if (s_isMyCi)
      r_isSramRead <= ~s_isSramWrite;

  // Configuration write logic
  always @(posedge clk) begin
    if (reset) begin
      r_busStartAddr    <= 32'b0;
      r_memoryStartAddr <= 32'b0;
      r_blockSize       <= 32'b0;
      r_usedBurstSize   <= 32'b0;
    end else if (s_isSramWrite) begin
      case (dmaConfig)
        BUS_START_ADDR: r_busStartAddr         <= valueB;
        MEM_START_ADDR: r_memoryStartAddr[8:0] <= valueB[8:0];
        BLOCK_SIZE:     r_blockSize[9:0]       <= valueB[9:0];
        BURST_SIZE:     r_usedBurstSize[7:0]   <= valueB[7:0];
      endcase
    end
  end

  // Read result logic
  always @* begin
    if (r_isSramRead) begin
      case (dmaConfig)
        MEM_DATA:       r_result = s_sramDataValue;
        BUS_START_ADDR: r_result = r_busStartAddr;
        MEM_START_ADDR: r_result = r_memoryStartAddr;
        BLOCK_SIZE:     r_result = r_blockSize;
        BURST_SIZE:     r_result = r_usedBurstSize;
        STATUS_R:       r_result = {30'b0, r_busError, ~(dmaState == IDLE)};
        default:        r_result = 32'b0;
      endcase
    end else begin
      r_result = 32'b0;
    end
  end

endmodule