// 8-tap pipelined FIR filter (direct form, MAC architecture)
//
//   y[n] = sum_{i=0}^{N-1} h[i] * x[n-i]
//
// Pipeline (latency = 3 clock cycles from in_valid to out_valid):
//   Stage 1 : input shift register (delay line) captures x[n]
//   Stage 2 : N parallel multipliers  -> registered products
//   Stage 3 : accumulate (sum of products) -> registered output
//
// Signed (two's complement) input, coefficients and output.
// Output width = DW + CW + clog2(N), so the accumulator can never overflow.
`timescale 1ns/1ps

module fir_filter #(
    parameter N  = 8,                 // number of taps
    parameter DW = 8,                 // input data width
    parameter CW = 8,                 // coefficient width
    parameter AW = DW + CW + 3        // output / accumulator width (3 = clog2(8))
)(
    input  wire                  clk,
    input  wire                  rst,        // synchronous, active high
    input  wire                  in_valid,   // high when x_in carries a new sample
    input  wire signed [DW-1:0]  x_in,
    output wire signed [AW-1:0]  y_out,
    output wire                  out_valid
);

    // ------------------------------------------------------------------
    // Coefficient ROM (symmetric low-pass, linear phase).
    // Change these values to build a different filter.
    // ------------------------------------------------------------------
    function signed [CW-1:0] coeff;
        input integer idx;
        begin
            case (idx)
                0: coeff = -8'sd3;
                1: coeff =  8'sd6;
                2: coeff =  8'sd28;
                3: coeff =  8'sd52;
                4: coeff =  8'sd52;
                5: coeff =  8'sd28;
                6: coeff =  8'sd6;
                7: coeff = -8'sd3;
                default: coeff = 0;
            endcase
        end
    endfunction

    integer i;

    // Stage 1: delay line
    reg signed [DW-1:0] x_reg [0:N-1];

    // Stage 2: registered products
    reg signed [DW+CW-1:0] prod [0:N-1];

    // Stage 3: accumulated output
    reg signed [AW-1:0] acc;

    // Valid pipeline, aligned with the three data stages
    reg v1, v2, v3;

    // Stage 1 - shift register (only advances on a valid input sample)
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < N; i = i + 1)
                x_reg[i] <= 0;
        end else if (in_valid) begin
            x_reg[0] <= x_in;
            for (i = 1; i < N; i = i + 1)
                x_reg[i] <= x_reg[i-1];
        end
    end

    // Stage 2 - multiply
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < N; i = i + 1)
                prod[i] <= 0;
        end else begin
            for (i = 0; i < N; i = i + 1)
                prod[i] <= x_reg[i] * coeff(i);
        end
    end

    // Stage 3 - accumulate
    reg signed [AW-1:0] sum_comb;
    always @(*) begin
        sum_comb = 0;
        for (i = 0; i < N; i = i + 1)
            sum_comb = sum_comb + prod[i];
    end

    always @(posedge clk) begin
        if (rst) acc <= 0;
        else     acc <= sum_comb;
    end

    // Valid flag pipeline
    always @(posedge clk) begin
        if (rst) begin
            v1 <= 1'b0; v2 <= 1'b0; v3 <= 1'b0;
        end else begin
            v1 <= in_valid;
            v2 <= v1;
            v3 <= v2;
        end
    end

    assign y_out     = acc;
    assign out_valid = v3;

endmodule
