// ============================================================================
// Copyright (c) 2016 by Terasic Technologies Inc.
// ============================================================================
//
// Permission:
//
//   Terasic grants permission to use and modify this code for use
//   in synthesis for all Terasic Development Boards and Altera Development 
//   Kits made by Terasic.  Other use of this code, including the selling 
//   ,duplication, or modification of any portion is strictly prohibited.
//
// Disclaimer:
//
//   This VHDL/Verilog or C/C++ source code is intended as a design reference
//   which illustrates how these types of functions can be implemented.
//   It is the user's responsibility to verify their design for
//   consistency and functionality through the use of formal
//   verification methods.  Terasic provides no warranty regarding the use 
//   or functionality of this code.
//
// ============================================================================
//           
//  Terasic Technologies Inc
//  9F., No.176, Sec.2, Gongdao 5th Rd, East Dist, Hsinchu City, 30070. Taiwan
//  
//  
//                     web: http://www.terasic.com/  
//                     email: support@terasic.com
//
// ============================================================================
//Date:  Tue Sep 27 10:46:00 2016
// ============================================================================

`define ENABLE_HPS
//`define ENABLE_HSMC

module DE10_Standard_GHRD(


      ///////// CLOCK /////////
      input              CLOCK2_50,
      input              CLOCK3_50,
      input              CLOCK4_50,
      input              CLOCK_50,

      ///////// KEY /////////
      input    [ 3: 0]   KEY,

      ///////// SW /////////
      input    [ 9: 0]   SW,

      ///////// LED /////////
      output   [ 9: 0]   LEDR,

      ///////// Seg7 /////////
      output  	[ 6: 0]   HEX0,
      output   [ 6: 0]   HEX1,
      output   [ 6: 0]   HEX2,
      output   [ 6: 0]   HEX3,
      output   [ 6: 0]   HEX4,
      output   [ 6: 0]   HEX5,

      ///////// SDRAM /////////
      output             DRAM_CLK,
      output             DRAM_CKE,
      output   [12: 0]   DRAM_ADDR,
      output   [ 1: 0]   DRAM_BA,
      inout    [15: 0]   DRAM_DQ,
      output             DRAM_LDQM,
      output             DRAM_UDQM,
      output             DRAM_CS_N,
      output             DRAM_WE_N,
      output             DRAM_CAS_N,
      output             DRAM_RAS_N,

      ///////// Video-In /////////
      input              TD_CLK27,
      input              TD_HS,
      input              TD_VS,
      input    [ 7: 0]   TD_DATA,
      output             TD_RESET_N,

      ///////// VGA /////////
      output             VGA_CLK,
      output             VGA_HS,
      output             VGA_VS,
      output   [ 7: 0]   VGA_R,
      output   [ 7: 0]   VGA_G,
      output   [ 7: 0]   VGA_B,
      output             VGA_BLANK_N,
      output             VGA_SYNC_N,

      ///////// Audio /////////
      inout              AUD_BCLK,
      output             AUD_XCK,
      inout              AUD_ADCLRCK,
      input              AUD_ADCDAT,
      inout              AUD_DACLRCK,
      output             AUD_DACDAT,

      ///////// PS2 /////////
      inout              PS2_CLK,
      inout              PS2_CLK2,
      inout              PS2_DAT,
      inout              PS2_DAT2,

      ///////// ADC /////////
      output             ADC_SCLK,
      input              ADC_DOUT,
      output             ADC_DIN,
      output             ADC_CONVST,

      ///////// I2C for Audio and Video-In /////////
      output             FPGA_I2C_SCLK,
      inout              FPGA_I2C_SDAT,

      ///////// GPIO /////////
      inout    [35: 0]   GPIO,

`ifdef ENABLE_HSMC
      ///////// HSMC /////////
      input              HSMC_CLKIN_P1,
      input              HSMC_CLKIN_N1,
      input              HSMC_CLKIN_P2,
      input              HSMC_CLKIN_N2,
      output             HSMC_CLKOUT_P1,
      output             HSMC_CLKOUT_N1,
      output             HSMC_CLKOUT_P2,
      output             HSMC_CLKOUT_N2,
      inout    [16: 0]   HSMC_TX_D_P,
      inout    [16: 0]   HSMC_TX_D_N,
      inout    [16: 0]   HSMC_RX_D_P,
      inout    [16: 0]   HSMC_RX_D_N,
      input              HSMC_CLKIN0,
      output             HSMC_CLKOUT0,
      inout    [ 3: 0]   HSMC_D,
      output             HSMC_SCL,
      inout              HSMC_SDA,
`endif /*ENABLE_HSMC*/

`ifdef ENABLE_HPS
      ///////// HPS /////////
      inout              HPS_CONV_USB_N,
      output      [14:0] HPS_DDR3_ADDR,
      output      [2:0]  HPS_DDR3_BA,
      output             HPS_DDR3_CAS_N,
      output             HPS_DDR3_CKE,
      output             HPS_DDR3_CK_N,
      output             HPS_DDR3_CK_P,
      output             HPS_DDR3_CS_N,
      output      [3:0]  HPS_DDR3_DM,
      inout       [31:0] HPS_DDR3_DQ,
      inout       [3:0]  HPS_DDR3_DQS_N,
      inout       [3:0]  HPS_DDR3_DQS_P,
      output             HPS_DDR3_ODT,
      output             HPS_DDR3_RAS_N,
      output             HPS_DDR3_RESET_N,
      input              HPS_DDR3_RZQ,
      output             HPS_DDR3_WE_N,
      output             HPS_ENET_GTX_CLK,
      inout              HPS_ENET_INT_N,
      output             HPS_ENET_MDC,
      inout              HPS_ENET_MDIO,
      input              HPS_ENET_RX_CLK,
      input       [3:0]  HPS_ENET_RX_DATA,
      input              HPS_ENET_RX_DV,
      output      [3:0]  HPS_ENET_TX_DATA,
      output             HPS_ENET_TX_EN,
      inout       [3:0]  HPS_FLASH_DATA,
      output             HPS_FLASH_DCLK,
      output             HPS_FLASH_NCSO,
      inout              HPS_GSENSOR_INT,
      inout              HPS_I2C1_SCLK,
      inout              HPS_I2C1_SDAT,
      inout              HPS_I2C2_SCLK,
      inout              HPS_I2C2_SDAT,
      inout              HPS_I2C_CONTROL,
      inout              HPS_KEY,
      inout              HPS_LCM_BK,
      inout              HPS_LCM_D_C,
      inout              HPS_LCM_RST_N,
      output             HPS_LCM_SPIM_CLK,
      output             HPS_LCM_SPIM_MOSI,
      output             HPS_LCM_SPIM_SS,
		input 				 HPS_LCM_SPIM_MISO,
      inout              HPS_LED,
      inout              HPS_LTC_GPIO,
      output             HPS_SD_CLK,
      inout              HPS_SD_CMD,
      inout       [3:0]  HPS_SD_DATA,
      output             HPS_SPIM_CLK,
      input              HPS_SPIM_MISO,
      output             HPS_SPIM_MOSI,
      inout              HPS_SPIM_SS,
      input              HPS_UART_RX,
      output             HPS_UART_TX,
      input              HPS_USB_CLKOUT,
      inout       [7:0]  HPS_USB_DATA,
      input              HPS_USB_DIR,
      input              HPS_USB_NXT,
      output             HPS_USB_STP,
`endif /*ENABLE_HPS*/
      ///////// IR /////////
      output             IRDA_TXD,
      input              IRDA_RXD
);


