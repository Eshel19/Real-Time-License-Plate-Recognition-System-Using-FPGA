module pio128_in (
	input logic clk,
	input logic reset_n,
	input logic block_read,
	input logic avs_s0_read,
	output logic waitrequest,
	output logic [127:0] avs_s0_readdata,
	output logic read_request,
	input logic [127:0] pio_in
);
	assign  read_request = avs_s0_read;
	assign  waitrequest = block_read;
	always_ff@(posedge clk or negedge reset_n) begin
		if(reset_n == 0) begin
		avs_s0_readdata<='0;
		end
		else begin avs_s0_readdata<=pio_in;
		end
	end

endmodule