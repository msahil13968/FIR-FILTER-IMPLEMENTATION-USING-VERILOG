# Pipelined FIR Filter in Verilog HDL

An 8-tap Finite Impulse Response (FIR) filter written in Verilog HDL using a multiply-accumulate (MAC) architecture with a 3-stage pipeline, plus a self-checking testbench that compares the RTL against a behavioural golden model.

```
y[n] = sum_{i=0}^{7} h[i] * x[n-i]
```

## Features
- Direct-form FIR, parameterised by `N` (taps), `DW` (data width), `CW` (coefficient width)
- Signed (two's complement) input, coefficients and output
- MAC architecture: parallel multipliers followed by an accumulate stage
- 3-stage pipeline for a short critical path (shift register, multiply, accumulate)
- `in_valid` / `out_valid` handshake, so the filter works with gaps between samples
- Full-precision output (`DW + CW + clog2(N)` bits), so the accumulator cannot overflow
- Coefficients kept in one function, easy to change

## Architecture

| Stage | Operation | Registered |
|-------|-----------|------------|
| 1 | Delay line (shift register), advances only when `in_valid = 1` | `x_reg[0..N-1]` |
| 2 | `N` parallel multiplications `x_reg[i] * h[i]` | `prod[0..N-1]` |
| 3 | Sum of all products | `acc` |

Latency from `in_valid` to `out_valid` is 3 clock cycles. Throughput is one sample per clock.

## Default filter
8-tap symmetric (linear-phase) low-pass with integer coefficients:

```
h = [-3, 6, 28, 52, 52, 28, 6, -3]
```
The coefficients sum to 166, which is the DC gain. The output is not scaled back, so a constant input of 50 settles at 8300.

## Ports

| Port        | Direction | Width      | Description                        |
|-------------|-----------|------------|------------------------------------|
| `clk`       | input     | 1          | Clock                              |
| `rst`       | input     | 1          | Synchronous reset, active high     |
| `in_valid`  | input     | 1          | High when `x_in` is a new sample   |
| `x_in`      | input     | `DW` (8)   | Signed input sample                |
| `y_out`     | output    | `AW` (19)  | Signed filter output               |
| `out_valid` | output    | 1          | High when `y_out` is valid         |

## Project structure
```
verilog-fir-filter/
├── rtl/   fir_filter.v       # design
├── tb/    fir_filter_tb.v    # self-checking testbench
├── sim/   run.sh             # simulation script (Icarus Verilog)
└── docs/                     # waveform and simulation screenshots
```

## Verification
The testbench computes the expected output of every sample with an independent integer golden model and checks each DUT output when `out_valid` is high. It covers:
1. Impulse response (output reproduces the coefficients)
2. Step input
3. Full-scale values (+127, -128, and alternating)
4. 100 random samples, back-to-back
5. 60 random samples with random idle gaps on `in_valid`

239 samples are checked in total. The run ends with a summary line and `ALL TESTS PASSED` when there are no mismatches.

## How to run

**Icarus Verilog**
```bash
bash sim/run.sh
# or
iverilog -o sim/fir_sim rtl/fir_filter.v tb/fir_filter_tb.v
vvp sim/fir_sim
```
The run writes `fir_filter.vcd`, which can be opened in GTKWave.

**Xilinx Vivado**
1. Create an RTL project.
2. Add `rtl/fir_filter.v` as a design source.
3. Add `tb/fir_filter_tb.v` as a simulation source and set `fir_filter_tb` as the simulation top.
4. Run Behavioral Simulation.

Expected end of the console output:
```
Samples sent: 239, outputs checked: 239, errors: 0
ALL TESTS PASSED
```

## Changing the filter
Edit the `coeff` function in `rtl/fir_filter.v` and the `h[]` array in the testbench. Keep both in sync. For a different tap count, change `N` and update `AW` (`DW + CW + clog2(N)`).

## Tools
Verilog HDL, Icarus Verilog, Xilinx Vivado (simulation)

## Author
Muhammad Sahil, M.Tech (Signal Processing and Machine Learning), NIT Jalandhar
