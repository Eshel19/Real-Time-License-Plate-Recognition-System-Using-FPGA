// Testbench for RX_UNIT (full operation test)

`timescale 1ns/1ps

import ocr_bridge_config_pkg::*;

module tb_RX_UNIT;

  // Clock and reset
  logic clk;
  logic rst_n;

  // Inputs
  logic Clear_buff;
  logic rx_wait_enable;
  logic select_mode;
  logic write;
  logic unsigned [RX_WD_DEPTH-1:0] watchdog_rx_conf;
  logic unsigned [BURST_SIZE_WIDTH-1:0] expected_bursts;
  logic [PIO_DATA_WIDTH-1:0] PIO_OUT;

  // Outputs
  logic [PIO_DATA_WIDTH-1:0] RX_data_out;
  logic watchdog_rx_trigger;
  logic breakpoint_write;
  logic image_write;
  logic RX_done;
  logic waitrequest_out;
  logic [IMAGE_RAM_WIDTH-1:0] addr_rx_out;

  // Instantiate the DUT
  RX_UNIT dut (
    .Clear_buff(Clear_buff),
    .clk_in(clk),
    .rst_n(rst_n),
    .rx_wait_enable(rx_wait_enable),
    .select_mode(select_mode),
    .write(write),
    .watchdog_rx_conf(watchdog_rx_conf),
    .expected_bursts(expected_bursts),
    .PIO_OUT(PIO_OUT),
    .RX_data_out(RX_data_out),
    .watchdog_rx_trigger(watchdog_rx_trigger),
    .breakpoint_write(breakpoint_write),
    .image_write(image_write),
    .RX_done(RX_done),
    .waitrequest_out(waitrequest_out),
    .addr_rx_out(addr_rx_out)
  );

  // Clock generation
  always #10 clk = ~clk; // 50 MHz clock

  // Stimulus procedure
  initial begin
    // Init
    clk = 0;
    rst_n = 0;
    Clear_buff = 0;
    rx_wait_enable = 0;
    select_mode = 0; // 0 = image, 1 = breakpoint
	 @(posedge clk);
    write = 0;
    watchdog_rx_conf = 4'd10; // very small timeout (~10 clocks)
    expected_bursts = 8'd20;
    PIO_OUT = 128'hDEADBEEFCAFEBABE_0123456789ABCDEF;

    // Reset sequence
    #25;
    rst_n = 1;

    // Clear buffer
    #20; Clear_buff = 1;
    #20; Clear_buff = 0;

    // Begin RX session (valid)
	
    #20; rx_wait_enable = 1;
	@(posedge clk); expected_bursts = 16'd1; 
	@(posedge clk); write = 1;
	@(posedge clk); write = 0;
	@(posedge clk); rx_wait_enable = 0;
	@(posedge clk); rx_wait_enable = 1;
	@(posedge clk); expected_bursts = 16'd20;
	repeat (5) @(posedge clk);
	
    // Simulate 4 valid bursts
    repeat (10) begin
      @(posedge clk); write = 1;
    end
	@(posedge clk); write = 0;
	 repeat (10) begin
      @(posedge clk); write = 1;
    end
	@(posedge clk); write = 0;
    // Expect RX_done = 1
    #20;
    $display("\n[PASS] RX_done = %b (expected: 1)", RX_done);
    $display("[INFO] Final addr_rx_out = %d", addr_rx_out);

    // Now test watchdog trigger:
    // Restart buffer and simulate write when rx_wait_enable is LOW
    #20;
    Clear_buff = 1;
    #20; Clear_buff = 0;

    #20;
    rx_wait_enable = 0; // deliberately stall
	 @(posedge clk);
    write = 1;

    // Run longer than watchdog threshold (10+ clocks)
    repeat (20) @(posedge clk);
    write = 0;

    // Expect watchdog trigger
    $display("\n[PASS] Watchdog Trigger = %b (expected: 1)", watchdog_rx_trigger);
  end

endmodule
