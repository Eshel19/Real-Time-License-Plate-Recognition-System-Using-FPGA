`timescale 1ns/1ps
import ocr_bridge_config_pkg::*;

module tb_OCR_RX_UNIT;

  // Clock & control signals
  logic clk_in = 0;
  logic rst_n = 0;
  logic final_image;
  logic Clear_buff;
  logic valid_output;

  // Inputs
  logic [MAX_OUT_L*CHAR_WIDTH-1:0] char_output;

  // Outputs
  pio_word         data_to_FILO;
  logic unsigned [UINT8_WIDTH-1:0] Result_LC;
  logic OCR_RX_done;
  logic push_filo;
	logic [MAX_OUT_L*CHAR_WIDTH-1:0] msg;

  // Instantiate DUT
  OCR_RX_UNIT dut (
    .char_output(char_output),
    .final_image(final_image),
    .clk_in(clk_in),
    .rst_n(rst_n),
    .Clear_buff(Clear_buff),
    .valid_output(valid_output),
    .data_to_FILO(data_to_FILO),
    .Result_LC(Result_LC),
    .OCR_RX_done(OCR_RX_done),
    .push_filo(push_filo)
  );

  // Clock generation
  always #5 clk_in = ~clk_in;

  // === Stimulus ===
  initial begin
    $display("== Starting OCR_RX_UNIT Testbench ==");
    rst_n = 0;
    Clear_buff = 0;
    valid_output = 0;
    final_image = 0;
    char_output = '0;
	
    repeat (5) @(posedge clk_in);
    rst_n = 1;

    // Keep final_image high for the full session
    //final_image = 1;

    // Send multiple valid digit segments to eventually fill the SIPO
	 make_char_stream_right_aligned('{8'h33, 8'h32, 8'h31}, msg); // "123"
    send_segment(msg);
	 repeat (10) @(posedge clk_in);
    make_char_stream_right_aligned('{8'h34, 8'h35}, msg);        // "45"
	 send_segment(msg);
	 repeat (10) @(posedge clk_in);
    make_char_stream_right_aligned('{8'h36, 8'h37, 8'h38}, msg); // "678"
	 send_segment(msg);
	 repeat (10) @(posedge clk_in);
    make_char_stream_right_aligned('{8'h39, 8'h30}, msg);        // "90"
	 send_segment(msg);
	 repeat (10) @(posedge clk_in);
	 make_char_stream_right_aligned('{8'h36, 8'h37, 8'h38}, msg); // "678"
	 send_segment(msg);
	 repeat (10) @(posedge clk_in);
    make_char_stream_right_aligned('{8'h39, 8'h30}, msg);        // "90"
	 send_segment(msg);
	 repeat (10) @(posedge clk_in);
	 make_char_stream_right_aligned('{8'h36, 8'h37, 8'h38}, msg); // "678"
	 send_segment(msg);
	 repeat (10) @(posedge clk_in);
    make_char_stream_right_aligned('{8'h39, 8'h30}, msg);        // "90"
	 send_segment(msg);
	 	 final_image = 1;

    // Hold for a few more cycles to see final push
	wait (OCR_RX_done);
	repeat (1) @(posedge clk_in);
	final_image = 0;
	repeat (10) @(posedge clk_in);
    $display("== Testbench Done ==");
    $stop;
  end

  // === Tasks ===

  // Send char_output with 1-cycle valid_output
  task send_segment(input logic [MAX_OUT_L*CHAR_WIDTH-1:0] packed_chars);
    begin
      @(posedge clk_in);
      char_output   = packed_chars;
      valid_output  = 1;
      @(posedge clk_in);
      valid_output  = 0;
    end
  endtask
	  
	// Task: Construct right-aligned packed character stream for char_output
	// Pads with NULL_CHAR toward MSB, aligns characters starting at LSB
	task automatic make_char_stream_right_aligned(
		 input  char_t raw_chars [],   // dynamic input character array
		 output logic [MAX_OUT_L*CHAR_WIDTH-1:0] packed_out
	);
		 packed_out = '0;
		 for (int i = 0; i < raw_chars.size(); i++) begin
			  packed_out[CHAR_WIDTH*i +: CHAR_WIDTH] = raw_chars[i];
		 end
		 // Pad the remaining MSB with NULL_CHAR
		 for (int i = raw_chars.size(); i < MAX_OUT_L; i++) begin
			  packed_out[CHAR_WIDTH*i +: CHAR_WIDTH] = NULL_CHAR;
		 end
	endtask


  // Capture when a push to FILO happens
  always_ff @(posedge clk_in) begin
    if (push_filo) begin
      $display("[@%0t] FILO pushed: %h", $time, data_to_FILO);
    end
  end

endmodule
