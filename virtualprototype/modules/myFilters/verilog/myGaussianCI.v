`define HI 1'b1
`define LO 1'b0

module myGaussianCI  #(	parameter [7:0] 	 customId = 8'h13)
                    	(	input  wire        start,
												input  wire        clock,
												input  wire        reset,
												input  wire [31:0] valueA, // p0 p1 p2 p3
												input  wire [31:0] valueB, // p5 p6 p7 p8
												input  wire [7:0]  ciN,    // Custom instruction number
												output wire        done,
												output wire [31:0] result);
	
	//========================================================================
  // Controll Logic
  //========================================================================

	assign done = (ciN == customId) ? start : `LO;

  //========================================================================
  // Address decode logic
  //========================================================================
	
	localparam logic [10:0] MAG_MAX_11 = 11'd255;
	localparam logic [10:0] MAG_MAX_8  = 8'd255;

	/* 	Pixel packing convention (excluding center):
	    p0   p1   p2     <- valueA[ 7:0], 	[15:8], 	[23:16]
	    p3   p4   p5     <- valueA[31:24], 	ignored, 	valueB[ 7:0]
	    p6   p7   p8     <- valueB[15:8], 	[23:16], 	[31:24]
	*/

	localparam P0_LO = 0;
	localparam P0_HI = 7;

	localparam P1_LO = 8;
	localparam P1_HI = 15;
	
	localparam P2_LO = 16;
	localparam P2_HI = 23;
	
	localparam P3_LO = 24;
	localparam P3_HI = 31;
	
	localparam P5_LO = 0;
	localparam P5_HI = 7;
	
	localparam P6_LO = 8;
	localparam P6_HI = 15;
	
	localparam P7_LO = 16;
	localparam P7_HI = 23;
	
	localparam P8_LO = 24;
	localparam P8_HI = 31;

	wire [7:0] p0 = valueA[P0_HI:P0_LO];
	wire [7:0] p1 = valueA[P1_HI:P1_LO];
	wire [7:0] p2 = valueA[P2_HI:P2_LO];
	wire [7:0] p3 = valueA[P3_HI:P3_LO];
	wire [7:0] p5 = valueB[P5_HI:P5_LO];
	wire [7:0] p6 = valueB[P6_HI:P6_LO];
	wire [7:0] p7 = valueB[P7_HI:P7_LO];
	wire [7:0] p8 = valueB[P8_HI:P8_LO];

	//========================================================================
	// Gaussian Logic
	//========================================================================

    wire [7:0] p4 = 8'd1; // Can be zero or come from external context

    // Gaussian weighted sum
    wire [15:0] weighted_sum = p0 + (p1 << 1) + p2 +
       												(p3 << 1) + (p4 << 2) + (p5 << 1) +
        											p6 + (p7 << 1) + p8;

    wire [7:0] blurred = weighted_sum[11:4]; // Divide by 16

    assign result = (reset || done == `LO) ? 32'd0 : {24'd0, blurred};

endmodule