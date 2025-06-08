import ahim_config_pkg::*;


module Result_FILO (
	input logic[PIO_DATA_WIDTH-1:0] data_in,
	input logic Clear_buff,
	input logic clk_in,
	input logic rst_n,
	input logic pop,
	input logic push,
	output logic Result_FILO_error,
	output logic[PIO_DATA_WIDTH-1:0] filo_q	
);



//signal
	logic unsigned[RESULT_RAM_WIDTH-1:0] addr_out,addr_out_plus_1,addr_in_plus_1,addr_in;
	logic full,empty,read_en,write_en;
	
//logic
	assign addr_out_plus_1 = (addr_out == $clog2(RESULT_RAM_DEPTH-1)'(RESULT_RAM_DEPTH-1)) ? 1'b0 : addr_out + 1'b1;
	assign addr_in_plus_1 = (addr_in == $clog2(RESULT_RAM_DEPTH-1)'(RESULT_RAM_DEPTH-1)) ? 1'b0 : addr_in + 1'b1;
	assign empty = (addr_out==addr_in);
	assign full = (addr_in_plus_1==addr_out);
	assign Result_FILO_error = (full&push)|(empty&pop);
	assign read_en = pop&!empty;
	assign write_en = push&!full;
	
	always_ff @(posedge clk_in or negedge rst_n) begin 
		if (!rst_n) begin 
			addr_out<='0;
			addr_in<='0;
			
		end else begin
			if(Clear_buff) begin
				addr_out<='0;
				addr_in<='0;
			end else begin
				if(read_en) addr_out<=addr_out_plus_1;
				if(write_en) addr_in<=addr_in_plus_1;
			end
		end
	
	end
	
	dp_ram_ver #(
		.DATA_WIDTH(PIO_DATA_WIDTH),
		.DEPTH(RESULT_RAM_DEPTH)
	) filo_inst (
		.aclr(~rst_n),
		.clock(clk_in),
		.data(data_in),
		.rdaddress(addr_out),
		.wraddress(addr_in),
		.wren(write_en),
		.q(filo_q)
	);	
endmodule

