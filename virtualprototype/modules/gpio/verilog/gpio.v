`define HI 1'b1         // Define TRUE as a 1-bit value of 1
`define LO 1'b0        // Define FALSE as a 1-bit value of 0


module gpio #(parameter        nrOfInputs = 8,
              parameter        nrOfOutputs = 8,
              parameter [31:0] Base = 32'h40000000)
            ( input wire                    clock,
                                            reset,

              input wire [nrOfInputs-1:0]   externalInputs,
              output wire [nrOfOutputs-1:0] externalOutputs,

              // here the bus interface is defined
              input wire         beginTransactionIn,
                                 endTransactionIn,
                                 readNotWriteIn,

                                 dataValidIn,
                                 busErrorIn,
                                 busyIn,

              input wire [31:0]  addressDataIn,
              input wire [3:0]   byteEnablesIn,
              input wire [7:0]   burstSizeIn,

              output wire        endTransactionOut,
                                 dataValidOut,
                                 busErrorOut,
              output wire [31:0] addressDataOut);

  //===========================================================================
  // Regs
  //===========================================================================

  reg        s_beginTransactionReg, s_transactionActiveReg, s_readNotWriteReg;
  reg [31:2] s_addressDataInReg;
  reg [3:0]  s_byteEnablesReg;
  reg [7:0]  s_burstSizeReg;

  reg [nrOfOutputs-1:0] s_externalOutputsReg;

  reg [nrOfInputs-1:0] s_externalInputsReg;
  reg s_dataValidOutReg, s_endTransReg;
  reg [31:0] s_addressDataOutReg;

  //===========================================================================
  // Wires
  //===========================================================================

  wire s_isMyAction;      
  wire s_isCorrectAction; 
  wire s_isWriteAction;   
  wire s_isReadAction;    

  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
  // Here we flipflop all bus signals and determine the control and error signals
  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––


  assign s_isMyAction      = (s_addressDataInReg == Base[31:2]) ? s_transactionActiveReg : `LO;
  assign s_isCorrectAction = (s_byteEnablesReg == 4'hF && s_burstSizeReg == 8'd0) ? s_isMyAction : `LO;
  assign s_isWriteAction   = s_isMyAction & s_isCorrectAction & ~s_readNotWriteReg;
  assign s_isReadAction    = s_isMyAction & s_isCorrectAction & s_readNotWriteReg;
  
  assign busErrorOut = s_isMyAction & ~s_isCorrectAction;

  always @(posedge clock)
    begin

      s_beginTransactionReg <= beginTransactionIn;

      if (reset == `HI || endTransactionIn == `HI)  s_transactionActiveReg <= `LO;
      else if (beginTransactionIn == `HI)           s_transactionActiveReg <= `HI;

      if (beginTransactionIn == `HI) 
        s_readNotWriteReg   <= readNotWriteIn;
        s_addressDataInReg  <= addressDataIn[31:2];
        s_byteEnablesReg    <= byteEnablesIn;
        s_burstSizeReg      <= burstSizeIn;

    end
  
  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
  // Here we define the write action 
  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
   
  assign externalOutputs = s_externalOutputsReg;
  always @(posedge clock)

    if (reset == `HI)             
      s_externalOutputsReg <= {nrOfOutputs{`LO}};

    else if ( s_isWriteAction == `HI && dataValidIn == `HI)       
      s_externalOutputsReg <= addressDataIn[nrOfOutputs-1:0];

    else
      s_externalOutputsReg <= s_externalOutputsReg;

  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
  //Here we define the read action
  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
  
  
  assign dataValidOut      = s_dataValidOutReg;
  assign endTransactionOut = s_endTransReg;
  assign addressDataOut    = s_addressDataOutReg;
  
  always @(posedge clock) 
    begin
      s_externalInputsReg <= externalInputs;

      if (reset == `HI) begin
        s_dataValidOutReg <= `LO;
        s_addressDataOutReg <= 32'd0;

      end else if ( s_isReadAction == `HI && s_beginTransactionReg == `HI) begin
        s_dataValidOutReg <= `HI;
        s_addressDataOutReg <= { {(32-nrOfOutputs){`LO}} , s_externalInputsReg };

      end else if (busyIn == `LO) begin
        s_dataValidOutReg <= `LO;
        s_addressDataOutReg <= 32'd0;

      end

      s_endTransReg <= s_dataValidOutReg & ~busyIn;
    end    
    
               
endmodule


