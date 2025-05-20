`define HI 1'b1         // Define TRUE as a 1-bit value of 1
`define LO 1'b0        // Define FALSE as a 1-bit value of 0


module myGPIO #(parameter        nrOfInputs = 8,
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

  //========================================================================
  // Internal Registers
  //========================================================================
  reg [nrOfOutputs-1:0] s_externalOutputsR;
  reg [nrOfInputs-1:0]  s_externalInputsR;

  reg        s_transactionActiveR, 
             s_beginTransactionR, 
             s_readNotWriteInR;
  reg [31:2] s_addressDataInR;
  reg [3:0]  s_byteEnablesInR;
  reg [7:0]  s_burstSizeInR;

  reg [31:0] s_addressDataOutR;
  reg        s_dataValidOutR;
  reg        s_endTransactionR;



  //========================================================================
  // Address decode logic
  //========================================================================

  wire s_isMyAction      = (s_addressDataInR == Base[31:2]) ? s_transactionActiveR : `LO;
  wire s_isCorrectAction = (s_byteEnablesInR == 4'hF && s_burstSizeInR == 8'd0);
  
  wire s_isReadAction    = s_isMyAction & s_isCorrectAction & s_readNotWriteInR;
  wire s_isWriteAction   = s_isMyAction & s_isCorrectAction & ~s_readNotWriteInR;
  
  // ============================================================================
  // Assign Outputs
  // ============================================================================

  assign externalOutputs   = s_externalOutputsR;
  assign addressDataOut    = s_addressDataOutR;
  assign dataValidOut      = s_dataValidOutR;
  assign endTransactionOut = s_endTransactionR;
  assign busErrorOut       = s_isMyAction & ~s_isCorrectAction;

  //========================================================================
  // Register logic for capturing transaction parameters
  //========================================================================

  always @(posedge clock) begin
    s_beginTransactionR <= beginTransactionIn;

    if (reset || endTransactionIn)  s_transactionActiveR  <= `LO;
    else if (beginTransactionIn)    s_transactionActiveR  <= `HI;

    if (beginTransactionIn) begin   s_readNotWriteInR     <= readNotWriteIn;
                                    s_addressDataInR      <= addressDataIn[31:2];
                                    s_byteEnablesInR      <= byteEnablesIn;
                                    s_burstSizeInR        <= burstSizeIn;
    end
  end
  
  
  // ============================================================================
  // Write Logic | CPU -> GPIO -> OUT PINS
  // ============================================================================
  always @(posedge clock) 
    if (reset)                                s_externalOutputsR <= {nrOfOutputs{1'b0}};
    else if (s_isWriteAction && dataValidIn)  s_externalOutputsR <= addressDataIn[nrOfOutputs-1:0];

  // ============================================================================
  // Read Logic | INP PINS -> GPIO -> CPU
  // ============================================================================
  always @(posedge clock) begin
    s_externalInputsR <= externalInputs;

    if (reset) begin
      
      s_dataValidOutR   <= `LO;
      s_addressDataOutR <= 32'd0;

    end else if (s_isReadAction && s_beginTransactionR) begin

      s_dataValidOutR   <= `HI;
      s_addressDataOutR <= { {(32-nrOfInputs){1'b0}}, s_externalInputsR };

    end else if (busyIn == `LO) begin
      s_dataValidOutR   <= `LO;
      s_addressDataOutR <= 32'd0;
    end
  end  
  // ============================================================================
  // End Transaction Signal
  // ============================================================================
  always @(posedge clock) 
    s_endTransactionR <= s_dataValidOutR & ~busyIn;


endmodule


