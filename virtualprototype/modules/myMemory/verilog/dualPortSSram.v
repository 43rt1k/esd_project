`define HI 1'b1
`define LO 1'b0


module dualPortSSRAM #( parameter                               bitwidth = 8,
                        parameter                               nrOfEntries = 512)
                      ( input wire                              clockA, 
                                                                clockB,
                                                                writeEnableA, 
                                                                writeEnableB,
                        input wire [$clog2(nrOfEntries)-1 : 0]  addressA, 
                                                                addressB,
                        input wire [bitwidth-1 : 0]             dataInA, 
                                                                dataInB,
                        output reg [bitwidth-1 : 0]             dataOutA, 
                                                                dataOutB);


  // Memory content declaration
  reg [bitwidth-1 : 0] memoryContent [nrOfEntries-1 : 0];

  //=============================================================
  // Port A (clockA domain): Read/Write Logic
  always @(posedge clockA) begin
    
    if (writeEnableA == `HI) memoryContent[addressA] = dataInA;

    dataOutA = memoryContent[addressA];

  end

  // Port B (clockB domain): Read/Write Logic
  always @(posedge clockB) begin

    if (writeEnableB == `HI) memoryContent[addressB] = dataInB;

    dataOutB = memoryContent[addressB];

  end

endmodule