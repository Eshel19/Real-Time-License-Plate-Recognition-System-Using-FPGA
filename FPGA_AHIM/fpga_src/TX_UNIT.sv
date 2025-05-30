import ahim_config_pkg::*;

module TX_UNIT (
	input logic 	Clear_buff,
	input logic		clk_in,
	input logic		rst_n,
	input logic		tx_en,
	input logic		read,
	input logic[PIO_DATA_WIDTH-1:0]		filo_q,
	input	logic unsigned[TX_WD_DEPTH-1:0] watchdog_tx_conf,
	input logic unsigned[UINT8_WIDTH-1:0] headcount,
	output logic 	tx_done,
	output logic 	waitrequest_in,
	output logic 	watchdog_tx_trigger,
	output logic	pop,
	output logic[PIO_DATA_WIDTH-1:0] PIO_IN
);

// signal declares
	logic at_head_count,first_read,read_rise,en_rise,en_reg_1,en_rise_reg,watchdog_trigger,at_burst_size,read_fall,valid_data_1,valid_data_0,valid_data_3,valid_data,valid_data_2,header_sent_reg,read_reg_1;
	logic unsigned[TX_WD_DEPTH-1:0] watchdog_counter;
	logic unsigned[UINT8_WIDTH-1:0] send_line_count,send_line_count_plus_1;
	logic valid_read;
	logic at_read_count;
	logic [2:0]read_count;
	logic count_as_read;
	

//logic 
	assign count_as_read=read&&!waitrequest_in;
	assign read_rise=(~read_reg_1&read);
	assign en_rise=(~en_reg_1&tx_en);
	assign read_fall=(~read&read_reg_1);
	assign first_read=en_rise_reg&read_rise;
	assign at_read_count=(read_count==2'd3);
	//assign valid_read=at_read_count&&read;
	assign valid_data=(valid_read&&header_sent_reg);
	assign waitrequest_in = !(watchdog_trigger|(valid_data_3&tx_en));
	assign watchdog_tx_trigger=watchdog_trigger;
	assign pop = valid_data&!at_head_count;
	assign PIO_IN[PIO_DATA_WIDTH-1:UINT8_WIDTH]=filo_q[PIO_DATA_WIDTH-1:UINT8_WIDTH];
	assign PIO_IN[UINT8_WIDTH-1:0]= (en_rise_reg&!read_fall) ? headcount : filo_q[UINT8_WIDTH-1:0];
	assign send_line_count_plus_1 = send_line_count+1;
	assign at_head_count=(headcount==send_line_count);
	assign tx_done=at_head_count&read_fall;
	
	
	always_ff @(posedge clk_in or negedge rst_n) begin
		if(!rst_n) begin
			en_reg_1<='0;
			en_rise_reg<='0;
			valid_data_0<='0;
			valid_data_1<='0;
			valid_data_2<='0;
			valid_data_3<='0;
			header_sent_reg<='0;
			read_reg_1<='0;
			watchdog_counter<='0;
			watchdog_trigger<='0;
			send_line_count<='0;
			read_count<='0;
			valid_read<='0;
		end else begin
			valid_read=at_read_count&&read;
			if(at_read_count&&read) begin
				read_count<='0;
			end else begin 
				if(count_as_read) read_count<= read_count+1'b1;
			end
			if(Clear_buff) begin
				read_count<='0;
				en_reg_1<='0;
				en_rise_reg<='0;
				valid_data_0<='0;
				valid_data_1<='0;
				valid_data_2<='0;
				valid_data_3<='0;
				header_sent_reg<='0;
				read_reg_1<='0;
				watchdog_counter<='0;
				watchdog_trigger<='0;
				send_line_count<='0;
			end else begin
				
				valid_data_0<=valid_data;
				valid_data_1<=valid_data_0;
				valid_data_2<=valid_data_1;
				if(en_rise_reg)
					valid_data_3<=1'b1;
				else begin
					if((!valid_read)&valid_data_3) valid_data_3<=1'b1;
					
					else valid_data_3<=valid_data_2;
				end
				en_reg_1<=tx_en;
				read_reg_1<=valid_read;
				
				//watchdog begin
				if((valid_data_3&tx_en)||!read) begin
					watchdog_trigger<='0;
					watchdog_counter<='0;
				end else begin
					if(watchdog_counter==watchdog_tx_conf) watchdog_trigger<=1'b1;
					else begin
						watchdog_counter<=watchdog_counter+1;
					end
				end
				//watchdog end
				
				
				
				//en_rise_reg begin
				if(read_fall) en_rise_reg<='0;
				else begin
					if(en_rise) en_rise_reg<=1'b1;
				end
				//en_rise_reg end
				
				
				//header_sent_reg begin
				if(en_rise) header_sent_reg<='0;
				else begin
					if(read_fall) header_sent_reg<=1'b1;
				end
				//header_sent_reg end
				
				
				//tx_done begin
				if(valid_read&&valid_data_3&&header_sent_reg&&!at_head_count) send_line_count<=send_line_count_plus_1;
				//tx_done end
				
			end
		end
	
	end
endmodule