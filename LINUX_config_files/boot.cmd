setenv fpgadata 0x2000000
fatload mmc 0:1 ${fpgadata} soc_system.rbf
fpga load 0 ${fpgadata} ${filesize}

fatload mmc 0:1 0x3000000 zImage
fatload mmc 0:1 0x2C00000 my_custom.dtb 

setenv bootargs console=ttyS0,115200 root=/dev/mmcblk0p2 rw rootwait

bootz 0x3000000 - 0x2C00000
