module myStatus (
    input wire clock,
    input wire requestTransaction,
    input wire transactionGranted,
    input wire beginTransaction,
    input wire endTransaction,
    input wire dataValid,
    input wire readNotWrite,
    input wire busError,
    input wire [3:0] byteEnables,
    input wire [7:0] burstSize,
    input wire [1:0] fsmState,

    output reg [3:0] rgbRow,
    output reg [9:0] red,
    output reg [9:0] green,
    output reg [9:0] blue
);

  reg [1:0] rowSelect = 0;

  always @(posedge clock) begin
    rowSelect <= rowSelect + 1;
    rgbRow <= 4'b0001 << rowSelect;

    case (rowSelect)
      // RED = status signals
      2'd0: begin
        red[0] <= requestTransaction;
        red[1] <= transactionGranted;
        red[2] <= beginTransaction;
        red[3] <= endTransaction;
        red[4] <= dataValid;
        red[5] <= readNotWrite;
        red[6] <= busError;
        red[9:7] <= 3'b000;  // Unused
        green <= 10'b0;
        blue <= 10'b0;
      end

      // GREEN = byteEnables, FSM state
      2'd1: begin
        green[3:0] <= byteEnables;
        green[4]   <= fsmState[0];
        green[5]   <= fsmState[1];
        green[9:6] <= 4'b0000;
        red <= 10'b0;
        blue <= 10'b0;
      end

      // BLUE = burstSize LSBs
      2'd2: begin
        blue <= {2'b00, burstSize[7:0]};
        red <= 10'b0;
        green <= 10'b0;
      end

      // Blank row
      2'd3: begin
        red <= 10'b0;
        green <= 10'b0;
        blue <= 10'b0;
      end
    endcase
  end
endmodule