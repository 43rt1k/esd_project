`timescale 1ns / 1ps

module myDmaRam_tb;

    reg clk = 0;
    reg reset = 1;
    reg start = 0;
    reg [31:0] valueA = 0;
    reg [31:0] valueB = 0;
    reg [7:0] ciN = 8'h14;
    reg transactionGranted = 0;
    reg endTransactionIn = 0;
    reg dataValidIn = 0;
    reg busErrorIn = 0;
    reg [31:0] addressDataIn = 32'h12345678;

    wire done;
    wire [31:0] result;
    wire requestTransaction;
    wire beginTransactionOut;
    wire readNotWriteOut;
    wire [3:0] byteEnablesOut;
    wire [7:0] burstSizeOut;
    wire [31:0] addressDataOut;

    always #5 clk = ~clk;

    myDmaRam dut (
        .start(start),
        .clock(clk),
        .reset(reset),
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
        $dumpfile("dma.vcd");
        $dumpvars(0, myDmaRam_tb);

        #20 reset = 0;

        #10;
        valueA = (3'b001 << 10) | (1 << 9); //BUS_START_ADDR
        valueB = 32'h0000E000;
        start = 1; #10 start = 0;

        #20;
        valueA = (3'b010 << 10) | (1 << 9); //MEM_START_ADDR
        valueB = 32'h00000000;
        start = 1; #10 start = 0;

        // #20;
        // valueA = (3'b011 << 10) | (1 << 9); //BLOCK_SIZE
        // valueB = 32'd8;
        // start = 1; #10 start = 0;
        
        // #20;
        // valueA = (3'b100 << 10) | (1 << 9); //BURST_SIZE
        // valueB = 32'd7;
        // start = 1; #10 start = 0;
        
        #20;
        valueA = (3'b101 << 10) | (1 << 9); 
        valueB = 32'd1;
        start = 1; #20 start = 0;

        #50;
        wait(requestTransaction == 1);
        transactionGranted = 1; 
        #20 transactionGranted = 0;
        #20;

        dataValidIn = 1; endTransactionIn = 1; #10;
        dataValidIn = 0; endTransactionIn = 0;

        #100;
        $finish;
    end
endmodule
