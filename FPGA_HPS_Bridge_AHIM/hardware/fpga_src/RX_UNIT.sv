import ahim_config_pkg::*;


module RX_UNIT (
	input logic Clear_buff,
	input logic clk_in,
	input logic rst_n,
	input logic rx_wait_enable,
	input logic select_mode,
	input logic write,
	input logic unsigned [RX_WD_DEPTH-1:0] watchdog_rx_conf, 
	input logic unsigned [UINT16_WIDTH-1:0] expected_packages,
	input logic [PIO_DATA_WIDTH-1:0] PIO_OUT, 
	output logic [PIO_DATA_WIDTH-1:0] RX_data_out,
	output logic watchdog_rx_trigger,
	output logic breakpoint_write,
	output logic image_write,
	output logic RX_done,
	output logic waitrequest_out,
	
	output logic [IMAGE_RAM_WIDTH-1:0] addr_rx_out
	//DEBUG TESTING PORT
	,
	output logic [7:0] burst_count_DEBUG,
	output logic [7:0] expected_packages_DEBUG
);

// signal declares
	logic first_rx_en,write_fall,rx_en_reg_1,write_reg_1,valid_write,at_burst_count,watchdog_trigger;
	logic unsigned [RX_WD_DEPTH-1:0] watchdog_counter;
	logic unsigned [IMAGE_RAM_WIDTH-1:0] addr_reg;
	logic unsigned [IMAGE_RAM_WIDTH-1:0] addr_reg_plus_1;
	logic unsigned [UINT16_WIDTH-1:0] burst_count;
	logic unsigned [UINT16_WIDTH-1:0] burst_count_plus_1;
	logic [2:0]write_count;
	logic [2:0]write_count_plus_1;
	logic at_write_count;
	
	//DEBUG_LOGIC output
	assign burst_count_DEBUG = burst_count[7:0];
	assign expected_packages_DEBUG = expected_packages[7:0];
	//DEBUG_LOGIC end
	
//logic 
	assign write_count_plus_1 = write_count+1'b1;
	assign at_write_count= (write_count==3'd3);
	
	
	assign image_write = (select_mode) ? valid_write : 1'b0;
	assign breakpoint_write = (select_mode) ? 1'b0 : valid_write;
	//assign valid_write = at_write_count&&write;//(rx_wait_enable && write);
//	assign first_rx_en = (rx_wait_enable &&	!rx_en_reg_1);
//	assign write_fall = (write_reg_1 && !write);
	assign at_burst_count= (expected_packages==burst_count);
	assign burst_count_plus_1 = burst_count +1'b1;
	assign addr_reg_plus_1 = addr_reg + 1'b1;
	assign RX_done = at_burst_count && write_fall;
	assign RX_data_out =PIO_OUT;
	//assign waitrequest_out = !(rx_wait_enable || watchdog_trigger);
	assign addr_rx_out = addr_reg;
	assign watchdog_rx_trigger= watchdog_trigger;
	
	
	
	always_ff @(posedge clk_in or negedge rst_n) begin
		if(!rst_n) begin
			addr_reg<='0;
			burst_count<='0;
			watchdog_counter<='0;
			rx_en_reg_1<='0;
			write_reg_1<='0;
			watchdog_trigger<='0;
			waitrequest_out<='0;
			first_rx_en<='0;
			write_fall<='0;
			write_count<='0;
			valid_write <='0;
		end else begin
			rx_en_reg_1<=rx_wait_enable;
			write_reg_1<=write;
			first_rx_en <= (rx_wait_enable &&	!rx_en_reg_1);
			write_fall <= (!write_reg_1 && write);
			if(Clear_buff) begin
				addr_reg<='0;
				burst_count<='0;
				watchdog_counter<='0;
				watchdog_trigger<='0;
				valid_write <='0;
			end else begin
				valid_write <= at_write_count&&write;
				waitrequest_out = !(rx_wait_enable || watchdog_trigger);
				//watchdog logic begin
				if(rx_wait_enable||!write) begin
					watchdog_trigger<='0;
					watchdog_counter<='0;
				end else begin
					if(watchdog_counter==watchdog_rx_conf) watchdog_trigger<=1'b1;
					else begin
						watchdog_counter<=watchdog_counter+1'b1;
					end
				end
				//watchdog logic end 
				
				//
				if(write&&at_write_count) begin
					write_count<='0;
				end else begin
					if(write&&!waitrequest_out) write_count<=write_count_plus_1;
				end
				//
				
				//burst_count logic begin
				if(!rx_wait_enable) burst_count<='0;
				else begin
				
					if(at_write_count&&write&&!waitrequest_out) burst_count<= burst_count +1'b1;
				end
				//burst_count logic end
				
				//addr_reg logic begin
				if(first_rx_en) addr_reg<='0;
				else begin
					if(valid_write) addr_reg<= addr_reg_plus_1;
				end
				//addr_reg logic end
					
			end
		end
	
	end 
	
endmodule