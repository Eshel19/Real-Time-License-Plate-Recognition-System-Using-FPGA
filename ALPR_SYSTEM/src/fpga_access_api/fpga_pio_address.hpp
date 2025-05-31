//Define Addresses from Platform Designer and Altera datasheets

#ifndef FPGA_PIO_ADDRESS_HPP
#define FPGA_PIO_ADDRESS_HPP

#define BRIDGE_BASE     0xC0000000
#define BRIDGE_SPAN     0x1000

#define LW_BRIDGE_BASE  0xFF200000
#define LW_BRIDGE_SPAN  0x1000

#define PIO_IN_BASE     0x00
#define PIO_OUT_BASE    0x40
#define PIO_STATUS      0x20
#define CMD_BASE        0x00

#define TIMEOUT_CYCLES  1000000  // Retry timeout threshold

#endif
