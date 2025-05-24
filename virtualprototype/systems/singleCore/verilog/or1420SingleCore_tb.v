`timescale 1ns / 1ps

module dma_request_tb;

  // Inputs
  reg         clk = 0;
  reg         rst = 1;
  reg         start = 0;
  reg  [7:0]  ciN = 8'h14;
  reg  [31:0] valueA = 0;
  reg  [31:0] valueB = 0;
  reg         transactionGranted = 0;
  reg         endTransactionIn = 0;
  reg         dataValidIn = 0;
  reg         busErrorIn = 0;
  reg  [31:0] addressDataIn = 32'hAABBCCDD;

  // Outputs
  wire        done;
  wire [31:0] result;
  wire        requestTransaction;
  wire        beginTransactionOut;
  wire        readNotWriteOut;
  wire [3:0]  byteEnablesOut;
  wire [7:0]  burstSizeOut;
  wire [31:0] addressDataOut;

  // Clock generation
  always #5 clk = ~clk;

  // Instantiate the DMA module
  myDmaRam #(.customId(8'h14)) DUT (
    .start(start),
    .clock(clk),
    .reset(rst),
    .valueA(valueA),
    .valueB(valueB),
    .ciN(ciN),
    .done(done),
    .result(result),
    .requestTransaction(requestTransaction),
    .transactionGranted(transactionGranted),
    .endTransactionIn(endTransactionIn),
    .dataValidIn(dataValidIn),
    .busErrorIn(busErrorIn),
    .addressDataIn(addressDataIn),
    .beginTransactionOut(beginTransactionOut),
    .readNotWriteOut(readNotWriteOut),
    .byteEnablesOut(byteEnablesOut),
    .burstSizeOut(burstSizeOut),
    .addressDataOut(addressDataOut)
  );

  initial begin
    $dumpfile("dma_tb.vcd");
    $dumpvars(0, dma_request_tb);

    #20 rst = 0;

    // Write DMA_BUS_START_ADDR (bits 12:10 = 3'b001, bit 9 = 1)
    valueA = (3'b001 << 10) | (1'b1 << 9);
    valueB = 32'h0000E000;
    start = 1; #10 start = 0; #20;

    // Write DMA_MEM_START_ADDR (3'b010)
    valueA = (3'b010 << 10) | (1'b1 << 9);
    valueB = 32'h00000000;
    start = 1; #10 start = 0; #20;

    // Write BLOCK_SIZE (3'b011)
    valueA = (3'b011 << 10) | (1'b1 << 9);
    valueB = 32'd4;
    start = 1; #10 start = 0; #20;

    // Write BURST_SIZE (3'b100)
    valueA = (3'b100 << 10) | (1'b1 << 9);
    valueB = 32'd2;
    start = 1; #10 start = 0; #20;

    // Trigger DMA start (3'b101)
    valueA = (3'b101 << 10) | (1'b1 << 9);
    valueB = 32'b01; // START_BUS_TO_MEM
    start = 1; #10 start = 0; #20;

    // Simulate transaction granting
    wait(requestTransaction == 1);
    transactionGranted = 1; #10 transactionGranted = 0;
    #10;

    // Simulate data valid and transaction end
    dataValidIn = 1;
    endTransactionIn = 1; #10;
    dataValidIn = 0;
    endTransactionIn = 0; #10;

    #100;
    $finish;
  end

endmodule