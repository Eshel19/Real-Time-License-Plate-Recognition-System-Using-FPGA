import ahim_config_pkg::*;

module AHIM (
	input logic clk_in,
	input logic rst_n,
	
	
	//OCR Accelerator IO
	input logic ocr_done,
	input logic[MAX_OUT_L*CHAR_WIDTH-1:0] char_output,
	input  logic unsigned[UINT8_WIDTH-1:0] output_dig_detect,
	output logic unsigned[UINT16_WIDTH-1:0] ADDR_PIXEL_START,
	output logic unsigned[UINT16_WIDTH-1:0] ADDR_PIXEL_END,
	output logic CU_rst,
	output logic [PIO_DATA_WIDTH-1:0] pixel_in,
	output logic image_loaded,
	input logic unsigned[UINT16_WIDTH-1:0] Pixel_addr,	
	
	//HPS IO
	output logic[PIO_DATA_WIDTH-1:0] PIO_IN,
	input logic[PIO_DATA_WIDTH-1:0] PIO_OUT,
	output logic[PIO_STATUS_WIDTH-1:0] PIO_STATUS,
	input logic[CMD_WIDTH-1:0] PIO_CMD,
	input logic read_request,
	input logic write_request,
	output logic waitrequest_in,
	output logic waitrequest_out
	//DEBUG OUTOUT
	,
	output logic[7:0] debug_output_1,
	output logic[7:0] debug_output_2
	//END DEBUG
);

//SET DEBUG_OUTPUT

