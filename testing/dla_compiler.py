#!/usr/bin/env python3
# =============================================================================
# dla_compiler.py — Python
# Software compiler toolchain for the Posit Strassen DLA
# =============================================================================
import sys
import math

class DLACompiler:
    def __init__(self):
        # Register Map Offsets
        self.REG_CTRL          = "0x00"
        self.REG_INST_OP       = "0x04"
        self.REG_INST_SLOTS    = "0x08"
        self.REG_DMA_SYS_ADDR  = "0x20"
        self.REG_DMA_SRAM_ADDR = "0x24"
        self.REG_DMA_LEN       = "0x28"
        self.REG_DMA_CTRL      = "0x2C"

        # Register address mappings for hex outputs (numeric value)
        self.reg_map_hex = {
            self.REG_CTRL:          0x00,
            self.REG_INST_OP:       0x04,
            self.REG_INST_SLOTS:    0x08,
            self.REG_DMA_SYS_ADDR:  0x20,
            self.REG_DMA_SRAM_ADDR: 0x24,
            self.REG_DMA_LEN:       0x28,
            self.REG_DMA_CTRL:      0x2C
        }

    def compile_conv_layer(self, h, w, c, kh, kw, stride, padding, out_channels, use_relu=True):
        """
        Compiles a Convolution layer to DLA instructions.
        Returns a tuple of (human_readable_text, hex_machine_code).
        """
        # 1. Calculate output dimensions
        h_out = (h + 2 * padding - kh) // stride + 1
        w_out = (w + 2 * padding - kw) // stride + 1

        # 2. Calculate matrix dimensions after im2col
        act_rows = h_out * w_out
        act_cols = kh * kw * c

        weight_rows = kh * kw * c
        weight_cols = out_channels

        # 3. Calculate tiling
        tile_rows_act = math.ceil(act_rows / 16)
        tile_cols_act = math.ceil(act_cols / 16)
        tile_cols_wt  = math.ceil(weight_cols / 16)

        text_program = []
        hex_program = []

        text_program.append("# =====================================================================")
        text_program.append(f"# DLA Instruction Stream for Convolution Layer")
        text_program.append(f"# Input: {h}x{w}x{c}, Kernel: {kh}x{kw}, Stride: {stride}, Padding: {padding}")
        text_program.append(f"# Output: {h_out}x{w_out}x{out_channels}")
        text_program.append(f"# Tiling Matrix sizes: Activation ({act_rows}x{act_cols}) -> {tile_rows_act}x{tile_cols_act} tiles")
        text_program.append(f"#                      Weight ({weight_rows}x{weight_cols}) -> {tile_cols_act}x{tile_cols_wt} tiles")
        text_program.append("# =====================================================================")
        text_program.append("")

        dram_weight_base = 0
        dram_act_base    = dram_weight_base + (tile_cols_act * tile_cols_wt * 32)
        dram_out_base    = dram_act_base + (tile_rows_act * tile_cols_act * 32)

        ctrl_val = 0x00000001

        def add_write(reg, val, comment=""):
            addr = self.reg_map_hex[reg]
            hex_program.append(f"0 {addr:02X} {val:08X}")
            cmt = f"  # {comment}" if comment else ""
            text_program.append(f"WRITE {reg} {val}{cmt}")

        def add_poll(reg, val, comment=""):
            addr = self.reg_map_hex[reg]
            hex_program.append(f"1 {addr:02X} {val:08X}")
            cmt = f"   # {comment}" if comment else ""
            text_program.append(f"POLL {reg} {val}{cmt}")

        for i in range(tile_rows_act):
            for j in range(tile_cols_wt):
                text_program.append(f"# --- Computing Output Tile ({i}, {j}) ---")
                
                for k in range(tile_cols_act):
                    wt_tile_idx = k * tile_cols_wt + j
                    dram_wt_addr = dram_weight_base + wt_tile_idx * 32

                    act_tile_idx = i * tile_cols_act + k
                    dram_act_addr = dram_act_base + act_tile_idx * 32

                    text_program.append(f"# Step A: Load Weight Tile ({k}, {j}) from DRAM {dram_wt_addr} to Weight Buffer Slot 1")
                    add_write(self.REG_DMA_SYS_ADDR, dram_wt_addr, f"DRAM Weight Tile ({k}, {j})")
                    add_write(self.REG_DMA_SRAM_ADDR, 0x000000A0, "Sel=1, address=32 (Slot 1)")
                    add_write(self.REG_DMA_LEN, 32)
                    add_write(self.REG_DMA_CTRL, 0x00000001, "Start DRAM->SRAM")
                    add_poll(self.REG_DMA_CTRL, 0x00000200, "Wait for DMA Done")

                    text_program.append(f"# Step B: Load Activation Tile ({i}, {k}) from DRAM {dram_act_addr} to Activation Buffer Slot 0")
                    add_write(self.REG_DMA_SYS_ADDR, dram_act_addr, f"DRAM Activation Tile ({i}, {k})")
                    add_write(self.REG_DMA_SRAM_ADDR, 0x00000000, "Sel=0, address=0 (Slot 0)")
                    add_write(self.REG_DMA_LEN, 32)
                    add_write(self.REG_DMA_CTRL, 0x00000001, "Start DRAM->SRAM")
                    add_poll(self.REG_DMA_CTRL, 0x00000200, "Wait for DMA Done")

                    apply_relu_matmul = 1 if (use_relu and k == tile_cols_act - 1 and tile_cols_act == 1) else 0
                    
                    text_program.append(f"# Step C: Execute Tile MatMul: Slot 0 * Slot 1 -> Slot 2 (ReLU={apply_relu_matmul})")
                    add_write(self.REG_INST_OP, 0x00000001 | (apply_relu_matmul << 8))
                    add_write(self.REG_INST_SLOTS, 0x00000021, "W=1, A=0, D=2")
                    add_write(self.REG_CTRL, ctrl_val, "Start DLA")
                    add_poll(self.REG_CTRL, 0x00000200, "Wait for DLA Done")

                    if k == 0:
                        if tile_cols_act > 1:
                            text_program.append(f"# Step D: Initialize accumulator by copying Slot 2 -> Slot 3 (vadd_init=1)")
                            add_write(self.REG_INST_OP, 0x00000202)  # OP_VADD=0x02 | bit9=vadd_init
                            add_write(self.REG_INST_SLOTS, 0x0000003E, "Src2=2, Src1=3, D=3")
                            add_write(self.REG_CTRL, ctrl_val, "Start VADD (init)")
                            add_poll(self.REG_CTRL, 0x00000200, "Wait for Done")
                    else:
                        apply_relu_vadd = 1 if (use_relu and k == tile_cols_act - 1) else 0
                        text_program.append(f"# Step D: Accumulate Slot 2 + Slot 3 -> Slot 3 (ReLU={apply_relu_vadd})")
                        add_write(self.REG_INST_OP, 0x00000002 | (apply_relu_vadd << 8))
                        add_write(self.REG_INST_SLOTS, 0x0000003E, "Src2=2 (weights slot), Src1=3, D=3")
                        add_write(self.REG_CTRL, ctrl_val, "Start VADD")
                        add_poll(self.REG_CTRL, 0x00000200, "Wait for Done")
                    if tile_cols_act > 1:
                        text_program.append("")

                out_tile_idx = i * tile_cols_wt + j
                dram_out_addr = dram_out_base + out_tile_idx * 32
                sram_src_addr = 0x00000040 if tile_cols_act == 1 else 0x00000060
                slot_num = 2 if tile_cols_act == 1 else 3
                text_program.append(f"# Step E: DMA write output Slot {slot_num} back to DRAM {dram_out_addr}")
                add_write(self.REG_DMA_SYS_ADDR, dram_out_addr, "DRAM Out Address")
                add_write(self.REG_DMA_SRAM_ADDR, sram_src_addr, f"Sel=0, address={sram_src_addr} (Slot {slot_num})")
                add_write(self.REG_DMA_LEN, 32)
                add_write(self.REG_DMA_CTRL, 0x00000003, "Start SRAM->DRAM (Dir=1)")
                add_poll(self.REG_DMA_CTRL, 0x00000200, "Wait for DMA Done")
                text_program.append("")

        return "\n".join(text_program), "\n".join(hex_program)

if __name__ == "__main__":
    compiler = DLACompiler()
    # Sample Convolution layer:
    # Input Image: 4x4 with 1 channel
    # Filter: 3x3, stride=1, padding=1, 4 output channels
    program_text, program_hex = compiler.compile_conv_layer(
        h=4, w=4, c=1,
        kh=3, kw=3,
        stride=1, padding=1,
        out_channels=4,
        use_relu=True
    )

    with open("dla_program.txt", "w") as f:
        f.write(program_text)

    with open("dla_program.hex", "w") as f:
        f.write(program_hex)

    print("[SUCCESS] Compiled Convolution layer to 'dla_program.txt' and 'dla_program.hex'!")
