`timescale 1ns / 1ps

`define HI 1'b1
`define LO 1'b0

module gpio_tb;

  // Parameters
  localparam nrOfInputs  = 8;
  localparam nrOfOutputs = 8;
  localparam [31:0] Base = 32'h40000000;

  // Signals
  reg clock, reset;
  reg [nrOfInputs-1:0] externalInputs;
  wire [nrOfOutputs-1:0] externalOutputs;

  reg beginTransactionIn, endTransactionIn, readNotWriteIn;
  reg dataValidIn, busErrorIn, busyIn;
  reg [31:0] addressDataIn;
  reg [3:0] byteEnablesIn;
  reg [7:0] burstSizeIn;

  wire endTransactionOut, dataValidOut, busErrorOut;
  wire [31:0] addressDataOut;

  // Instantiate DUT
  gpio #(
    .nrOfInputs(nrOfInputs),
    .nrOfOutputs(nrOfOutputs),
    .Base(Base)
  ) uut (
    .clock(clock),
    .reset(reset),
    .externalInputs(externalInputs),
    .externalOutputs(externalOutputs),
    .beginTransactionIn(beginTransactionIn),
    .endTransactionIn(endTransactionIn),
    .readNotWriteIn(readNotWriteIn),
    .dataValidIn(dataValidIn),
    .busErrorIn(busErrorIn),
    .busyIn(busyIn),
    .addressDataIn(addressDataIn),
    .byteEnablesIn(byteEnablesIn),
    .burstSizeIn(burstSizeIn),
    .endTransactionOut(endTransactionOut),
    .dataValidOut(dataValidOut),
    .busErrorOut(busErrorOut),
    .addressDataOut(addressDataOut)
  );

  // Clock generation
  always #5 clock = ~clock;

  // Simulation
  initial begin
    $dumpfile("gpio.vcd");
    $dumpvars(0, gpio_tb);

    // Initialization
    clock = 0;
    reset = `HI;
    beginTransactionIn = `LO;
    endTransactionIn = `LO;
    readNotWriteIn = `LO;
    dataValidIn = `LO;
    busErrorIn = `LO;
    busyIn = `LO;
    addressDataIn = 32'd0;
    byteEnablesIn = 4'h0;
    burstSizeIn = 8'd0;
    externalInputs = 8'hA5;

    #20 reset = `LO;

    // ─────────────────────────────────────────────
    // 1. Shortest Read Transaction
    // ─────────────────────────────────────────────
    #50;
    addressDataIn = Base;
    byteEnablesIn = 4'hF;
    burstSizeIn = 8'd0;
    readNotWriteIn = `HI;
    beginTransactionIn = `HI;
    #10 beginTransactionIn = `LO;
    #20;

    // ─────────────────────────────────────────────
    // 2. General Read Transaction with busy delay
    // ─────────────────────────────────────────────
    #50;
    addressDataIn = Base;
    byteEnablesIn = 4'hF;
    burstSizeIn = 8'd0;
    readNotWriteIn = `HI;
    beginTransactionIn = `HI;
    #10 beginTransactionIn = `LO;
    busyIn = `HI;
    #20 busyIn = `LO;

    // ─────────────────────────────────────────────
    // 3. Write Transaction
    // ─────────────────────────────────────────────
    #50;
    addressDataIn = {Base[31:2], 2'b00} | 32'h000000A5; // Write value A5
    byteEnablesIn = 4'hF;
    burstSizeIn = 8'd0;
    readNotWriteIn = `LO;
    beginTransactionIn = `HI;
    #10 beginTransactionIn = `LO;
    dataValidIn = `HI;
    #10 dataValidIn = `LO;

    // ─────────────────────────────────────────────
    // 4. Busy Extended Write Transaction
    // ─────────────────────────────────────────────
    #50;
    addressDataIn = {Base[31:2], 2'b00} | 32'h0000005A; // Write value 5A
    byteEnablesIn = 4'hF;
    burstSizeIn = 8'd0;
    readNotWriteIn = `LO;
    beginTransactionIn = `HI;
    #10 beginTransactionIn = `LO;
    dataValidIn = `HI;
    busyIn = `HI;
    #20 busyIn = `LO;
    dataValidIn = `LO;

    #50;
    $display("Final externalOutputs = %h", externalOutputs);
    $display("Final addressDataOut  = %h", addressDataOut);

    $finish;
  end

endmodule