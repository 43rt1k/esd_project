


`timescale 1ns/1ps

module gpio_tb;

  // Parameters
  parameter nrOfInputs = 8;
  parameter nrOfOutputs = 8;
  parameter [31:0] Base = 32'h40000000;

  // DUT I/O
  reg clock;
  reg reset;

  reg [nrOfInputs-1:0] externalInputs;
  wire [nrOfOutputs-1:0] externalOutputs;

  reg beginTransactionIn;
  reg endTransactionIn;
  reg readNotWriteIn;
  reg dataValidIn;
  reg busErrorIn;
  reg busyIn;

  reg [31:0] addressDataIn;
  reg [3:0] byteEnablesIn;
  reg [7:0] burstSizeIn;

  wire endTransactionOut;
  wire dataValidOut;
  wire busErrorOut;
  wire [31:0] addressDataOut;

  // DUT instance
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

  // Clock generator
  always #5 clock = ~clock;

  // Simulation
  initial begin
    $dumpfile("gpio.vcd");
    $dumpvars(0, gpio_tb);

    clock = 0;
    reset = 1;
    beginTransactionIn = 0;
    endTransactionIn = 0;
    readNotWriteIn = 0;
    dataValidIn = 0;
    busErrorIn = 0;
    busyIn = 0;
    addressDataIn = 0;
    byteEnablesIn = 0;
    burstSizeIn = 0;
    externalInputs = 8'h5A;

    #20;
    reset = 0;

    // Start a read transaction
    #10;
    addressDataIn = Base;
    byteEnablesIn = 4'hF;
    burstSizeIn = 8'd0;
    readNotWriteIn = 1;
    beginTransactionIn = 1;
    #10;
    beginTransactionIn = 0;
    dataValidIn = 1;
    #10;
    dataValidIn = 0;
    endTransactionIn = 1;
    #10;
    endTransactionIn = 0;

    // Wait for response and check
    #20;

    if (addressDataOut !== 32'h0000005A)
      $display("TEST FAILED: Expected addressDataOut = 0x5A, got %h", addressDataOut);
    else
      $display("TEST PASSED: addressDataOut = %h", addressDataOut);

    if (dataValidOut !== 1'b1)
      $display("TEST WARNING: dataValidOut should be high at response cycle.");

    if (busErrorOut !== 1'b0)
      $display("TEST FAILED: Unexpected busErrorOut");

    #20;
    $finish;
  end

endmodule

