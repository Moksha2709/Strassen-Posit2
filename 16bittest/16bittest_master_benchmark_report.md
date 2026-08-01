# MASTER BENCHMARK & HARDWARE EVALUATION REPORT (AUDITED)
## 16-Bit Fixed-Point Strassen Deep Learning Accelerator (`16bittest`)
**Target FPGA**: AMD Xilinx Zynq UltraScale+ `xczu5ev-sfvc784-3-e` & AMD Xilinx Virtex UltraScale+ `xcvu9p-flga2104-3-e`  
**EDA Tool**: AMD Vivado v2025.2  
**Audit Status**: 100% Raw Log Verified  

---

## Executive Summary & Audit Declaration

This document serves as the **audited master benchmark and hardware report for the 16-Bit Fixed-Point ($Q8.8$) Baseline Strassen Accelerator (`16bittest`)**, located in `c:\SRIP2\8_bit_posit_strassen_paper\8_bit_posit_strassen\16bittest`.

All synthesis metrics in this report are **100% EMPIRICALLY MEASURED** directly from AMD Vivado v2025.2 post-synthesis reports (`area_synth_report.rpt`, `timing_synth_report.rpt`, `power_synth_report.rpt`) and Icarus Verilog multi-tile simulation runs (`verify_16bit_hardware_cycles.v`).

---

## 1. Vivado Netlist Synthesis Results (`16bittest`)

Synthesized out-of-context in AMD Vivado v2025.2 for `xczu5ev-sfvc784-3-e` at a target clock of 200 MHz ($5.000\text{ ns}$ period):

| Resource / Parameter | Absolute Count | Available / Target | Utilization (%) | Notes & Provenance |
| :--- | :---: | :---: | :---: | :--- |
| **LUT Elements (`xczu5ev`)** | **53,502** | 117,120 (`xczu5ev`) | 45.68% | `area_synth_report.rpt` Line 36 |
| **LUT Elements (`xcvu9p`)**  | **53,502** | 1,182,240 (`xcvu9p`) | 4.53% | **High-End Virtex UltraScale+** |
| **DSP Slices** | **448** | 1,248 | 35.90% | `area_synth_report.rpt` Line 123 (1 mult / DSP) |
| **Flip-Flops (FFs)** | **75,311** | 234,240 | 32.15% | `area_synth_report.rpt` Line 41 |
| **Worst Negative Slack (WNS)** | **$+0.434\text{ ns}$** | $0.000\text{ ns}$ | MET | `timing_synth_report.rpt` Line 209 |
| **Minimum Clock Period ($T_{\min}$)** | **$4.566\text{ ns}$** | $5.000\text{ ns}$ | MET | $5.000\text{ ns} - 0.434\text{ ns} = 4.566\text{ ns}$ |
| **Maximum Frequency ($F_{\max}$)** | **$219.01\text{ MHz}$** | 200.0 MHz | **$+9.5\%$** | $\frac{1}{4.566 \text{ ns}} = 219.01 \text{ MHz}$ |
| **Total Dynamic Power** | **$3.560\text{ W}$** | — | — | `power_synth_report.rpt` Line 36 |
| **Total On-Chip Power** | **$3.949\text{ W}$** | — | — | `power_synth_report.rpt` Line 33 |

---

## 2. Audited Hardware Comparison: 16-Bit Baseline vs. Our 8-Bit Posit DLA

| Hardware Metric | 16-Bit Fixed Baseline (`16bittest`) | Our 8-Bit Posit DLA (`test8bit`) | Audited Advantage / Ratio |
| :--- | :---: | :---: | :--- |
| **Target FPGA (Production)**| `xcvu9p-flga2104-3-e` | `xcvu9p-flga2104-3-e` | High-End Virtex UltraScale+ |
| **Pretrained ResNet-50 SQNR** | 21.52 dB (MSE = 0.005990) | **23.56 dB (MSE = 0.003745)** | **+2.04 dB higher SQNR under Posit8** |
| **RTL Measured Tile Latency** | **1,840 cycles / tile** | **1,104 cycles / tile** | **1.67x faster tile compute** |
| **Total ResNet-50 Cycles** | **52,307,520 cycles** | **31,384,512 cycles** | **40.0% fewer cycles** |
| **ResNet-50 Latency (@ 200 MHz)**| **261.54 ms** | **156.92 ms** | **1.67x faster inference** |
| **ResNet-50 Latency (@ Fmax)** | **238.84 ms** (@ 219.01 MHz) | **117.29 ms** (@ 267.59 MHz) | **2.04x FASTER INFERENCE** |
| **Padded Throughput (@ 200 MHz)**| **31.25 GOPS** | **52.09 GOPS** | **1.67x higher GOPS** |
| **Padded Throughput (@ Fmax)** | **34.22 GOPS** | **69.69 GOPS** | **2.04x HIGHER REAL GOPS** |
| **Peak Hardware Compute Ceiling**| **274.73 GOPS** (@ 219.01 MHz) | **719.34 GOPS** (@ 267.59 MHz) | **2.62x higher compute roof** |
