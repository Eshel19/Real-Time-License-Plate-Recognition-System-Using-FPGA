### FPGA Register Map

All hardware register base addresses and offsets for memory-mapped PIO access are defined in [software/include/fpga_pio_address.hpp](software/include/fpga_pio_address.hpp):

```cpp
#define BRIDGE_BASE     0xC0000000
#define BRIDGE_SPAN     0x1000

#define LW_BRIDGE_BASE  0xFF200000
#define LW_BRIDGE_SPAN  0x1000

#define PIO_IN_BASE     0x00
#define PIO_OUT_BASE    0x40
#define PIO_STATUS      0x20
#define CMD_BASE        0x00

#define TIMEOUT_CYCLES  1000000
