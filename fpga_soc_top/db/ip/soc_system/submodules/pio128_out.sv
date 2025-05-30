module pio128_out (
	input logic clk,
	input logic reset_n,

	input logic avs_s0_write,
	input logic [127:0] avs_s0_writedata,
	input logic block_read,
	output logic avs_s0_waitrequest,
	output logic [127:0] pio_out,
	output logic data_ready
);

reg reg_data_ready;
reg [ 127: 0]data_out;
always_ff @ (posedge clk or negedge reset_n) begin
  if (reset_n == 0) begin
		data_out <= '0;
		reg_data_ready <=0;
	end else begin 
		reg_data_ready<=avs_s0_write;
		if(avs_s0_write)
			data_out<=avs_s0_writedata;
	end
end
	assign data_ready=reg_data_ready;
	assign pio_out=data_out;
	assign avs_s0_waitrequest=block_read;
endmodule