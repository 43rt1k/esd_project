module dmaFsmNextState #( parameter [2:0]   IDLE         = 3'd0,
                                            INIT         = 3'd1,
                                            REQUEST_BUS  = 3'd2,
                                            SET_UP_TRANS = 3'd3,
                                            DO_READ      = 3'd4,
                                            WAIT_END     = 3'd5)( 
                          
                          input  wire       clock, 
                                            s_requestDmaIn,
                                            transactionGranted,
                                            busErrorIn,
                                            s_transCompleted,
                                            r_endTransIn,
                          input  wire [2:0] currentState,
                          output wire  [2:0] nextState);

  always @(posedge clock) begin
    case (currentState)

      IDLE:         if      (s_requestDmaIn)      nextState = INIT;
                    else                          nextState = IDLE;

      INIT:                                       nextState = REQUEST_BUS;

      REQUEST_BUS:  if      (transactionGranted)  nextState = SET_UP_TRANS;
                    else                          nextState = REQUEST_BUS;

      SET_UP_TRANS:                               nextState = DO_READ;

      DO_READ:      if      (busErrorIn)          nextState = WAIT_END;
                    else if (s_transCompleted)    nextState = IDLE;
                    else if (r_endTransIn)        nextState = REQUEST_BUS;
                    else                          nextState = DO_READ;

      WAIT_END:     if      (r_endTransIn)        nextState = IDLE;
                    else                          nextState = WAIT_END;

      default:                                    nextState = IDLE;

    endcase
  end

endmodule