//SET DEBUG_OUTPUT END 

	//signals
	logic Clear_buff;
	
	//Result_FILO IO
	logic Result_FILO_error;
	logic [PIO_DATA_WIDTH-1:0] Result_filo_out;
	
	
	// TX_IO
	logic watchdog_tx_trigger, tx_done;
	logic [TX_WD_DEPTH-1:0] watchdog_tx_conf;
	logic [RESULT_COUNT_WIDTH-1:0] headcount;
	logic tx_en;
	logic pop_result_filo;
	
	// RX_IO
	logic watchdog_rx_trigger, rx_done;
	logic [RX_WD_DEPTH-1:0] watchdog_rx_conf;
	logic [UINT16_WIDTH-1:0] expected_packages;
	logic select_mode, rx_en;
	logic [PIO_DATA_WIDTH-1:0] rx_out;
	logic breakpoint_write;
	logic image_write;
	logic [IMAGE_RAM_WIDTH-1:0] addr_rx_out;
	

	// OCR_RX_IO
	logic final_image, valid_output;
	logic [UINT8_WIDTH-1:0] Result_LC;
	logic ocr_rx_done;
	logic [PIO_DATA_WIDTH-1:0] rx_ocr_out;
	logic push_result_filo;

	// Break_point_ram IO
	logic BP_error;
	logic [UINT16_WIDTH-1:0] breakpoint;
	logic [BREAKPOINT_RAM_WIDTH-1:0] breakpoint_addr_write;
	logic [BREAKPOINT_RAM_OUTPUT_WIDTH-1:0] breakpoint_addr_read;

	// HPS_IO
	logic busy, result_ready, error_flag;
	logic [3:0] fsm_state;
	logic [UINT8_WIDTH-1:0] image_processed, images_with_digits;

	
	assign breakpoint_addr_write = (BREAKPOINT_RAM_WIDTH)'(addr_rx_out);
	assign BP_error = (((breakpoint_addr_write+1'b1)>(BREAKPOINT_RAM_WIDTH)'(BREAKPOINT_RAM_DEPTH))&&breakpoint_write)
							||((breakpoint_addr_read+1'b1)>(BREAKPOINT_RAM_OUTPUT_WIDTH)'(BREAKPOINT_RAM_DEPTH_OUTPUT));
	
	// Instantiate ahim_core_controller begin
	ahim_core_controller ahim_cc (
		.clk_in(clk_in),
		.rst_n(rst_n),
		.Clear_buff(Clear_buff),
		.watchdog_tx_trigger(watchdog_tx_trigger),
		.tx_done(tx_done),
		.watchdog_tx_conf(watchdog_tx_conf),
		.headcount(headcount),
		.tx_en(tx_en),
		.watchdog_rx_trigger(watchdog_rx_trigger),
		.rx_done(rx_done),
		.watchdog_rx_conf(watchdog_rx_conf),
		.expected_packages(expected_packages),
		.select_mode(select_mode),
		.rx_en(rx_en),
		.final_image(final_image),
		.valid_output(valid_output),
		.Result_LC(Result_LC),
		.ocr_rx_done(ocr_rx_done),
		.ADDR_PIXEL_START(ADDR_PIXEL_START),
		.ADDR_PIXEL_END(ADDR_PIXEL_END),
		.CU_rst(CU_rst),
		.image_loaded(image_loaded),
		.ocr_done(ocr_done),
		.output_dig_detect(output_dig_detect),
		.Pixel_addr(Pixel_addr),
		.BP_error(BP_error),
		.breakpoint(breakpoint),
		.breakpoint_addr_read(breakpoint_addr_read),
		.PIO_CMD(PIO_CMD),
		.busy(busy),
		.result_ready(result_ready),
		.error_flag(error_flag),
		.fsm_state(fsm_state),
		.image_processed(image_processed),
		.images_with_digits(images_with_digits)
	);
	//ahim_core_controller end
	
	
	
		assign PIO_STATUS = build_status(
		 waitrequest_out,
		 waitrequest_in,
		 busy,
		 result_ready,
		 error_flag,
		 fsm_state,
		 image_processed,
		 images_with_digits
	);
		
	/* -------------------- IO blocks -------------------- */
	
	//TX_UNIT begin
	TX_UNIT tx_unit (
		.Clear_buff(Clear_buff),
		.clk_in(clk_in),
		.rst_n(rst_n),
		.tx_en(tx_en),
		.read(read_request),
		.filo_q(Result_filo_out),
		.watchdog_tx_conf(watchdog_tx_conf),
		.headcount(headcount),
		.waitrequest_in(waitrequest_in),
		.watchdog_tx_trigger(watchdog_tx_trigger),
		.pop(pop_result_filo),
		.PIO_IN(PIO_IN),
		.tx_done(tx_done)
	);
	//TX_UNIT end
	
	//RX_UNIT begin
	RX_UNIT rx_unit (
		.Clear_buff(Clear_buff),
		.clk_in(clk_in),
		.rst_n(rst_n),
		.rx_wait_enable(rx_en),
		.select_mode(select_mode),
		.write(write_request),
		.watchdog_rx_conf(watchdog_rx_conf),
		.expected_packages(expected_packages),
		.PIO_OUT(PIO_OUT),
		.RX_data_out(rx_out),
		.watchdog_rx_trigger(watchdog_rx_trigger),
		.breakpoint_write(breakpoint_write),
		.image_write(image_write),
		.RX_done(rx_done),
		.waitrequest_out(waitrequest_out),
		.addr_rx_out(addr_rx_out)
		
		//DEBUG 
		,
		.burst_count_DEBUG(debug_output_1),
		.expected_packages_DEBUG(debug_output_2)
		//DEBUG END
	);
	//RX_UNIT end
	
	//RX_OCR begin
	OCR_RX_UNIT ocr_rx_unit (
		.char_output(char_output),
		.final_image(final_image),
		.clk_in(clk_in),
		.rst_n(rst_n),
		.Clear_buff(Clear_buff),
		.valid_output(valid_output),
		.data_to_FILO(rx_ocr_out),
		.Result_LC(Result_LC),
		.OCR_RX_done(ocr_rx_done),
		.push_filo(push_result_filo)
	);
	//RX_OCR end
	
	
	/* -------------------- RAM blocks -------------------- */
	
	//Result_FILO begin
	Result_FILO filo_inst (
		.data_in(rx_ocr_out),
		.Clear_buff(Clear_buff),
		.clk_in(clk_in),
		.rst_n(rst_n),
		.pop(pop_result_filo),
		.push(push_result_filo),
		.Result_FILO_error(Result_FILO_error),
		.filo_q(Result_filo_out)
	);
	//Result_FILO end
	
	//IMAGE_RAM begin
	dp_ram_ver #(
		.DATA_WIDTH(PIO_DATA_WIDTH),
		.DEPTH(IMAGE_RAM_DEPTH)
	) img_ram (
		.aclr(~rst_n),
		.clock(clk_in),
		.data(rx_out),
		.rdaddress(Pixel_addr),
		.wraddress(addr_rx_out),
		.wren(image_write),
		.q(pixel_in)
	);	
	//IMAGE RAM end
	
	//Break_point_RAM begin
//	BP_ram #(
//		.DATA_WIDTH_IN(PIO_DATA_WIDTH),
//		.DEPTH_IN(BREAKPOINT_RAM_DEPTH),
//		.DATA_WIDTH_OUT(UINT16_WIDTH)
//	) Breakpoint_ram(
//		.aclr(~rst_n),
//		.clock(clk_in),
//		.data(breakpoint),
//		.rdaddress(breakpoint_addr_read),
//		.wraddress(breakpoint_addr_write),
//		.wren(breakpoint_write),
//		.q(breakpoint)
//	);

	
	Breakpoint_RAM Breakpoint_ram(
		.aclr(~rst_n),
		.clock(clk_in),
		.data(rx_out),
		.rdaddress(breakpoint_addr_read),
		.wraddress(breakpoint_addr_write),
		.wren(breakpoint_write),
		.q(breakpoint)
	);
	//Break_point_RAM end
 
	 


endmodule