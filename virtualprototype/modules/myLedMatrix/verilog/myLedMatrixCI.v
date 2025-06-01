//============================================================
// File: myLedMatrixCI.v
//============================================================
module myLedMatrixCI #( parameter [7:0] customId    = 8'h15,   // CI opcode
                        parameter integer REFRESH_DIV = 1000)( // ≈1 kHz @ 50 MHz
                        input  wire        clock,
                        input  wire        reset,
                        input  wire        start,

                        input  wire [31:0] valueA,
                        input  wire [31:0] valueB,

                        input  wire [7:0]  ciN,
                        output wire        done,
                        output wire [31:0] result,   // not used

                        output wire [3:0]  rgbRow,   // row select (binary 0-9)
                        output wire [9:0]  red,      // column lines (active-high in _myLedPixel sense)
                        output wire [9:0]  green,
                        output wire [9:0]  blue
                    );

    //--------------------------------------------------------
    //  Frame storage (two halves of 60 bits each)
    //--------------------------------------------------------
    reg [59:0] r_matrix1;       // valueA[30]==0
    reg [59:0] r_matrix2;       // valueA[30]==1

    //--------------------------------------------------------
    //  Scan engine registers
    //--------------------------------------------------------
    reg [5:0]  r_pixelIndex;    // 0-59
    reg        r_showMatrix;    // 0→matrix1, 1→matrix2
    reg [31:0] r_refreshCnt;    // refresh-rate divider

    //--------------------------------------------------------
    //  Custom-instruction handshake
    //--------------------------------------------------------
    assign done   = (start && (ciN == customId)); // 1-cycle pulse
    assign result = 32'd0;                        // not used

    //--------------------------------------------------------
    //  Write new frame data on CI activation
    //--------------------------------------------------------

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            r_matrix1 <= 60'd0;
            r_matrix2 <= 60'd0;
        end
        else if (done) begin
            if (valueA[30] == 1'b1)
                r_matrix1 <= {valueB[29:0], valueA[29:0]};  // rows 0–5
            else
                r_matrix2 <= {valueB[29:0], valueA[29:0]};  // rows 6–11
        end
    end

    //--------------------------------------------------------
    //--------------------------------------------------------
    always @(posedge clock or posedge reset) begin
    if (reset) begin
        r_pixelIndex <= 6'd0;
        r_showMatrix <= 1'b1;      // start by showing matrix1 (rows 0–5)
        r_refreshCnt <= 32'd0;
    end else begin
        if (r_refreshCnt == REFRESH_DIV - 1) begin
            r_refreshCnt <= 32'd0;

            if (r_pixelIndex == 6'd59) begin
                r_showMatrix <= ~r_showMatrix;  // toggle which half we show
                r_pixelIndex <= 6'd0;
            end else begin
                r_pixelIndex <= r_pixelIndex + 6'd1;
            end

        end else begin
            r_refreshCnt <= r_refreshCnt + 32'd1;
        end
    end
end

    //--------------------------------------------------------

    wire [3:0] baseRow = r_pixelIndex / 10;         // 0..5
    wire [3:0] col     = r_pixelIndex % 10;         // 0..9

    // If showing second half (r_showMatrix=0 for matrix2 per your code),
    // then actualRow = baseRow + 6. Otherwise, actualRow = baseRow.
    wire [3:0] row = (r_showMatrix == 1'b1)
                    ? baseRow                 // matrix1 shows rows 0..5
                    : (baseRow + 4'd6);       // matrix2 shows rows 6..11
    //--------------------------------------------------------
    //  Decide whether LED is ON for this pixel
    //--------------------------------------------------------
    wire [59:0] activeMatrix = (r_showMatrix == 1'b1) ? r_matrix1 : r_matrix2;
    wire        pixelOn      = activeMatrix[r_pixelIndex];

    //--------------------------------------------------------
    //  Drive one pixel via sequential _myLedPixel
    //--------------------------------------------------------


    _myLedPixel pixelDrv (
        .clock (clock),
        .row   (row),// binary 0-11 (0-5 for matrix1, 6-11 for matrix2)
        .col   (col),// binary 0-9
        .enable(pixelOn),   // 1 = LED ON
        .color (2'b00),     // red only

        .rowSel(rgbRow),
        .red   (red),
        .green (green),
        .blue  (blue)
    );

    // wire [3:0] _row = 4'd11;
    // wire [3:0] _col = 4'd9;
    
    // wire _pixelOn = 1'b1; // always ON for this example

    // _myLedPixel pixelDrv (
    //     .clock (clock),
    //     .row   (_row),
    //     .col   (_col),
    //     .enable(_pixelOn),   // 1 = LED ON
    //     .color (2'b00),     // red only

    //     .rowSel(rgbRow),
    //     .red   (red),
    //     .green (green),
    //     .blue  (blue)
    // );

endmodule