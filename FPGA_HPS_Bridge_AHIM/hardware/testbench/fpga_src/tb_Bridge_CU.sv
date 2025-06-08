`timescale 1ns/1ps
module tb_Bridge_CU;
    import ocr_bridge_config_pkg::*;
	 import tb_bridge_cmd_pkg::*;


    // Clock and reset
    logic clk_in = 0;
    logic rst_n = 0;

    // All DUT ports as signals
    logic Clear_buff;

    // TX_IO
    logic watchdog_tx_trigger, tx_done;
    logic [TX_WD_DEPTH-1:0] watchdog_tx_conf;
    logic [RESULT_COUNT_WIDTH-1:0] headcount;
    logic tx_en;

    // RX_IO
    logic watchdog_rx_trigger, rx_done;
    logic [RX_WD_DEPTH-1:0] watchdog_rx_conf;
    logic [UINT16_WIDTH-1:0] expected_packages;
    logic select_mode, rx_en;

    // OCR_RX_IO
    logic final_image, valid_output;
    logic [UINT8_WIDTH-1:0] Result_LC;
    logic ocr_rx_done;

    // OCR_IO
    logic [UINT16_WIDTH-1:0] ADDR_PIXEL_START, ADDR_PIXEL_END;
    logic CU_rst, image_loaded, ocr_done;
    logic [UINT8_WIDTH-1:0] output_dig_detect;
	

    // Break_point_ram IO
	logic BP_error;
    logic [UINT16_WIDTH-1:0] breakpoint;
    logic [BREAKPOINT_RAM_WIDTH-1:0] breakpoint_addr_read;
	logic unsigned[UINT16_WIDTH-1:0] Pixel_addr;

    // HPS_IO
    logic [CMD_WIDTH-1:0] PIO_CMD;
    logic busy, result_ready, error_flag;
    logic [3:0] fsm_state;
    logic [UINT8_WIDTH-1:0] image_processed, images_with_digits;

    // Instantiate DUT
    Bridge_CU dut (
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

    // Clock generation (50 MHz)
    always #10 clk_in = ~clk_in;

	 
	 // Example maximums (or use dynamic array if you want):
parameter int MAX_IMAGES = 32;

// Test arrays (must be defined somewhere in your TB)
logic [15:0] breakpoints[MAX_IMAGES];
logic [7:0] digit_counts[MAX_IMAGES];
int num_images;

// TB signals (matching DUT)
logic [3:0] min_digits;
logic [3:0] max_digits;
logic [7:0] watchdog_pio;
logic [7:0] watchdog_ocr;
logic ocr_break;
logic ignore_invalid_cmd;

always_comb begin
    if (breakpoint_addr_read < num_images)
        breakpoint = breakpoints[breakpoint_addr_read];
    else
        breakpoint = 0;
end


	initial begin
		// Optional: reset and/or INIT
		BP_error		= 0;
		Pixel_addr		= '0;
		rx_done         = 0;
		tx_done         = 0;
		ocr_done        = 0;
		ocr_rx_done     = 0;
		output_dig_detect = 0;
		Result_LC       = 0;
		//breakpoint      = 0;
		PIO_CMD = 0;
		rst_n = 0;
		#30;
		rst_n = 1;
		repeat(3)@(posedge clk_in);

		// Optional: Send INIT once, outside the emulation task
		min_digits=4'd5;
		max_digits=4'd8;
		watchdog_pio=8'd100;
		watchdog_ocr=8'd150;
		ocr_break='0;
		ignore_invalid_cmd='0;
		
		/*--------------FIRST START UP AND RESET TESTING CODE---------------------*/
		$display("TB: Start Test first startup and reset time=%0t\n",$time);
		send_init_cmd(PIO_CMD, min_digits, max_digits, watchdog_pio, watchdog_ocr, ocr_break, ignore_invalid_cmd);
		wait_state_or_cycles(
			.target_state(IDLE),
			.num_cycles(5),     
			.test_error_flag(0),
			.cirical_error_timeout(1),
			.msg_on_state("Sysem Successfully enter IDLE state"),   
			.msg_on_timeout("Critical ERROR! system fail to enter IDLE after init cmd!")  
		);

		send_rst_cmd(PIO_CMD);
		wait_state_or_cycles(
			.target_state(OFFLINE),
			.num_cycles(5),     
			.test_error_flag(0),
			.cirical_error_timeout(1),
			.msg_on_state("Successfully reset itself"),   
			.msg_on_timeout("Critical error: Reset fail!!!")  
		);
		
		
		/*--------------COMMUNICATION ERROR TESTING CODE---------------------*/
		$display("\n\nTB: Start Test com error time=%0t\n",$time);
		send_init_cmd(PIO_CMD, min_digits, max_digits, watchdog_pio, watchdog_ocr, ocr_break, ignore_invalid_cmd);
		wait(fsm_state==IDLE);
		send_upload_cmd(PIO_CMD, 8'd8, 16'd5);
		wait_state_or_cycles(
			.target_state(ERROR_COM),
			.num_cycles(5),     
			.test_error_flag(1),
			.cirical_error_timeout(0),
			.msg_on_state("System Successfully enter ERROR_COM due to invalid strip size"),   
			.msg_on_timeout("Protection fail!!! to enter ERROR_COM due to invalid strip size")  
		);
		send_rst_cmd(PIO_CMD);
		wait(fsm_state==OFFLINE);
		send_init_cmd(PIO_CMD, min_digits, max_digits, watchdog_pio, watchdog_ocr, ocr_break, ignore_invalid_cmd);
		wait(fsm_state==IDLE);
		send_upload_cmd(PIO_CMD, 8'd0, 16'd20);
		wait_state_or_cycles(
			.target_state(ERROR_COM),
			.num_cycles(5),     
			.test_error_flag(1),
			.cirical_error_timeout(0),
			.msg_on_state("System Successfully enter ERROR_COM due to invalid breakpoint size"),   
			.msg_on_timeout("Protection fail!!! to enter ERROR_COM due to invalid breakpoint size")  
		);	
		send_rst_cmd(PIO_CMD);
		wait(fsm_state==OFFLINE);
		send_upload_cmd(PIO_CMD, 16'd6, 8'd3);
		
		wait_state_or_cycles(
			.target_state(ERROR_COM),
			.num_cycles(5),     
			.test_error_flag(1),
			.cirical_error_timeout(0),
			.msg_on_state("System Successfully enter ERROR_COM due to unmatch commade"),   
			.msg_on_timeout("Protection fail!!! to enter ERROR_COM due to unmatch commade")  
		);	
		send_rst_cmd(PIO_CMD);
		wait(fsm_state==OFFLINE);
		send_init_cmd(PIO_CMD, min_digits, max_digits, watchdog_pio, watchdog_ocr, ocr_break, 1'b1);
		wait(fsm_state==IDLE);
		send_ack_cmd(PIO_CMD);
		wait_state_or_cycles(
			.target_state(ERROR_COM),
			.num_cycles(5),     
			.test_error_flag(1),
			.cirical_error_timeout(0),
			.msg_on_state("Test fail ignore_invalid_cmd fail to skip ignore invalid commade"),   
			.msg_on_timeout("ignore_invalid_cmd successfully ignore invalid commade")  
		);
		
		/*--------------OVERFLOW PROTECTION TESTING CODE---------------------*/
		$display("\n\nTB: Start Test overflow protection errors time=%0t\n",$time);
		send_rst_cmd(PIO_CMD);
		repeat(5) @(posedge clk_in);
		send_init_cmd(PIO_CMD, min_digits, max_digits, watchdog_pio, 8'd0, '1, ignore_invalid_cmd);
		wait(fsm_state==IDLE);
		send_upload_cmd(PIO_CMD, ((16)'(IMAGE_RAM_DEPTH)+16'd20), 8'd10);
		wait_state_or_cycles(
			.target_state(ERROR_OVERFLOW),
			.num_cycles(5),     
			.test_error_flag(1),
			.cirical_error_timeout(0),
			.msg_on_state("System Successfully enter ERROR_OVERFLOW due to stip size to long"),   
			.msg_on_timeout("Protection fail!!! to enter ERROR_OVERFLOW stip size to long")  
		);
		send_rst_cmd(PIO_CMD);
		repeat(5) @(posedge clk_in);
		send_init_cmd(PIO_CMD, min_digits, max_digits, watchdog_pio, 8'd0, '1, ignore_invalid_cmd);
		wait(fsm_state==IDLE);
		send_upload_cmd(PIO_CMD, 16'd20, 8'd10);
		repeat(5) @(posedge clk_in);
		Pixel_addr=(UINT16_WIDTH)'(IMAGE_RAM_DEPTH);
		wait_state_or_cycles(
			.target_state(ERROR_OVERFLOW),
			.num_cycles(5),     
			.test_error_flag(1),
			.cirical_error_timeout(0),
			.msg_on_state("System Successfully enter ERROR_OVERFLOW due to OCR read address overflow"),   
			.msg_on_timeout("Protection fail!!! to enter ERROR_OVERFLOW due to OCR read address overflow")  
		);
		
		Pixel_addr=16'd60;
		send_rst_cmd(PIO_CMD);
		repeat(5) @(posedge clk_in);
		send_init_cmd(PIO_CMD, min_digits, max_digits, watchdog_pio, 8'd0, '1, ignore_invalid_cmd);
		wait(fsm_state==IDLE);
		send_upload_cmd(PIO_CMD, 16'd20, 8'd10);
		repeat(5) @(posedge clk_in);
		BP_error=1'b1;
		wait_state_or_cycles(
			.target_state(ERROR_OVERFLOW),
			.num_cycles(5),     
			.test_error_flag(1),
			.cirical_error_timeout(0),
			.msg_on_state("System Successfully enter ERROR_OVERFLOW due to Breakpoint ram error"),   
			.msg_on_timeout("Protection fail!!! to enter ERROR_OVERFLOW due to BP_error")  
		);
		BP_error=1'b0;

		/*--------------WATCHDOG TESTING CODE---------------------*/
		$display("\n\nTB: Start Test watchdogs triggers errors time=%0t\n",$time);
		send_rst_cmd(PIO_CMD);
		wait(fsm_state==OFFLINE);
		repeat(5) @(posedge clk_in);
		send_init_cmd(PIO_CMD, min_digits, max_digits, watchdog_pio, watchdog_ocr, ocr_break, ignore_invalid_cmd);
		repeat(5) @(posedge clk_in);
		
		watchdog_rx_trigger=1'b1;
		wait_state_or_cycles(
			.target_state(ERROR_RX),
			.num_cycles(5),     
			.test_error_flag(1),
			.cirical_error_timeout(0),
			.msg_on_state("System Successfully enter ERROR_RX due to watchdog_rx_trigger"),   
			.msg_on_timeout("Protection fail!!! to enter ERROR_RX due to watchdog_rx_trigger")  
		);	
		watchdog_rx_trigger=1'b0;
		send_rst_cmd(PIO_CMD);
		repeat(5) @(posedge clk_in);
		send_init_cmd(PIO_CMD, min_digits, max_digits, watchdog_pio, watchdog_ocr, ocr_break, ignore_invalid_cmd);
		wait(fsm_state==IDLE);
		watchdog_tx_trigger=1'b1;
		wait_state_or_cycles(
			.target_state(ERROR_TX),
			.num_cycles(5),     
			.test_error_flag(1),
			.cirical_error_timeout(0),
			.msg_on_state("System Successfully enter ERROR_TX due to watchdog_tx_trigger"),   
			.msg_on_timeout("Protection fail!!! to enter ERROR_RX due to watchdog_tx_trigger")  
		);
		watchdog_tx_trigger=1'b0;
		

		
		$display("\n\nTB: Start OCR Watchdog test time=%0t\n",$time);
		send_rst_cmd(PIO_CMD);
		repeat(5) @(posedge clk_in);
		send_init_cmd(PIO_CMD, min_digits, max_digits, watchdog_pio, 8'd0, '1, ignore_invalid_cmd);
		wait(fsm_state==IDLE);
		breakpoints[0] = 16'd31;
		breakpoints[1] = 16'd74;
		breakpoints[2] = 16'd125;
		digit_counts[0]=8'd8;
		digit_counts[1]=8'd5;
		digit_counts[2]=8'd6;
		num_images = 3;
		emulate_full_ocr_scenario(
			.test_OCR_WD(1),
			.breakpoints(breakpoints),
			.digit_counts(digit_counts),
			.num_images(num_images),
			.strip_width(16'd30),// strip_width
			.breakpoint_count(8'd3)//breakpoint_count
			);

		
		
		
//		wait_state_or_cycles(
//			.target_state(),
//			.num_cycles(),     
//			.test_error_flag(),
//			.cirical_error_timeout(),
//			.msg_on_state(),   
//			.msg_on_timeout()  
//		);
//		
		/*--------------TEST FULL OPEREATION---------------------*/
		$display("\n\nTB: Start Test full cycle operation time=%0t\n",$time);

		send_rst_cmd(PIO_CMD);
		repeat(5) @(posedge clk_in);
		send_init_cmd(PIO_CMD, min_digits, max_digits, watchdog_pio, 8'd0, '1, ignore_invalid_cmd);
		wait(fsm_state==IDLE);
		breakpoints[0] = 16'd31;
		breakpoints[1] = 16'd74;
		breakpoints[2] = 16'd125;
		digit_counts[0]=8'd8;
		digit_counts[1]=8'd5;
		digit_counts[2]=8'd6;
		num_images = 3;
		@(posedge clk_in);
		// Now run the main scenario (UPLOAD, image process, etc.)
		emulate_full_ocr_scenario(
			.test_OCR_WD(0),
			.breakpoints(breakpoints),
			.digit_counts(digit_counts),
			.num_images(num_images),
			.strip_width(16'd30),// strip_width
			.breakpoint_count(8'd3)//breakpoint_count
			);

		$display("TB: Task completed!");
	end
		// Main image processing task
	task automatic emulate_full_ocr_scenario(
		 input logic test_OCR_WD,
		 input logic [15:0] breakpoints[],
		 input logic [7:0] digit_counts[],
		 input int num_images,
		 input [15:0] strip_width,
		 input [7:0] breakpoint_count
	);
		 int img_idx;
		 int prev_bp, curr_bp, delay;

		 // --- INIT PHASE ---
		 #0;
		 @(posedge clk_in);
		 PIO_CMD = 0;
		 wait (fsm_state == IDLE);
		 $display("TB: System entered IDLE state (ready for upload) at time=%0t", $time);

		 // --- UPLOAD PHASE ---
		 send_upload_cmd(PIO_CMD, strip_width, breakpoint_count);
		 @(posedge clk_in);
		 PIO_CMD = 0;
		 $display("TB: Sent UPLOAD command (strip_width=%0d, breakpoint_count=%0d)", strip_width, breakpoint_count);

		 // --- RX breakpoints phase ---
		 wait(rx_en && select_mode == 1'b0);
		 repeat(expected_packages) @(posedge clk_in);
		 rx_done = 1;
		 @(posedge clk_in);
		 rx_done = 0;
		 $display("TB: Breakpoint RX handshake completed (select_mode=0) at time=%0t", $time);

		 repeat(3) @(posedge clk_in);

		 // --- RX strip phase ---
		 wait(rx_en && select_mode == 1'b1);
		 repeat(expected_packages) @(posedge clk_in);
		 rx_done = 1;
		 @(posedge clk_in);
		 rx_done = 0;
		 $display("TB: Strip RX handshake completed (select_mode=1) at time=%0t", $time);

		 img_idx = 0;
		 prev_bp = 0;

		 if(test_OCR_WD) begin 
			  wait(image_loaded);
			  $display("TB: IMAGE LOADED (testing OCR watchdog trigger)");
			  wait_state_or_cycles(
				   .target_state(ERROR_OCR),
				   .num_cycles({8'd10, {OCR_WD_SHIFT{1'b1}}}),     
				   .test_error_flag(1),
				   .cirical_error_timeout(0),
				   .msg_on_state("System Successfully entered ERROR_OCR due to watchdog_OCR_trigger"),   
				   .msg_on_timeout("Protection FAIL! Did not enter ERROR_OCR on watchdog trigger")  
			  );
		 end else begin
			  while (img_idx < num_images) begin
				   wait(image_loaded);
				   $display("TB: IMAGE LOADED (index=%0d, breakpoints=%0d-%0d, digit_count=%0d, time=%0t)",
					   img_idx, 
					   (img_idx==0 ? 0 : breakpoints[img_idx-1]), 
					   breakpoints[img_idx], 
					   digit_counts[img_idx], $time
				   );
				   curr_bp = breakpoints[img_idx];
				   delay = (ADDR_PIXEL_END - ADDR_PIXEL_START) / 2;
				   if (delay < 1) delay = 1;
				   output_dig_detect = digit_counts[img_idx];
				   repeat(delay) @(posedge clk_in);
				   ocr_done = 1;
				   @(posedge clk_in);
				   ocr_done = 0;
				   prev_bp = curr_bp;
				   img_idx++;
			  end

			  // --- POST-IMAGE/FINAL PHASE ---
			  wait(fsm_state == WAIT_POST_RX);
			  $display("TB: All images processed, waiting for OCR RX done at time=%0t", $time);
			  repeat(2) @(posedge clk_in);
			  ocr_rx_done = 1;
			  @(posedge clk_in);
			  ocr_rx_done = 0;

			  // --- TX phase ---
			  wait(tx_en);
			  $display("TB: TX enabled (results ready to send to CPU) at time=%0t", $time);
			  repeat(2) @(posedge clk_in);
			  tx_done = 1;
			  @(posedge clk_in);
			  tx_done = 0;

			  // --- ACK phase ---
			  wait (fsm_state == WAIT_ACK);
			  $display("TB: FSM entered WAIT_ACK, sending ACK command at time=%0t", $time);
			  send_ack_cmd(PIO_CMD);
			  @(posedge clk_in);
			  PIO_CMD = 0;

			  // --- Final confirmation ---
			  wait (fsm_state == IDLE);
			  $display("TB: Scenario completed successfully, returned to IDLE at time=%0t", $time);
		 end
	endtask


	
	task automatic wait_state_or_cycles(
		input cu_fsm_state_e target_state,   // State to wait for (e.g. ERROR_COM, or any)
		input int         num_cycles,     // Max number of cycles to wait
		input logic			test_error_flag,
		input logic 		cirical_error_timeout,
		input string      msg_on_state,   // Message if state is reached
		input string      msg_on_timeout  // Message if cycles expire
	);
		
		int i;
		@(posedge clk_in);
		for (i = 0; i < num_cycles; i++) begin
			@(posedge clk_in);
			if(test_error_flag) begin
				if (fsm_state == target_state&&error_flag==1'b1) begin
					$display("TB: %s (at cycle %0d, time=%0t)", msg_on_state, i, $time);
				return;
				end
			end else begin
				if (fsm_state == target_state&&error_flag==1'b0) begin
					$display("TB: %s (at cycle %0d, time=%0t)", msg_on_state, i, $time);
				return;
				end
			end
		end
		// If we get here, the cycles expired
		if(cirical_error_timeout) $fatal(1,"TB: %s (after %0d cycles, time=%0t)", msg_on_timeout, num_cycles, $time);
		else $display("TB: %s (after %0d cycles, time=%0t)", msg_on_timeout, num_cycles, $time);
	endtask
    // Insert command tasks and stimulus code here

endmodule