//=======================================================
//  REG/WIRE declarations
//=======================================================
//=======================================================
//  REG/WIRE declarations
//=======================================================

  wire  hps_fpga_reset_n;
  wire [127:0] data_from_hps;
  wire data_from_hps_block_read;
  wire data_from_hps_write_request;
  
  
  
  wire [127:0] data_to_hps;
  wire			data_to_hps_read_request;
  wire			data_to_hps_block_read;

  wire [31:0]  hps_commade;
  wire [31:0]	status_to_hps;
  
  wire [3:0] fpga_debounced_buttons;
  wire [6:0]  fpga_led_internal;
  wire [2:0]  hps_reset_req;
  wire        hps_cold_reset;
  wire        hps_warm_reset;
  wire        hps_debug_reset;
  wire [27:0] stm_hw_events;
  wire        fpga_clk_50;
  	
	
// connection of internal logics
  assign LEDR[6:1] = fpga_led_internal;
  assign stm_hw_events    = {{4{1'b0}}, SW, fpga_led_internal, fpga_debounced_buttons};
  assign fpga_clk_50=CLOCK_50;
//=======================================================
//  Structural coding
//=======================================================
soc_system u0 (      
		  .clk_clk                               (CLOCK_50),                             //                clk.clk
		  .reset_reset_n                         (hps_fpga_reset_n),                                 //                reset.reset_n
		  //HPS ddr3
		  .memory_mem_a                          ( HPS_DDR3_ADDR),                       //                memory.mem_a
        .memory_mem_ba                         ( HPS_DDR3_BA),                         //                .mem_ba
        .memory_mem_ck                         ( HPS_DDR3_CK_P),                       //                .mem_ck
        .memory_mem_ck_n                       ( HPS_DDR3_CK_N),                       //                .mem_ck_n
        .memory_mem_cke                        ( HPS_DDR3_CKE),                        //                .mem_cke
        .memory_mem_cs_n                       ( HPS_DDR3_CS_N),                       //                .mem_cs_n
        .memory_mem_ras_n                      ( HPS_DDR3_RAS_N),                      //                .mem_ras_n
        .memory_mem_cas_n                      ( HPS_DDR3_CAS_N),                      //                .mem_cas_n
        .memory_mem_we_n                       ( HPS_DDR3_WE_N),                       //                .mem_we_n
        .memory_mem_reset_n                    ( HPS_DDR3_RESET_N),                    //                .mem_reset_n
        .memory_mem_dq                         ( HPS_DDR3_DQ),                         //                .mem_dq
        .memory_mem_dqs                        ( HPS_DDR3_DQS_P),                      //                .mem_dqs
        .memory_mem_dqs_n                      ( HPS_DDR3_DQS_N),                      //                .mem_dqs_n
        .memory_mem_odt                        ( HPS_DDR3_ODT),                        //                .mem_odt
        .memory_mem_dm                         ( HPS_DDR3_DM),                         //                .mem_dm
        .memory_oct_rzqin                      ( HPS_DDR3_RZQ),                        //                .oct_rzqin
       //HPS ethernet		
	     .hps_0_hps_io_hps_io_emac1_inst_TX_CLK ( HPS_ENET_GTX_CLK),       //                             hps_0_hps_io.hps_io_emac1_inst_TX_CLK
        .hps_0_hps_io_hps_io_emac1_inst_TXD0   ( HPS_ENET_TX_DATA[0] ),   //                             .hps_io_emac1_inst_TXD0
        .hps_0_hps_io_hps_io_emac1_inst_TXD1   ( HPS_ENET_TX_DATA[1] ),   //                             .hps_io_emac1_inst_TXD1
        .hps_0_hps_io_hps_io_emac1_inst_TXD2   ( HPS_ENET_TX_DATA[2] ),   //                             .hps_io_emac1_inst_TXD2
        .hps_0_hps_io_hps_io_emac1_inst_TXD3   ( HPS_ENET_TX_DATA[3] ),   //                             .hps_io_emac1_inst_TXD3
        .hps_0_hps_io_hps_io_emac1_inst_RXD0   ( HPS_ENET_RX_DATA[0] ),   //                             .hps_io_emac1_inst_RXD0
        .hps_0_hps_io_hps_io_emac1_inst_MDIO   ( HPS_ENET_MDIO ),         //                             .hps_io_emac1_inst_MDIO
        .hps_0_hps_io_hps_io_emac1_inst_MDC    ( HPS_ENET_MDC  ),         //                             .hps_io_emac1_inst_MDC
        .hps_0_hps_io_hps_io_emac1_inst_RX_CTL ( HPS_ENET_RX_DV),         //                             .hps_io_emac1_inst_RX_CTL
        .hps_0_hps_io_hps_io_emac1_inst_TX_CTL ( HPS_ENET_TX_EN),         //                             .hps_io_emac1_inst_TX_CTL
        .hps_0_hps_io_hps_io_emac1_inst_RX_CLK ( HPS_ENET_RX_CLK),        //                             .hps_io_emac1_inst_RX_CLK
        .hps_0_hps_io_hps_io_emac1_inst_RXD1   ( HPS_ENET_RX_DATA[1] ),   //                             .hps_io_emac1_inst_RXD1
        .hps_0_hps_io_hps_io_emac1_inst_RXD2   ( HPS_ENET_RX_DATA[2] ),   //                             .hps_io_emac1_inst_RXD2
        .hps_0_hps_io_hps_io_emac1_inst_RXD3   ( HPS_ENET_RX_DATA[3] ),   //                             .hps_io_emac1_inst_RXD3
       //HPS QSPI  
		  .hps_0_hps_io_hps_io_qspi_inst_IO0     ( HPS_FLASH_DATA[0]    ),     //                               .hps_io_qspi_inst_IO0
        .hps_0_hps_io_hps_io_qspi_inst_IO1     ( HPS_FLASH_DATA[1]    ),     //                               .hps_io_qspi_inst_IO1
        .hps_0_hps_io_hps_io_qspi_inst_IO2     ( HPS_FLASH_DATA[2]    ),     //                               .hps_io_qspi_inst_IO2
        .hps_0_hps_io_hps_io_qspi_inst_IO3     ( HPS_FLASH_DATA[3]    ),     //                               .hps_io_qspi_inst_IO3
        .hps_0_hps_io_hps_io_qspi_inst_SS0     ( HPS_FLASH_NCSO    ),        //                               .hps_io_qspi_inst_SS0
        .hps_0_hps_io_hps_io_qspi_inst_CLK     ( HPS_FLASH_DCLK    ),        //                               .hps_io_qspi_inst_CLK
       //HPS SD card 
		  .hps_0_hps_io_hps_io_sdio_inst_CMD     ( HPS_SD_CMD    ),           //                               .hps_io_sdio_inst_CMD
        .hps_0_hps_io_hps_io_sdio_inst_D0      ( HPS_SD_DATA[0]     ),      //                               .hps_io_sdio_inst_D0
        .hps_0_hps_io_hps_io_sdio_inst_D1      ( HPS_SD_DATA[1]     ),      //                               .hps_io_sdio_inst_D1
        .hps_0_hps_io_hps_io_sdio_inst_CLK     ( HPS_SD_CLK   ),            //                               .hps_io_sdio_inst_CLK
        .hps_0_hps_io_hps_io_sdio_inst_D2      ( HPS_SD_DATA[2]     ),      //                               .hps_io_sdio_inst_D2
        .hps_0_hps_io_hps_io_sdio_inst_D3      ( HPS_SD_DATA[3]     ),      //                               .hps_io_sdio_inst_D3
       //HPS USB 		  
		  .hps_0_hps_io_hps_io_usb1_inst_D0      ( HPS_USB_DATA[0]    ),      //                               .hps_io_usb1_inst_D0
        .hps_0_hps_io_hps_io_usb1_inst_D1      ( HPS_USB_DATA[1]    ),      //                               .hps_io_usb1_inst_D1
        .hps_0_hps_io_hps_io_usb1_inst_D2      ( HPS_USB_DATA[2]    ),      //                               .hps_io_usb1_inst_D2
        .hps_0_hps_io_hps_io_usb1_inst_D3      ( HPS_USB_DATA[3]    ),      //                               .hps_io_usb1_inst_D3
        .hps_0_hps_io_hps_io_usb1_inst_D4      ( HPS_USB_DATA[4]    ),      //                               .hps_io_usb1_inst_D4
        .hps_0_hps_io_hps_io_usb1_inst_D5      ( HPS_USB_DATA[5]    ),      //                               .hps_io_usb1_inst_D5
        .hps_0_hps_io_hps_io_usb1_inst_D6      ( HPS_USB_DATA[6]    ),      //                               .hps_io_usb1_inst_D6
        .hps_0_hps_io_hps_io_usb1_inst_D7      ( HPS_USB_DATA[7]    ),      //                               .hps_io_usb1_inst_D7
        .hps_0_hps_io_hps_io_usb1_inst_CLK     ( HPS_USB_CLKOUT    ),       //                               .hps_io_usb1_inst_CLK
        .hps_0_hps_io_hps_io_usb1_inst_STP     ( HPS_USB_STP    ),          //                               .hps_io_usb1_inst_STP
        .hps_0_hps_io_hps_io_usb1_inst_DIR     ( HPS_USB_DIR    ),          //                               .hps_io_usb1_inst_DIR
        .hps_0_hps_io_hps_io_usb1_inst_NXT     ( HPS_USB_NXT    ),          //                               .hps_io_usb1_inst_NXT
		  
		  //HPS SPI0->LCDM 	
        .hps_0_hps_io_hps_io_spim0_inst_CLK    ( HPS_LCM_SPIM_CLK),    //                               .hps_io_spim0_inst_CLK
        .hps_0_hps_io_hps_io_spim0_inst_MOSI   ( HPS_LCM_SPIM_MOSI),   //                               .hps_io_spim0_inst_MOSI
        .hps_0_hps_io_hps_io_spim0_inst_MISO   ( HPS_LCM_SPIM_MISO),   //                               .hps_io_spim0_inst_MISO
        .hps_0_hps_io_hps_io_spim0_inst_SS0    ( HPS_LCM_SPIM_SS),    //                               .hps_io_spim0_inst_SS0
       //HPS SPI1 		  
		  .hps_0_hps_io_hps_io_spim1_inst_CLK    ( HPS_SPIM_CLK  ),           //                               .hps_io_spim1_inst_CLK
        .hps_0_hps_io_hps_io_spim1_inst_MOSI   ( HPS_SPIM_MOSI ),           //                               .hps_io_spim1_inst_MOSI
        .hps_0_hps_io_hps_io_spim1_inst_MISO   ( HPS_SPIM_MISO ),           //                               .hps_io_spim1_inst_MISO
        .hps_0_hps_io_hps_io_spim1_inst_SS0    ( HPS_SPIM_SS ),             //                               .hps_io_spim1_inst_SS0
      //HPS UART		
		  .hps_0_hps_io_hps_io_uart0_inst_RX     ( HPS_UART_RX    ),          //                               .hps_io_uart0_inst_RX
        .hps_0_hps_io_hps_io_uart0_inst_TX     ( HPS_UART_TX    ),          //                               .hps_io_uart0_inst_TX
		//HPS I2C1
		  .hps_0_hps_io_hps_io_i2c0_inst_SDA     ( HPS_I2C1_SDAT    ),        //                               .hps_io_i2c0_inst_SDA
        .hps_0_hps_io_hps_io_i2c0_inst_SCL     ( HPS_I2C1_SCLK    ),        //                               .hps_io_i2c0_inst_SCL
		//HPS I2C2
		  .hps_0_hps_io_hps_io_i2c1_inst_SDA     ( HPS_I2C2_SDAT    ),        //                               .hps_io_i2c1_inst_SDA
        .hps_0_hps_io_hps_io_i2c1_inst_SCL     ( HPS_I2C2_SCLK    ),        //                               .hps_io_i2c1_inst_SCL
      //HPS GPIO  
		  .hps_0_hps_io_hps_io_gpio_inst_GPIO09  ( HPS_CONV_USB_N),           //                               .hps_io_gpio_inst_GPIO09
        .hps_0_hps_io_hps_io_gpio_inst_GPIO35  ( HPS_ENET_INT_N),           //                               .hps_io_gpio_inst_GPIO35
        .hps_0_hps_io_hps_io_gpio_inst_GPIO37  ( HPS_LCM_BK ),  //                               .hps_io_gpio_inst_GPIO37
		  .hps_0_hps_io_hps_io_gpio_inst_GPIO40  ( HPS_LTC_GPIO ),              //                               .hps_io_gpio_inst_GPIO40
        .hps_0_hps_io_hps_io_gpio_inst_GPIO41  ( HPS_LCM_D_C ),              //                               .hps_io_gpio_inst_GPIO41
        .hps_0_hps_io_hps_io_gpio_inst_GPIO44  ( HPS_LCM_RST_N  ),  //                               .hps_io_gpio_inst_GPIO44
		  .hps_0_hps_io_hps_io_gpio_inst_GPIO48  ( HPS_I2C_CONTROL),          //                               .hps_io_gpio_inst_GPIO48
        .hps_0_hps_io_hps_io_gpio_inst_GPIO53  ( HPS_LED),                  //                               .hps_io_gpio_inst_GPIO53
        .hps_0_hps_io_hps_io_gpio_inst_GPIO54  ( HPS_KEY),                  //                               .hps_io_gpio_inst_GPIO54
    	  .hps_0_hps_io_hps_io_gpio_inst_GPIO61  ( HPS_GSENSOR_INT),  //                               .hps_io_gpio_inst_GPIO61
		  .hps_0_h2f_reset_reset_n               ( hps_fpga_reset_n ),                //                hps_0_h2f_reset.reset_n
		  
		 //HPS to FPGA data
			.data_to_hps_export(data_to_hps),
			.data_to_hps_read_request(data_to_hps_read_request),
			.data_to_hps_block_read(data_to_hps_block_read),
			
		//FPGA to HPS data
			.data_from_hps_export(data_from_hps),
			.data_from_hps_block_read_export(data_from_hps_block_read),
			.data_from_hps_data_ready_export(data_from_hps_write_request),
					
			
		//AXI Lite commade 
			.hps_commade_export(hps_commade),
			
		//PIO_STATUS
			.pio_status_export(status_to_hps),
    );


	 //signals for AHIM/OCR IO
	 
	wire image_loaded;
	wire CU_rst;
	wire [15:0] ADDR_PIXEL_START;
	wire [15:0] ADDR_PIXEL_END;
	wire [15:0] pixel_addr;
	wire ocr_done;
	wire [79:0] char_output;
	wire [7:0] output_dig_detect;
	wire [127:0] pixel_in;
	wire [7:0]debug_output_1;
	wire [7:0]debug_output_2;
	 
//Connecting HPS to AHIM - Accelerator Host Interface Manager begin
	AHIM ahim(
	.clk_in(fpga_clk_50),
	.rst_n(hps_fpga_reset_n),
	
	//OCR Accelerator IO
	.ocr_done(ocr_done),
	.char_output(char_output),
	.output_dig_detect(output_dig_detect),
	.ADDR_PIXEL_START(ADDR_PIXEL_START),
	.ADDR_PIXEL_END(ADDR_PIXEL_END),
	.CU_rst(CU_rst),
	.pixel_in(pixel_in),
	.image_loaded(image_loaded),
	.Pixel_addr(pixel_addr),	
	
	//HPS IO
	.PIO_IN(data_to_hps),
	.PIO_OUT(data_from_hps),
	.PIO_STATUS(status_to_hps),
	.PIO_CMD(hps_commade),
	.read_request(data_to_hps_read_request),
	.write_request(data_from_hps_write_request),
	.waitrequest_in(data_to_hps_block_read),
	.waitrequest_out(data_from_hps_block_read)
	
	//DEBUG output 
	//,
	//.debug_output_1(debug_output_1),
	//.debug_output_2(debug_output_2)
	
	//DEBUG output end
);
	 
	 
//Connecting HPS to AHIM - Accelerator Host Interface Manager end
	



//Connecting HPS to OCR Accelerator begin
	 OCR_Accelerator OCR_Accelerator(
		.clk_in(fpga_clk_50),
		.rst_n(hps_fpga_reset_n),
		.image_load(image_loaded),
		.CU_rst(CU_rst),
		.ADDR_PIXEL_START(ADDR_PIXEL_START),
		.ADDR_PIXEL_END(ADDR_PIXEL_END),
		.output_dig_detect(output_dig_detect),
		.output_char(char_output),
		.done(ocr_done),
		.pixel_in(pixel_in),
		.ADDR_PIXEL(pixel_addr)
	 );
	 
	 
//Connecting HPS to OCR Accelerator end
	 
	 
	 
	 // Debounce logic to clean out glitches within 1ms
debounce debounce_inst (
  .clk                                  (fpga_clk_50),
  .reset_n                              (hps_fpga_reset_n),  
  .data_in                              (KEY),
  .data_out                             (fpga_debounced_buttons)
);
  defparam debounce_inst.WIDTH = 4;
  defparam debounce_inst.POLARITY = "LOW";
  defparam debounce_inst.TIMEOUT = 50000;               // at 50Mhz this is a debounce time of 1ms
  defparam debounce_inst.TIMEOUT_WIDTH = 16;            // ceil(log2(TIMEOUT))
  
// Source/Probe megawizard instance
hps_reset hps_reset_inst (
  .source_clk (fpga_clk_50),
  .source     (hps_reset_req)
);


altera_edge_detector pulse_warm_reset (
  .clk       (fpga_clk_50),
  .rst_n     (hps_fpga_reset_n),
  .signal_in (hps_reset_req[1]),
  .pulse_out (hps_warm_reset)
);
  defparam pulse_warm_reset.PULSE_EXT = 2;
  defparam pulse_warm_reset.EDGE_TYPE = 1;
  defparam pulse_warm_reset.IGNORE_RST_WHILE_BUSY = 1;
  
altera_edge_detector pulse_debug_reset (
  .clk       (fpga_clk_50),
  .rst_n     (hps_fpga_reset_n),
  .signal_in (hps_reset_req[2]),
  .pulse_out (hps_debug_reset)
);
  defparam pulse_debug_reset.PULSE_EXT = 32;
  defparam pulse_debug_reset.EDGE_TYPE = 1;
  defparam pulse_debug_reset.IGNORE_RST_WHILE_BUSY = 1;
  
reg [25:0] counter; 
reg  led_level;
always @(posedge fpga_clk_50 or negedge hps_fpga_reset_n)
begin
if(~hps_fpga_reset_n)
begin
                counter<=0;
                led_level<=0;
end

else if(counter==24999999)
        begin
                counter<=0;
                led_level<=~led_level;
        end
else
                counter<=counter+1'b1;
end


reg [6:0] FSM_HEX;
reg [6:0] DEBUG_1_L_HEX;
reg [6:0] DEBUG_2_L_HEX;
reg [6:0] DEBUG_1_R_HEX;
reg [6:0] DEBUG_2_R_HEX;


reg wait_in;
reg wait_out;
reg error_out;

reg DEBUG_1_L_source;
reg DEBUG_2_L_source;
reg DEBUG_1_R_source;
reg DEBUG_2_R_source;

//assign DEBUG_1_L_source = debug_output_1[7:4];
//assign DEBUG_2_L_source = debug_output_2[7:4];
//assign DEBUG_1_R_source = debug_output_1[3:0];
//assign DEBUG_2_R_source = debug_output_2[3:0];


assign LEDR[0]=led_level;

assign LEDR[8]=wait_in;
assign LEDR[9]=wait_out;
assign LEDR[7]=error_out;
//assign LEDR[6]=wirte_rq;
//assign LEDR[5]=read_rq;

assign  HEX1=7'b111_1111;
assign  HEX2=7'b111_1111;
assign  HEX3=7'b111_1111;
assign  HEX4=7'b111_1111;
assign  HEX5=7'b111_1111;
assign 	HEX0=FSM_HEX;
//    wire a = status_to_hps[9];
//    wire b = status_to_hps[8];
//    wire c = status_to_hps[7];
//    wire d = status_to_hps[6];
//SET 7 Sigmant for debugging view 
always @(posedge fpga_clk_50 or negedge hps_fpga_reset_n) begin
    if (!hps_fpga_reset_n) begin
			FSM_HEX <= 7'b111_1111;  // default to blank on reset
			error_out <= 1'b0;
			wait_out  <= 1'b0;
			wait_in   <= 1'b0;
//			DEBUG_1_R_HEX <= 7'b111_1111;
//			DEBUG_2_L_HEX <= 7'b111_1111;
//			DEBUG_1_R_HEX <= 7'b111_1111;
//			DEBUG_1_L_HEX <= 7'b111_1111;
//			DEBUG_1_L_source <= 4'b0000;
//			DEBUG_2_L_source <= 4'b0000;
//			DEBUG_1_R_source <= 4'b0000;
//         DEBUG_2_R_source <= 4'b0000;
			
			
    end else begin
			error_out<=status_to_hps[4];
			wait_out<=data_from_hps_block_read;
			wait_in<=data_to_hps_block_read;
//			DEBUG_1_L_source <= debug_output_1[7:4];
//			DEBUG_2_L_source <= debug_output_2[7:4];
//			DEBUG_1_R_source <= debug_output_1[3:0];
//			DEBUG_2_R_source <= debug_output_2[3:0];
			
        case (status_to_hps[9:6])
            4'h0: FSM_HEX <= 7'b100_0000;
            4'h1: FSM_HEX <= 7'b111_1001;
            4'h2: FSM_HEX <= 7'b010_0100;
            4'h3: FSM_HEX <= 7'b011_0000;
            4'h4: FSM_HEX <= 7'b001_1001;
            4'h5: FSM_HEX <= 7'b001_0010;
            4'h6: FSM_HEX <= 7'b000_0010;
            4'h7: FSM_HEX <= 7'b111_1000;
            4'h8: FSM_HEX <= 7'b000_0000;
            4'h9: FSM_HEX <= 7'b001_0000;
            4'hA: FSM_HEX <= 7'b000_1000;
            4'hB: FSM_HEX <= 7'b000_0011;
            4'hC: FSM_HEX <= 7'b100_0110;
            4'hD: FSM_HEX <= 7'b010_0001;
            4'hE: FSM_HEX <= 7'b000_0110;
            4'hF: FSM_HEX <= 7'b000_1110;
            default: FSM_HEX <= 7'b111_1111;
        endcase
		  
//		  case (DEBUG_1_L_source)
//            4'h0: DEBUG_1_L_HEX <= 7'b100_0000;
//            4'h1: DEBUG_1_L_HEX <= 7'b111_1001;
//            4'h2: DEBUG_1_L_HEX <= 7'b010_0100;
//            4'h3: DEBUG_1_L_HEX <= 7'b011_0000;
//            4'h4: DEBUG_1_L_HEX <= 7'b001_1001;
//            4'h5: DEBUG_1_L_HEX <= 7'b001_0010;
//            4'h6: DEBUG_1_L_HEX <= 7'b000_0010;
//            4'h7: DEBUG_1_L_HEX <= 7'b111_1000;
//            4'h8: DEBUG_1_L_HEX <= 7'b000_0000;
//            4'h9: DEBUG_1_L_HEX <= 7'b001_0000;
//            4'hA: DEBUG_1_L_HEX <= 7'b000_1000;
//            4'hB: DEBUG_1_L_HEX <= 7'b000_0011;
//            4'hC: DEBUG_1_L_HEX <= 7'b100_0110;
//            4'hD: DEBUG_1_L_HEX <= 7'b010_0001;
//            4'hE: DEBUG_1_L_HEX <= 7'b000_0110;
//            4'hF: DEBUG_1_L_HEX <= 7'b000_1110;
//            default: DEBUG_1_L_HEX <= 7'b111_1111;
//        endcase
//		  
//		  case (DEBUG_1_R_source)
//            4'h0: DEBUG_1_R_HEX <= 7'b100_0000;
//            4'h1: DEBUG_1_R_HEX <= 7'b111_1001;
//            4'h2: DEBUG_1_R_HEX <= 7'b010_0100;
//            4'h3: DEBUG_1_R_HEX <= 7'b011_0000;
//            4'h4: DEBUG_1_R_HEX <= 7'b001_1001;
//            4'h5: DEBUG_1_R_HEX <= 7'b001_0010;
//            4'h6: DEBUG_1_R_HEX <= 7'b000_0010;
//            4'h7: DEBUG_1_R_HEX <= 7'b111_1000;
//            4'h8: DEBUG_1_R_HEX <= 7'b000_0000;
//            4'h9: DEBUG_1_R_HEX <= 7'b001_0000;
//            4'hA: DEBUG_1_R_HEX <= 7'b000_1000;
//            4'hB: DEBUG_1_R_HEX <= 7'b000_0011;
//            4'hC: DEBUG_1_R_HEX <= 7'b100_0110;
//            4'hD: DEBUG_1_R_HEX <= 7'b010_0001;
//            4'hE: DEBUG_1_R_HEX <= 7'b000_0110;
//            4'hF: DEBUG_1_R_HEX <= 7'b000_1110;
//            default: DEBUG_1_R_HEX <= 7'b111_1111;
//        endcase
//		  
//		  		  case (DEBUG_2_L_source)
//            4'h0: DEBUG_2_L_HEX <= 7'b100_0000;
//            4'h1: DEBUG_2_L_HEX <= 7'b111_1001;
//            4'h2: DEBUG_2_L_HEX <= 7'b010_0100;
//            4'h3: DEBUG_2_L_HEX <= 7'b011_0000;
//            4'h4: DEBUG_2_L_HEX <= 7'b001_1001;
//            4'h5: DEBUG_2_L_HEX <= 7'b001_0010;
//            4'h6: DEBUG_2_L_HEX <= 7'b000_0010;
//            4'h7: DEBUG_2_L_HEX <= 7'b111_1000;
//            4'h8: DEBUG_2_L_HEX <= 7'b000_0000;
//            4'h9: DEBUG_2_L_HEX <= 7'b001_0000;
//            4'hA: DEBUG_2_L_HEX <= 7'b000_1000;
//            4'hB: DEBUG_2_L_HEX <= 7'b000_0011;
//            4'hC: DEBUG_2_L_HEX <= 7'b100_0110;
//            4'hD: DEBUG_2_L_HEX <= 7'b010_0001;
//            4'hE: DEBUG_2_L_HEX <= 7'b000_0110;
//            4'hF: DEBUG_2_L_HEX <= 7'b000_1110;
//            default: DEBUG_2_L_HEX <= 7'b111_1111;
//        endcase
//		  
//		  case (DEBUG_2_R_source)
//            4'h0: DEBUG_2_R_HEX <= 7'b100_0000;
//            4'h1: DEBUG_2_R_HEX <= 7'b111_1001;
//            4'h2: DEBUG_2_R_HEX <= 7'b010_0100;
//            4'h3: DEBUG_2_R_HEX <= 7'b011_0000;
//            4'h4: DEBUG_2_R_HEX <= 7'b001_1001;
//            4'h5: DEBUG_2_R_HEX <= 7'b001_0010;
//            4'h6: DEBUG_2_R_HEX <= 7'b000_0010;
//            4'h7: DEBUG_2_R_HEX <= 7'b111_1000;
//            4'h8: DEBUG_2_R_HEX <= 7'b000_0000;
//            4'h9: DEBUG_2_R_HEX <= 7'b001_0000;
//            4'hA: DEBUG_2_R_HEX <= 7'b000_1000;
//            4'hB: DEBUG_2_R_HEX <= 7'b000_0011;
//            4'hC: DEBUG_2_R_HEX <= 7'b100_0110;
//            4'hD: DEBUG_2_R_HEX <= 7'b010_0001;
//            4'hE: DEBUG_2_R_HEX <= 7'b000_0110;
//            4'hF: DEBUG_2_R_HEX <= 7'b000_1110;
//            default: DEBUG_2_R_HEX <= 7'b111_1111;
//        endcase
			
		end
	end

endmodule

  