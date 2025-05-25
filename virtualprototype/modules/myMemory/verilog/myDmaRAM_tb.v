`timescale 1ns / 1ps
`define PIXEL_NB (256*2)

module myDmaRam_tb;
    reg [15:0] rgb565 [0:`PIXEL_NB];  // Only 8 pixels for demo

    reg clk = 0;
    reg reset = 1;
    reg start = 0;
    reg [31:0] valueA = 0;
    reg [31:0] valueB = 0;
    reg [7:0] ciN = 0;
    reg transactionGranted = 0;
    reg endTransactionIn = 0;
    reg dataValidIn = 0;
    reg busErrorIn = 0;
    reg [31:0] addressDataIn = 0;

    wire done;
    wire [31:0] result;
    wire requestTransaction;
    wire endTransactionOut;
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
        .endTransactionOut(endTransactionOut),
        .readNotWriteOut(readNotWriteOut),
        .byteEnablesOut(byteEnablesOut),
        .burstSizeOut(burstSizeOut),
        .addressDataOut(addressDataOut)
    );

    integer i;

    initial begin
        // Fill rgb565 with random values
        for (i = 0; i < `PIXEL_NB; i = i + 1) begin
            rgb565[i] = $random & 16'hFFFF;
        end
    end


    initial begin
        $dumpfile("dma.vcd");
        $dumpvars(0, myDmaRam_tb);


        #20 
        reset = 0; 
        #10;

        //DMA Init settings
        //1
        start = 1; ciN = 8'h14;
        valueA = (3'b001 << 10) | (1 << 9); //BUS_START_ADDR
        valueB = 32'h0000E000;
        #10 

        start = 0; ciN = 0; valueA = 0; valueB = 0;
        #40;
        
        //2
        start = 1; ciN = 8'h14;
        valueA = (3'b010 << 10) | (1 << 9); //MEM_START_ADDR
        valueB = 32'h00000000;
        #10 
        
        start = 0; ciN = 0; valueA = 0; valueB = 0;
        #40;
        
        //3
        start = 1; ciN = 8'h14;
        valueA = (3'b011 << 10) | (1 << 9); //BLOCK_SIZE
        valueB = 32'd256;
        #10 
        
        start = 0; ciN = 0; valueA = 0; valueB = 0;
        #40;

        //4
        start = 1; ciN = 8'h14;
        valueA = (3'b100 << 10) | (1 << 9); //BURST_SIZE
        valueB = 32'd31;
        #10 
        
        start = 0; ciN = 0; valueA = 0; valueB = 0;
        #40;

        //5
        start = 1; ciN = 8'h14;     
        valueA = (3'b101 << 10) | (1 << 9); //STATUS_R 
        valueB = 32'd1; //Bus to mem
        #10 
        
        start = 0; ciN = 0; valueA = 0; valueB = 0;
        #100;

        //DMA bus to DMA tranfer


        wait(requestTransaction == 1);
        transactionGranted = 1; 
        #10 
        transactionGranted = 0;
        #50;


        // Simulate pixel-by-pixel output with dataValidIn pulse
        for (i = 0; i < `PIXEL_NB; i = i + 2) begin
            addressDataIn = {rgb565[i], rgb565[i+1]}; 
            dataValidIn   = 1;
            #10;

            // dataValidIn   = 0;
            // addressDataIn = 0;
            // #5;
        end
        
        dataValidIn = 0; 
        addressDataIn = 32'd0;
        endTransactionIn = 1;
        #10

        endTransactionIn = 0;
        #200;


        $finish;
    end
endmodule
