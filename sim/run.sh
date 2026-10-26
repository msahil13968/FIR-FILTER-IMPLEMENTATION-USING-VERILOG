#!/bin/bash
# Run from the project root: bash sim/run.sh
iverilog -o sim/fir_sim rtl/fir_filter.v tb/fir_filter_tb.v && vvp sim/fir_sim
