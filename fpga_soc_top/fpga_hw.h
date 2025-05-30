#ifndef FPGA_HW_H
#define FPGA_HW_H

// ----------------------------------------------------
// HPS-to-FPGA Bridge Base Addresses (fixed from Cyclone V HPS TRM)
// ----------------------------------------------------
#define HPS_TO_FPGA_FULL_BASE        0xC0000000  // Full AXI bridge (h2f_axi_master)
#define HPS_TO_FPGA_LW_BASE          0xFF200000  // Lightweight AXI-Lite bridge (h2f_lw_axi_master)

// ----------------------------------------------------
// FPGA Peripheral Base Addresses (offsets added to bridges)
// ----------------------------------------------------

// 128-bit input FIFO PIO (big data) on Full AXI
#define FPGA_PIO128_IN_BASE          (HPS_TO_FPGA_FULL_BASE + 0x00000000) // pio128_in_with_fifo_0
#define FPGA_PIO128_IN_SPAN          0x20   // 32 bytes

// 128-bit output PIO (big data) on Full AXI
#define FPGA_PIO128_OUT_BASE         (HPS_TO_FPGA_FULL_BASE + 0x00000010) // pio128_out_0
#define FPGA_PIO128_OUT_SPAN         0x20   // 32 bytes

// Command Control PIO (small register) on Lightweight AXI
#define FPGA_COMMAND_PIO_BASE        (HPS_TO_FPGA_LW_BASE + 0x00000000)   // pio_commade
#define FPGA_COMMAND_PIO_SPAN        0x10   // 16 bytes

// ----------------------------------------------------
// FPGA Interrupts
// ----------------------------------------------------

// FPGA-to-HPS interrupt controller (no memory mapped base address, signal only)
#define FPGA_IRQ_CONTROLLER_IRQ      31   // irq_controller_0 connected to HPS IRQ 31

#endif /* FPGA_HW_H */
