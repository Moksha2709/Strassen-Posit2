// =============================================================================
// strassen_pkg.vh — Verilog header
// Default array dimensions and Strassen parameters
// =============================================================================
`ifndef STRASSEN_PKG_VH
`define STRASSEN_PKG_VH

// Default systolic array dimensions (parameterizable per-module)
`define DEFAULT_SZI         8
`define DEFAULT_SZJ         8

// Strassen algorithm parameters
`define MAX_RECURSION_DEPTH 1
`define TOTAL_PRODUCTS      7
`define TOTAL_SCRATCH_SLOTS 14
`define NUM_WORDS           512

`endif // STRASSEN_PKG_VH
