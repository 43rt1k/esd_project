`define TRUE 1'b1            // Define logical TRUE (1-bit)
`define FALSE 1'b0           // Define logical FALSE (1-bit)

// Define bit ranges for splitting a 32-bit word into two 16-bit parts.
// These are used to split the incoming pixel words into two 16-bit RGB565 pixels.
`define P1_L 0
`define P1_H 15

`define P2_L 16
`define P2_H 31

`define P3_L 0
`define P3_H 15

`define P4_L 16
`define P4_H 31

// Define bit ranges for grouping grayscale output into four 8-bit parts.
// For example, the 32-bit grayscale result is partitioned into four bytes.
`define G1_L 0    // Lower bit of group 1
`define G1_H 7    // Higher bit of group 1
`define G2_L 8
`define G2_H 15
`define G3_L 16
`define G3_H 23
`define G4_L 24
`define G4_H 31

// Module: rgb565GrayscaleIse
// Description:
//   This module implements a custom instruction for converting four 16-bit RGB565
//   pixels into grayscale. It accepts two 32-bit inputs (valueA and valueB) that
//   contain two RGB565 pixels each. Due to a big/little-endian issue, the pixels are
//   passed directly (without swapping in this version) and then routed to four instances
//   of the rgb565Grayscale module. The four grayscale results are then collected into a
//   single 32-bit result.
//   The custom instruction is activated when the input ciN matches the parameter
//   customId and the `start` signal is high.
module myGrayscaleCI #(  parameter [7:0]      customId = 8'h11 )
                        ( input wire          start,    // Signal indicating custom instruction activation
                          input wire [31:0]   valueA,   // First 32-bit input; holds two RGB565 pixels
                                              valueB,   // Second 32-bit input; holds two RGB565 pixels
                          input wire [7:0]    ciN,    // Custom instruction ID from the CPU
                          output wire         done,     // Goes high when this custom instruction is active
                          output wire [31:0]  result    // 32-bit output containing four 8-bit grayscale values
                        );

  /* We compensate here for the big/little endian problem by proper slicing.
     The idea is to split the 32-bit input words into two 16-bit RGB565 pixels each,
     and then route each pixel to its corresponding grayscale converter instance. */
  
  // s_isMyIse is high when the provided instruction ID matches the module's customInstructionId
  // and the start signal is asserted.
  wire s_isMyIse = (ciN == customId) ? start : `FALSE;
  
  // s_grayScaleValues will collect the 8-bit grayscale values for the four pixels.
  wire [31:0] s_grayScaleValues;
  
  // The done output is high when this custom instruction is active.
  assign done   = s_isMyIse;
  // The result is s_grayScaleValues if active; otherwise, 0.
  assign result = (s_isMyIse == `TRUE) ? s_grayScaleValues : 32'd0;

  // Instantiate rgb565Grayscale modules for each pixel.
  // For valueA, we split it into two 16-bit chunks:
  //   - Pixel1 takes bits [15:0] of valueA.
  //   - Pixel2 takes bits [31:16] of valueA.
  /*
  rgb565Grayscale pixel1 ( .rgb565(valueA[`P1_H:`P1_L]),
                           .grayscale(s_grayScaleValues[`G1_H:`G1_L]));
  
  rgb565Grayscale pixel2 ( .rgb565(valueA[`P2_H:`P2_L]),
                           .grayscale(s_grayScaleValues[`G2_H:`G2_L]));
  
  // For valueB, we assume a similar split:
  //   - Pixel3 takes bits [15:0] of valueB.
  //   - Pixel4 takes bits [31:16] of valueB.
  rgb565Grayscale pixel3 ( .rgb565(valueB[`P3_H:`P3_L]),
                           .grayscale(s_grayScaleValues[`G3_H:`G3_L]));
  
  rgb565Grayscale pixel4 ( .rgb565(valueB[`P4_H:`P4_L]),
                           .grayscale(s_grayScaleValues[`G4_H:`G4_L]));
  

  */
  _myGrayscale1pixel pixel1 ( .rgb565({ valueA[`P1_L+7:`P1_L], valueA[`P1_H:`P1_L+8] }),
                              .grayscale(s_grayScaleValues[`G3_H:`G3_L]));

  _myGrayscale1pixel pixel2 ( .rgb565({ valueA[`P2_L+7:`P2_L], valueA[`P2_H:`P2_L+8] }),
                              .grayscale(s_grayScaleValues[`G4_H:`G4_L]));

  _myGrayscale1pixel pixel3 ( .rgb565({ valueB[`P3_L+7:`P3_L], valueB[`P3_H:`P3_L+8] }),
                              .grayscale(s_grayScaleValues[`G1_H:`G1_L]));

  _myGrayscale1pixel pixel4 ( .rgb565({ valueB[`P4_L+7:`P4_L], valueB[`P4_H:`P4_L+8] }),
                              .grayscale(s_grayScaleValues[`G2_H:`G2_L]));

  
endmodule