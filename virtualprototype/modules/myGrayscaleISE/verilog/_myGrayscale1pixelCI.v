`define RGB_R_L 11
`define RGB_R_H 15
`define RGB_G_L 5
`define RGB_G_H 10
`define RGB_B_L 0
`define RGB_B_H 4

// For convenience, these define the bit ranges for the “normalized” values.
// In our grayscale computation, we treat red as 5 bits, green as 6 bits, and blue as 5 bits.
`define R_L 0
`define R_H 4
`define G_L 0
`define G_H 5
`define B_L 0
`define B_H 4

// Macros for multiplication by 3 using shifts and additions:
//   M_x2: Concatenates a zero at the MSB and LSB of the input (effectively shifting left by 1)
//   M_x3: Computes (input expanded by 2 bits) + (input shifted left by 1 with an extra zero)
//         which yields 3 × (input)
`define M_x2(w) {w, 1'b0}
`define M_x3(w) ({2'b0, w} + {1'b0, w, 1'b0})
`define M_x8(w) {w, 3'b0}       // Shifts left by 3 bits (multiplies by 8)
`define M_x16(w) {w, 4'b0}      // Shifts left by 4 bits (multiplies by 16)

module _myGrayscale1pixelCI(  input wire [15:0] rgb565,
                              output wire [7:0] grayscale );

  // Extract individual color components from the 16-bit RGB565 pixel.
  // Red is in bits [15:11] (5 bits), green in bits [10:5] (6 bits), blue in bits [4:0] (5 bits).
  wire [`R_H:`R_L]   _red   = rgb565[`RGB_R_H:`RGB_R_L];
  wire [`G_H:`G_L]   _green = rgb565[`RGB_G_H:`RGB_G_L];
  wire [`B_H:`B_L]   _blue  = rgb565[`RGB_B_H:`RGB_B_L];
  

  //=============================================================
  // Red Component Multiplication: Compute red * 54.
  // We compute red * 54 as follows:
  //   1. Multiply red by 3: _red_x3 = red * 3.
  //   2. Multiply that result by 8 (i.e. shift left by 3) to get red * 24: _red_x24 = (red * 3) << 3.
  //   3. Sum red * 3 and red * 24 to get red * 27: _red_x27 = red * 3 + red * 24.
  //   4. Then multiply red * 27 by 2 to yield red * 54: _red_x54 = (red * 27) << 1.
  //=============================================================
  wire [`R_H+2:0] _red_x3 = `M_x3(_red);  // _red is 5 bits; result is 7 bits (red * 3).
  wire [`R_H+2+3:0] _red_x24 = `M_x8(_red_x3);  // Shifts _red_x3 left by 3 bits: red * 3 * 8 = red * 24 (10 bits).
  // Sum red * 3 and red * 24: we extend widths for proper addition.
  wire [`R_H+6:0] _red_x27 = {1'b0, _red_x24} + {4'b0, _red_x3}; // 11-bit result: red * 27.
  // Multiply by 2 to yield red * 54.
  wire [`R_H+6+1:0] _red_x54 = `M_x2(_red_x27); // 12-bit result: red * 54.

  //=============================================================
  // Blue Component Multiplication: Compute blue * 19.
  // We compute blue * 19 as:
  //   blue * 19 = (blue * 3) + (blue * 16)
  //=============================================================
  wire [`B_H+2:0] _blue_x3 = `M_x3(_blue);  // _blue is 5 bits; result is 7 bits (blue * 3).
  // Multiply blue by 16 by shifting left by 4 bits.
  wire [`B_H+4:0] _blue_x16 = `M_x16(_blue);  // 5+4 = 9 bits: blue * 16.
  // Sum: blue * 3 + blue * 16 = blue * 19.
  // Extend each term to proper width and add:
  wire [`B_H+4+1:0] _blue_x19 = {1'b0, _blue_x16} + {3'b0, _blue_x3}; // 12-bit result: blue * 19.

  //=============================================================
  // Green Component Multiplication: Compute green * 183.
  // The decomposition used here is: 183 = 27 + 156.
  // First, compute green * 3 and green * 24 to get green * 27.
  //=============================================================
  wire [`G_H+2:0] _green_x3 = `M_x3(_green); // _green is 6 bits; result is 8 bits (green * 3).
  wire [`G_H+2+3:0] _green_x24 = `M_x8(_green_x3); // Multiply by 8: (green * 3) << 3 = green * 24 (11 bits).
  wire [`G_H+6:0] _green_x27 = {1'b0, _green_x24} + {4'b0, _green_x3}; // 12-bit result: green * 27.
  
  // Next, compute green * 156.
  // One method: form green * 129 by concatenating two copies of _green with a zero in between.
  wire [`G_H+7:0] _green_x129 = {_green, 1'b0, _green};  // This concatenation produces a 14-bit value.
  // Then, add green * 27 shifted left by 1 (i.e., multiplied by 2) to _green_x129
  // to yield green * 183.
  // Here, {2'b0, _green_x27, 1'b0} shifts _green_x27 left by 1.
  wire [`G_H+8+1:0] _green_x183 = {1'b0, _green_x129} + {2'b0, _green_x27, 1'b0}; // 15-bit result: green * 183.

  //=============================================================
  // Final Grayscale Computation:
  // Compute the weighted sum:
  //   grayscale = (red*54 + blue*19 + green*183) / 256
  // Division by 256 is performed by taking the upper 8 bits of the final 16-bit sum.
  //=============================================================
  // Sum red and blue contributions.
  wire [12:2] _rbSum = {1'b0, _red_x54} + {1'b0, _blue_x19}; // 13-bit sum.
  // Add green contribution; extend widths to 16 bits.
  wire [15:2] _rgbSum = {3'b0, _rbSum} + {1'b0, _green_x183}; // 16-bit final sum.
  
  // Extract the upper 8 bits to perform the division by 256.
  assign grayscale = _rgbSum[15:8];

endmodule

