library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use WORK.data_pack.ALL;


package mem_pack is


	
	--relu out info
	constant fullyConnect_in_size : integer := pic_height*sub_pic_w*total_filters;
	constant fullyConnect_in_bit_size : integer :=fullyConnect_in_size*INT19_WIDTH;
	constant max_fullyconnect_in_per_inter_size :integer := num_of_conv_filter*pic_height*sub_pic_w;
	constant num_fullyconnect_inter:integer :=total_filters/num_of_conv_filter;
	constant max_fullyconnect_in_per_inter_bit_size :integer :=max_fullyconnect_in_per_inter_size*INT19_WIDTH;
	
	--mem def info
	constant relu_out_depth : integer :=total_filters+2;
	constant WFC_depth : integer :=num_fullyconnect_inter*N*3+1;
	constant BFC_depth : integer :=num_of_conv_ops+1;
	constant CONV_depth : integer :=num_of_conv_ops+1;
	
	constant relu_out_ADD_W : integer :=log2of(relu_out_depth);
	constant WFC_ADD_W : integer :=log2of(WFC_depth);
	constant BFC_ADD_W : integer :=log2of(BFC_depth);
	constant CONV_ADD_W : integer :=log2of(CONV_depth);
	
	constant relu_out_WIDTH : integer :=max_fullyconnect_in_per_inter_bit_size;
	constant WFC_WIDTH : integer :=INT8_WIDTH*num_of_18x18_multi*pic_height;
	constant BFC_WIDTH : integer :=INT45_WIDTH;
	constant CONV_W_WIDTH : integer :=INT8_WIDTH*filter_size*num_of_conv_filter;
	constant CONV_B_WIDTH : integer :=INT16_WIDTH*num_of_conv_filter;
	
	
	--mem addr info
	constant ADDR_CONV_start : integer :=0;
	constant ADDR_WFC_start : integer :=0;
	constant ADDR_BFC_start : integer :=0;
	constant ADDR_Relu_write_start : integer :=num_fullyconnect_inter;
	constant ADDR_Relu_read_start : integer :=0;
	
	constant ADDR_CONV_end : integer :=CONV_depth-2;
	constant ADDR_WFC_end : integer :=WFC_depth-2;
	constant ADDR_BFC_end : integer :=BFC_depth-2;
	constant ADDR_Relu_end : integer :=relu_out_depth-3;
	

	
	
	constant ADDR_CONV_zero : integer :=CONV_depth-1;
	constant ADDR_WFC_zero : integer :=WFC_depth-1;
	constant ADDR_BFC_zero : integer :=BFC_depth-1;
	
	constant ADDR_Relu_read_junk : integer :=relu_out_depth-1;
	constant ADDR_Relu_write_junk : integer :=relu_out_depth-2;
	
	
	-- Define a record to group MEM info
	type mem_rec is record
		mif_fn :string(mif_s'range);
		DATA_WIDTH : integer;
		ADDR_WIDTH : integer;
		DATA_DEPTH : integer;
	end record;
		
	constant relu_out_info : mem_rec :=
	(
		mif_fn=>mif_name(0),
		DATA_WIDTH=>relu_out_WIDTH,
		ADDR_WIDTH=>relu_out_ADD_W,
		DATA_DEPTH=>relu_out_depth
	);
	
	constant WFC_info : mem_rec :=
	(
		mif_fn=>mif_name(1),
		DATA_WIDTH=>WFC_WIDTH,
		ADDR_WIDTH=>WFC_ADD_W,
		DATA_DEPTH=>WFC_depth
	);
	
	constant BFC_info : mem_rec :=
	(
		mif_fn=>mif_name(2),
		DATA_WIDTH=>BFC_WIDTH,
		ADDR_WIDTH=>BFC_ADD_W,
		DATA_DEPTH=>BFC_depth
	);
	
	constant CONV_W_info : mem_rec :=
	(
		mif_fn=>mif_name(3),
		DATA_WIDTH=>CONV_W_WIDTH,
		ADDR_WIDTH=>CONV_ADD_W,
		DATA_DEPTH=>CONV_depth
	);
	
	constant CONV_B_info : mem_rec :=
	(
		mif_fn=>mif_name(4),
		DATA_WIDTH=>CONV_B_WIDTH,
		ADDR_WIDTH=>CONV_ADD_W,
		DATA_DEPTH=>CONV_depth
	);
	
	function addr_incress(addr,start_addr,final_addr: integer) return integer;
	

end package mem_pack;


package body mem_pack is
	
	function addr_incress(addr,start_addr,final_addr :integer) return integer is
		variable new_addr: integer range 0 to final_addr;
	begin
		if(addr=final_addr) then
			new_addr:=start_addr;
		else
			new_addr:=addr+1;
		end if;
		return new_addr;
	end function;



end package body mem_pack;