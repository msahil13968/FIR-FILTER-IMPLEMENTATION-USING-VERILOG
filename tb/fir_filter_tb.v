// Self-checking testbench for fir_filter
// A behavioural golden model (integer arithmetic) computes the expected
// output for every input sample; the DUT output is compared against it.
`timescale 1ns/1ps

module fir_filter_tb;

    localparam N  = 8;
    localparam DW = 8;
    localparam CW = 8;
    localparam AW = DW + CW + 3;
    localparam MAXS = 512;

    reg                   clk = 0;
    reg                   rst = 1;
    reg                   in_valid = 0;
    reg  signed [DW-1:0]  x_in = 0;
    wire signed [AW-1:0]  y_out;
    wire                  out_valid;

    fir_filter #(.N(N), .DW(DW), .CW(CW), .AW(AW)) dut (
        .clk(clk), .rst(rst), .in_valid(in_valid),
        .x_in(x_in), .y_out(y_out), .out_valid(out_valid)
    );

    always #5 clk = ~clk;       // 100 MHz

    // Golden-model coefficients (independent copy of the DUT values)
    integer h [0:N-1];
    initial begin
        h[0] = -3; h[1] = 6;  h[2] = 28; h[3] = 52;
        h[4] = 52; h[5] = 28; h[6] = 6;  h[7] = -3;
    end

    integer hist [0:N-1];       // golden delay line
    integer exp_mem [0:MAXS-1]; // expected outputs, in order
    integer n_in = 0, n_out = 0, errors = 0;
    integer k, j, acc_g;

    // Send one sample, then 'gap' idle cycles. Computes the expected output.
    task send;
        input integer s;
        input integer gap;
        begin
            x_in     = s;
            in_valid = 1'b1;

            for (k = N-1; k > 0; k = k - 1) hist[k] = hist[k-1];
            hist[0] = s;
            acc_g = 0;
            for (k = 0; k < N; k = k + 1) acc_g = acc_g + h[k] * hist[k];
            exp_mem[n_in] = acc_g;
            n_in = n_in + 1;

            @(negedge clk);
            for (j = 0; j < gap; j = j + 1) begin
                in_valid = 1'b0;
                @(negedge clk);
            end
        end
    endtask

    // Output checker
    always @(posedge clk) begin
        if (!rst && out_valid) begin
            if (y_out !== exp_mem[n_out]) begin
                errors = errors + 1;
                $display("FAIL #%0d: got %0d, expected %0d", n_out, y_out, exp_mem[n_out]);
            end else begin
                $display("PASS #%0d: y = %0d", n_out, y_out);
            end
            n_out = n_out + 1;
        end
    end

    integer t, seed;

    initial begin
        $dumpfile("fir_filter.vcd");
        $dumpvars(0, fir_filter_tb);

        for (k = 0; k < N; k = k + 1) hist[k] = 0;

        // Reset
        repeat (3) @(negedge clk);
        rst = 0;
        @(negedge clk);

        // 1) Impulse response: output must reproduce the coefficients
        $display("--- impulse response ---");
        send(100, 0);
        for (t = 0; t < N + 2; t = t + 1) send(0, 0);

        // 2) Step input
        $display("--- step input ---");
        for (t = 0; t < 16; t = t + 1) send(50, 0);
        for (t = 0; t < N; t = t + 1)  send(0, 0);

        // 3) Extreme values (full-scale positive / negative)
        $display("--- extreme values ---");
        for (t = 0; t < 12; t = t + 1) send(127, 0);
        for (t = 0; t < 12; t = t + 1) send(-128, 0);
        for (t = 0; t < 12; t = t + 1) send((t % 2) ? 127 : -128, 0);
        for (t = 0; t < N; t = t + 1)  send(0, 0);

        // 4) Random samples, back-to-back
        $display("--- random, continuous ---");
        seed = 32'hC0FFEE;
        for (t = 0; t < 100; t = t + 1)
            send(($random(seed) % 128), 0);

        // 5) Random samples with idle gaps (in_valid toggling)
        $display("--- random, with gaps ---");
        for (t = 0; t < 60; t = t + 1)
            send(($random(seed) % 128), ($random(seed) & 3));

        // Flush the pipeline
        in_valid = 1'b0;
        repeat (10) @(negedge clk);

        $display("--------------------------------------------");
        $display("Samples sent: %0d, outputs checked: %0d, errors: %0d", n_in, n_out, errors);
        if (errors == 0 && n_in == n_out) $display("ALL TESTS PASSED");
        else                              $display("SOME TESTS FAILED");
        $finish;
    end

endmodule
