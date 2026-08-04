// =============================================================================
// posit_pkg.vh — Verilog header 
// Posit number format parameters and decoded struct field definitions
// =============================================================================
`ifndef POSIT_PKG_VH
`define POSIT_PKG_VH

// --- Posit Format Parameters ---
`define POSIT_WIDTH       8
`define POSIT_ES          1

// --- Quire Accumulator Parameters ---
`define QUIRE_WIDTH       128
`define QUIRE_RADIX_POINT 64

// --- Decoded Posit Representation ---
// Flattened width = 10 + POSIT_WIDTH = 18 bits
`define POSIT_DECODED_W   (10 + `POSIT_WIDTH)

// Field bit positions for baseline 8-bit Posit
`define PD_SIGN_BIT       (`POSIT_DECODED_W - 1)
`define PD_IS_ZERO_BIT    (`POSIT_DECODED_W - 2)
`define PD_IS_NAR_BIT     (`POSIT_DECODED_W - 3)
`define PD_SCALE_MSB      (`POSIT_DECODED_W - 4)
`define PD_SCALE_LSB      (`POSIT_WIDTH)
`define PD_FRAC_MSB       (`POSIT_WIDTH - 1)
`define PD_FRAC_LSB       0

// --- SIMD and Triple-Packed Configuration ---
// 3 active channels for 8-bit Posit (each channel element decoded is 12-bit = 36 bits)
// Readout bus: 3 channels of 16-bit formatted words = 48 bits
`define ACT_DEC_BUS_W     36
`define WEIGHT_READ_BUS_W 48
`define JOB_W             24  // Packed BRAM word width per element (3x 8-bit)

`endif // POSIT_PKG_VH
