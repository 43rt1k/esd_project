`define TRUE 1'b1
`define FALSE 1'b0

//–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

`define COUNTER_WIDTH .WIDTH(32) 

// Define bit positions for controlling counters via valueB:
// Enable counters (EC_i) – bits 0..3
`define EC_0 0  // Counts the number of CPU-cycles when enabled.
`define EC_1 1  // Counts the µC stall cycles when enabled.
`define EC_2 2  // Counts the bus-idle cycles when enabled.
`define EC_3 3  // Counts the number of CPU-cycles when enabled.

// Disable counters (DC_i) – bits 4..7
`define DC_0 4
`define DC_1 5
`define DC_2 6
`define DC_3 7

// Reset counters (RC_i) – bits 8..11
`define RC_0 8
`define RC_1 9
`define RC_2 10
`define RC_3 11

//–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
// Module: profileCi
// This module implements a custom instruction for profiling. It continuously 
// runs four 32-bit counters and only "reacts" (i.e. outputs a counter value)
// when the custom instruction is activated (when ciN matches customId and start is high).
// The control of counters (enable/reset) is governed by bits in the 32-bit input valueB.
//–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

//–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
//–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––


module myProfileISE #(  parameter[7:0]    customId = 8'h0B )
                    (   input wire        start,    // Signal indicating a custom instruction is initiated
                                          clock,    // System clock
                                          reset,    // Global reset signal
                                          stall,    // External signal used to gate counter1 (e.g., CPU stall)
                                          busIdle,  // External signal used to gate counter2 (e.g., bus idle)
                        input wire [31:0] valueA,   // Data input: lower 2 bits select which counter value to output
                                                    // [in1] from grayscale.c   
                        input wire [31:0] valueB,   // Control signals for enabling/disabling/resetting counters
                                                    // [in2] from grayscale.c   
                        input wire [7:0]  ciN,      // Custom instruction code coming from the CPU
                        output wire       done,     // Output signal to indicate that the custom instruction is active
                        output reg [31:0] result    // Output result (selected counter value)
                                                    // [out1] from grayscale.c
  );

  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
  // Wire for the Counter Values
  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
  
  // These wires hold the outputs (counter values) from the four counters.
  wire [31:0] _counterValue_0, 
              _counterValue_1, 
              _counterValue_2, 
              _counterValue_3;

  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
  // Register Definitions for Counter Enable Signals
  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
  
  // These registers hold the enable signal for each counter.
  reg _enableCounter_0, 
      _enableCounter_1, 
      _enableCounter_2, 
      _enableCounter_3;

  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
  // Intermediate Wire Definitions
  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
  
  // This signal "done" is simply assigned to _isMyCi,
  // indicating that the custom instruction is currently active.
  assign done = _isMyCi;
  // _reset_True is asserted when the global reset is active.
  wire _reset_True = (reset == `TRUE);
  // _isMyCi_True: A wire to indicate if _isMyCi equals TRUE.
  // (We could also use _isMyCi directly in comparisons, but sometimes it's clearer to have a separate signal.)
  wire _isMyCi_True = (_isMyCi == `TRUE);
  // _isMyCi is high if the incoming custom instruction code (ciN) equals our customId,
  // and in that case, it takes the value of 'start'; otherwise it is FALSE.
  wire _isMyCi = (ciN == customId) ? start : `FALSE;
  
  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
  // Macros Definitions
  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

  // Macros for common conditions:
  // These macros help factor out common checks.
  // `COND_resetCounter(w) returns TRUE if either the global reset is active 
  // or the provided bit w equals TRUE.
  `define COND_resetCounter(w) (_reset_True || ((w) == `TRUE))

  // These macros check the enable conditions:
  // _ENABLE_COUNTER_COND_1 returns TRUE if reset is active (which disables the counter)
  // or if (when the custom instruction is active) the corresponding "disable" bit is TRUE.
  `define _ENABLE_COUNTER_COND_1(w) (_reset_True || (_isMyCi_True && ((w) == `TRUE)))
  // _ENABLE_COUNTER_COND_2 returns TRUE if, when the custom instruction is active, the corresponding "enable" bit is TRUE.
  `define _ENABLE_COUNTER_COND_2(w) (_isMyCi_True && ((w) == `TRUE))

  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
  // Reset Signals for Each Counter
  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

  // Each counter gets a reset signal that is asserted if either:
  // - Global reset is active, or
  // - The corresponding "reset" bit in valueB (RC_i) is TRUE.
  // If either is TRUE, then the reset signal is driven by _isMyCi; otherwise, it's FALSE.
  wire _resetCounter_0 = `COND_resetCounter(valueB[`RC_0]) ? _isMyCi : `FALSE;
  wire _resetCounter_1 = `COND_resetCounter(valueB[`RC_1]) ? _isMyCi : `FALSE;
  wire _resetCounter_2 = `COND_resetCounter(valueB[`RC_2]) ? _isMyCi : `FALSE;
  wire _resetCounter_3 = `COND_resetCounter(valueB[`RC_3]) ? _isMyCi : `FALSE;

  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
  // Sequential Logic: Updating the Enable Signals for Counters
  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

  // This always block updates the enable signals (_enableCounterX) on every rising clock edge.
  // For each counter:
  // - If a reset condition or a corresponding "disable" bit (from valueB[DC_i]) is TRUE,
  //   then the enable signal is set to FALSE.
  // - Otherwise, if the corresponding "enable" bit (from valueB[EC_i]) is TRUE, the enable signal is set to TRUE.
  // - If neither condition is met, the previous state is retained.
  always @(posedge clock) begin
    _enableCounter_0 <= (`_ENABLE_COUNTER_COND_1(valueB[`DC_0])) ? `FALSE :
                         (`_ENABLE_COUNTER_COND_2(valueB[`EC_0])) ? `TRUE : _enableCounter_0;
                          
    _enableCounter_1 <= (`_ENABLE_COUNTER_COND_1(valueB[`DC_1])) ? `FALSE :
                         (`_ENABLE_COUNTER_COND_2(valueB[`EC_1])) ? `TRUE : _enableCounter_1;

    _enableCounter_2 <= (`_ENABLE_COUNTER_COND_1(valueB[`DC_2])) ? `FALSE :
                         (`_ENABLE_COUNTER_COND_2(valueB[`EC_2])) ? `TRUE : _enableCounter_2;

    _enableCounter_3 <= (`_ENABLE_COUNTER_COND_1(valueB[`DC_3])) ? `FALSE :
                         (`_ENABLE_COUNTER_COND_2(valueB[`EC_3])) ? `TRUE : _enableCounter_3;
  end
  
  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
  // Counter Instantiations
  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
  // Instantiate four 32-bit counters, connecting each one to its reset, clock, enable,
  // and reading its counter value.
  // The 'direction' is hard-coded as TRUE, indicating that counters count upward.
  _myCounterCi #(`COUNTER_WIDTH) counter_0 (
           .reset(_resetCounter_0),
           .clock(clock),
           .enable(_enableCounter_0),
           .direction(`TRUE),
           .counterValue(_counterValue_0)
  );

  _myCounterCi #(`COUNTER_WIDTH) counter_1 (
           .reset(_resetCounter_1),
           .clock(clock),
           .enable(_enableCounter_1 & stall),  // Only count if 'stall' is active
           .direction(`TRUE),
           .counterValue(_counterValue_1)
  );

  _myCounterCi #(`COUNTER_WIDTH) counter_2 (
           .reset(_resetCounter_2),
           .clock(clock),
           .enable(_enableCounter_2 & busIdle), // Only count if 'busIdle' is active
           .direction(`TRUE),
           .counterValue(_counterValue_2)
  );

  _myCounterCi #(`COUNTER_WIDTH) counter_3 (
           .reset(_resetCounter_3),
           .clock(clock),
           .enable(_enableCounter_3),
           .direction(`TRUE),
           .counterValue(_counterValue_3)
  );

  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
  // Combinational Logic to Select Output Counter Value
  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
  // This always block (combinational) checks if the custom instruction is active.
  // If not, result is 0. Otherwise, it selects one of the four counter values based on
  // the lower two bits of valueA.
  always @* begin
    if (!_isMyCi_True) result = 32'd0;
    else begin
      case (valueA[1:0])
        2'd0:    result = _counterValue_0;
        2'd1:    result = _counterValue_1;
        2'd2:    result = _counterValue_2;
        2'd3:    result = _counterValue_3;
        default: result = 32'd0;
      endcase
    end
  end

endmodule