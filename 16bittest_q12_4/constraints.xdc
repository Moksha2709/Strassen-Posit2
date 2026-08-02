# ==============================================================================
# Vivado Xilinx Design Constraints (XDC)
# Target: 16-Bit Fixed-Point 7-Array Strassen Accelerator Baseline
# Frequency: 200 MHz (Period = 5.000 ns)
# ==============================================================================

# Clock Constraint (200 MHz)
create_clock -period 5.000 -name clk -waveform {0.000 2.500} [get_ports clk]

# Asynchronous Reset False Path
set_false_path -from [get_ports resetn]

# Input / Output Delay Constraints
set_input_delay -clock clk -max 1.000 [all_inputs]
set_input_delay -clock clk -min 0.200 [all_inputs]

set_output_delay -clock clk -max 1.000 [all_outputs]
set_output_delay -clock clk -min 0.200 [all_outputs]
