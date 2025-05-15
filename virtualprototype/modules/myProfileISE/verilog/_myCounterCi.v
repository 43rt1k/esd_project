`define TRUE 1'b1         // Define TRUE as a 1-bit value of 1
`define FALSE 1'b0        // Define FALSE as a 1-bit value of 0

//–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

//–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
// Module: counter
// Description:
//   This module implements a simple up/down counter. It accepts a reset,
//   enable, and direction input, and it outputs a counter value that is
//   WIDTH bits wide. When direction is TRUE, the counter increments; when FALSE,
//   it decrements. If enable is FALSE, the counter holds its value. When reset is
//   asserted, the counter resets to zero.
//–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

module _myCounterCi #( parameter WIDTH = 8)  // Parameter WIDTH sets the bit-width; default is 8
                ( input wire reset,     // Reset signal: when TRUE, resets the counter to 0
                  input wire clock,     // Clock signal: counter updates occur on the rising edge
                  input wire enable,    // Enable signal: if FALSE, the counter holds its value
                  input wire direction, /* Direction control: 1 counts up; 0 counts down */
                  output reg [WIDTH-1:0] counterValue  // The current counter value (WIDTH bits wide)
                );

  // Internal wire to detect if reset is active (equals TRUE)
  wire _reset_True = (reset == `TRUE);
  
  // Internal wire to detect if enable is inactive (equals FALSE)
  wire _enable_False = (enable == `FALSE);
  
  // Internal wire to detect if the direction is set to counting up (equals TRUE)
  wire _direction_True = (direction == `TRUE);

  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––  
  // Always block: Sequential logic for updating the counter
  // This block triggers on every rising edge of the clock.
  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

  always @(posedge clock)
    // Use a conditional (ternary) operator to update counterValue:
    // 1. If reset is active (_reset_True), set counterValue to 0.
    // 2. Else if enable is FALSE (_enable_False), retain the previous counterValue.
    // 3. Else if direction is TRUE (_direction_True), increment counterValue.
    // 4. Otherwise, decrement counterValue.
    counterValue <= _reset_True         ? {WIDTH{1'b0}} :  // Reset: set all bits to 0
                    _enable_False       ? counterValue   :  // Hold value: no change when not enabled
                    _direction_True     ? counterValue + 1:  // Count up when direction is TRUE
                                          counterValue - 1;   // Count down otherwise

endmodule