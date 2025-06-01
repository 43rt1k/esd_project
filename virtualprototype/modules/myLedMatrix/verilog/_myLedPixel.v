//============================================================
// File: _myLedPixel.v  (sequential version)
//------------------------------------------------------------
//  * Initial values for RED/GREEN/BLUE are all '1'.
//  * Per-pixel state is stored in flip-flops and updated on the
//    rising clock edge following the rule:
//        new_value <= old_value | colMask;
//    where  colMask  has a single '1' at the selected column.
//  * With this rule the design assumes **active-high** LED drive
//    (1 = LED ON, 0 = OFF).  If you need active-low outputs,
//    change the OR to an AND.
//============================================================
module _myLedPixel (
    input  wire        clock,       // system clock

    input  wire [3:0]  row,       // binary 0-12
    input  wire [3:0]  col,       // binary 0-9
    input  wire        enable,    // enable pixel update
    input  wire [1:0]  color,     // 00=R,01=G,10=B,11=W

    output wire  [3:0]  rowSel,    // row select (combinational)
    output wire  [9:0]  red,       // column lines (active-high)
    output wire  [9:0]  green,
    output wire  [9:0]  blue);

    // --------------------------------------------------------
    // Initial state: all LEDs OFF (all lines high)
    // --------------------------------------------------------


    reg [9:0] r_red   = 10'b1111111111;   // active-high RED plane
    reg [9:0] r_green = 10'b1111111111;   // active-high GREEN plane
    reg [9:0] r_blue  = 10'b1111111111;   // active-high BLUE plane

    reg [3:0] r_row;// = 4'b1111; // row select (active-high)
    reg [3:0] r_col; // row select (active-high)
    reg       r_enable;
    // --------------------------------------------------------


    assign red   = r_red;    // output RED plane
    assign green = r_green;  // output GREEN plane
    assign blue  = r_blue;   // output BLUE plane
    assign rowSel = r_row; // output row select

    
    always @(posedge clock) begin
      r_row <= row; // update row select on clock edge
      r_col <= col; // update column select on clock edge
      r_enable <= enable; // update enable on clock edge
    end

    always @(posedge clock) begin
      case (color)
            2'b00: r_red   [r_col] <= ~r_enable; // clear the column bit
            2'b01: r_green [r_col] <= ~r_enable;
            2'b10: r_blue  [r_col] <= ~r_enable;
          default: ;
      endcase
    end


endmodule
