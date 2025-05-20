// sobelCi: Custom Instruction for Sobel Edge Detection (8-pixel version)
// Computes the Sobel gradient magnitude for a 3x3 window of grayscale pixels, excluding the center pixel.
// The 8 used pixels are packed into two 32-bit values (valueA, valueB).
// The result is the gradient magnitude for the center pixel (8 bits in LO).
`define HI 1'b1
`define LO 1'b0

module mySobelCI #(	parameter [7:0] 	 customId = 8'h0D)
									( input  wire        start,
										input  wire        clock,
										input  wire        reset,
										input  wire [31:0] valueA,    // p0 (7:0), p1 (15:8), p2 (23:16), p3 (31:24)
										input  wire [31:0] valueB,    // p5 (7:0), p6 (15:8), p7 (23:16), p8 (31:24)
										input  wire [7:0]  ciN,    // Custom instruction ID from the CPU

										output wire        done,
										output reg [31:0]  result);
	
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
	// Sobel Logic
	//========================================================================

	wire [10:0] dX_R = {3'b0, p2} + {2'b0, p5, 1'b0} + {3'b0, p8};
	wire [10:0] dX_L = {3'b0, p0} + {2'b0, p3, 1'b0} + {3'b0, p6};

	wire [10:0] dY_U = {3'b0, p0} + {2'b0, p1, 1'b0} + {3'b0, p2};
	wire [10:0] dY_D = {3'b0, p6} + {2'b0, p7, 1'b0} + {3'b0, p8};

	wire [10:0] dX_abs = (dX_R >= dX_L) ? (dX_R - dX_L) : (dX_L - dX_R);
	wire [10:0] dY_abs = (dY_D >= dY_U) ? (dY_D - dY_U) : (dY_U - dY_D);

	wire [10:0] magnitude = dX_abs + dY_abs;

	wire [7:0] s_result = (magnitude > MAG_MAX_11) ? MAG_MAX_8 : magnitude[7:0];


	//try to di with signed wire 

	
	//========================================================================
	// Result and done logic
	//========================================================================

	always @(posedge clock)
		if (reset || done == `LO) result <= 32'd0;
		else result <= {24'd0, s_result};


endmodule