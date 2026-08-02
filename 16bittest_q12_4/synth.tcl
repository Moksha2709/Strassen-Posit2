# ==============================================================================
# Vivado Batch Synthesis Script (Out-of-Context Mode)
# Baseline 16-Bit Fixed-Point 7-Array Strassen Accelerator
# Target Device: AMD Xilinx Zynq UltraScale+ XCZU5EV-SFVC784-3-E
# ==============================================================================

# 1. Set Target FPGA Part
set_part xczu5ev-sfvc784-3-e

# 2. Read Header and Verilog Source Files
read_verilog -sv strassen_pkg.vh
read_verilog fixed_pe.v
read_verilog fixed_mac_array.v
read_verilog fixed_mxu.v
read_verilog strassen_controller.v
read_verilog strassen_preprocess.v
read_verilog strassen_scratchpad.v
read_verilog strassen_top.v

# 3. Read XDC Constraints
read_xdc constraints.xdc

# 4. Run Out-of-Context (OOC) Synthesis
synth_design -top strassen_top -mode out_of_context

# 5. Write Synthesis Utilization, Timing & Power Reports
report_utilization -file area_synth_report.rpt
report_timing_summary -file timing_synth_report.rpt
report_power -file power_synth_report.rpt
