`define HI 1'b1
`define LO 1'b0


module sevenSegShow (input wire        clock,
                                        reset,
                      input wire [24:0] s_III_Digits,
                      output wire [2:0] displaySelect,
                      output reg  [7:0] nSegments);

  reg [16:0] clockDivideReg;
  wire clockDivideZero = (clockDivideReg == 17'd0) ? `HI : `LO;

  always @(posedge clock)
    clockDivideReg <= (reset == `HI || clockDivideZero == `HI) ? 17'd74249 : clockDivideReg - 1;

  reg [2:0] displaySelectReg;
  
  always @(posedge clock)
    displaySelectReg <= ((displaySelectReg == 3'd0 && clockDivideZero == `HI) || reset == `HI) ? 3'd2 : 
                      (clockDivideZero == `HI) ? displaySelectReg - 1 : displaySelectReg;
  
  assign displaySelect = displaySelectReg;

  always @*
    case (displaySelectReg)
      2'd2    : nSegments <= ~s_III_Digits[7:0];
      2'd1    : nSegments <= ~s_III_Digits[15:8];
      default : nSegments <= ~s_III_Digits[23:16];
    endcase
endmodule
