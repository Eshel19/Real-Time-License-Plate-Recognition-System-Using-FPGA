library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

package data_pack is




	----model information 
	constant pic_height : integer := 16;
	constant sub_pic_w : integer :=12;
	constant filter_size : integer := 9;
	constant num_of_conv_filter : integer := 2;
	constant N : integer :=10; -- number of models
	constant T_RAM: integer :=2;
	constant T_find_winner : integer :=2;
	constant num_of_mem_banks : integer :=5;
	
	--The output string is set from Model 0 until model N 
	constant Model_outputs_str : string := "0123456789";
	type integer_array is array (natural range <>) of integer;
	
	
	--Define Threshold for each model 
	constant integer_values_threshold : integer_array(0 to N-1) := (
		 0  => 1,
		 1  => 2,
		 2  => 3,
		 3  => 4,
		 4  => 5,
		 5  => 6,
		 6  => 7,
		 7  => 8,
		 8  => 9,
		 9  => 10
	);

	
	--DSP multiplier split info
	constant Total_DPS_Count : integer := 112;
	constant num_of_9x9_multi_per_DSP : integer := 3;
	constant num_of_18x18_multi_per_DSP : integer := 2;
	constant num_of_9x9_multi : integer := 18;
	constant num_of_18x18_multi : integer := 8;
	
	--Mif files
	constant mif_s : string := "CON_W.mif";
	constant thre_mif: string:="threshold.mif";
	type mif is array (natural range <>) of string(mif_s'range);
	constant mif_name : mif :=("REL_O.mif","FCM_W.mif","FCM_B.mif","CON_W.mif","CON_B.mif","image.mif");
	
	
	
	
	
	--define int type
	constant INT8_WIDTH : integer := 8;
	constant INT9_WIDTH : integer := 9;
	constant INT17_WIDTH : integer := 17;
	constant INT16_WIDTH : integer := 16;
	constant INT18_WIDTH : integer := 18;
	constant INT19_WIDTH : integer := 19;
	constant INT24_WIDTH : integer := 24;
	constant INT27_WIDTH : integer := 27;
	constant INT29_WIDTH : integer := 29;
	constant INT38_WIDTH : integer := 38;
	constant INT45_WIDTH : integer := 45;
	constant INT64_WIDTH : integer := 64;

	
	subtype int9 is signed(INT9_WIDTH-1 downto 0); -- for 9x9 multiplications
	subtype int8 is signed(INT8_WIDTH-1 downto 0); -- data, weight and bais size
	subtype int16 is signed(INT16_WIDTH-1 downto 0); -- result for 8x8 multiplications
	subtype int18 is signed(INT18_WIDTH-1 downto 0); -- result for 9x9 
	subtype int19 is signed(INT19_WIDTH-1 downto 0); -- max result size for sum of 9 int16 + int8 bais
	subtype int27 is signed(INT27_WIDTH-1 downto 0); -- max result size of 19x8 multiplications
	subtype int45 is signed(INT45_WIDTH-1 downto 0); -- 45-bit max result for sum of 384 int29 + int8 bias
	subtype int24 is signed(INT24_WIDTH-1 downto 0); 
	subtype int17 is signed(INT17_WIDTH-1 downto 0); 
	subtype int29 is signed(INT29_WIDTH-1 downto 0); -- Max result size for sum of 8 int27
	subtype int38 is signed(INT38_WIDTH-1 downto 0); -- result size of 19x18 multiplications
	subtype uint64 is unsigned(INT64_WIDTH-1 downto 0);
	subtype uint8 is unsigned(INT8_WIDTH-1 downto 0);
	subtype uint27 is unsigned(INT27_WIDTH-1 downto 0);
	subtype uint19 is unsigned(INT19_WIDTH-1 downto 0);
	subtype char is integer range 0 to 255;

	constant MAX_INT19 : int19:= to_signed((2**18)-1,INT19_WIDTH);
	constant MIN_INT19 : int19:= to_signed(-(2**18),INT19_WIDTH);
	constant MAX_INT18 : int18:= to_signed((2**17)-1,INT18_WIDTH);
	constant MIN_INT18 : int18:= to_signed(-(2**17),INT18_WIDTH);

	--Define types for arrays
	type int9_vector is array (natural range <>) of int9;
	type int19_vector is array (natural range <>) of int19;
	type int16_vector is array (natural range <>) of int16;
	type int8_vector is array (natural range <>) of int8;
	type int24_vector is array (natural range <>) of int24;
	type int27_vector is array (natural range <>) of int27;
	type int17_vector is array (natural range <>) of int17;
	type int29_vector is array (natural range <>) of int29;
	type int45_vector is array (natural range <>) of int45;
	type int18_vector is array (natural range <>) of int18;
	type int38_vector is array (natural range <>) of int38;
	type uint8_vector is array (natural range <>) of uint8;
	type uint19_vector is array (natural range <>) of uint19;
	type uint27_vector is array (natural range <>) of uint27;
	type char_vector is array (natural range <>) of char;

	

	constant pixel_input_size : integer:= filter_size;
	constant filter_weight_size : integer:= filter_size;
	constant conv_data_in_size : integer := (pixel_input_size+filter_weight_size*num_of_conv_filter)*INT8_WIDTH;
	constant num_of_fullconnected_mode_size : integer :=conv_data_in_size/(INT8_WIDTH+INT19_WIDTH); 
	constant conv_data_out_size : integer :=INT19_WIDTH*num_of_conv_filter;
	

	--conv block in out vector
	subtype conv_in_data is std_logic_vector(conv_data_in_size-1 downto 0);
	type conv_in_data_vector is array (natural range <>) of conv_in_data;
	subtype conv_out_data is std_logic_vector(conv_data_out_size-1 downto 0);
	type conv_out_data_vector is array (natural range <>) of conv_out_data;

	--conv mode data array 
	subtype conv_weight is int8_vector(0 to filter_weight_size-1);
	subtype conv_pixel is int8_vector(0 to pixel_input_size-1);

	--Fully Connect data array
	subtype fullConnect_data is int19_vector(0 to num_of_fullconnected_mode_size-1);
	subtype fullConnect_weight is int8_vector(0 to num_of_fullconnected_mode_size-1);
	

	
	
	--data mangmant functions
	function extract_conv_pixel(conv_data: conv_in_data) return conv_pixel;
	function extract_conv_weight_1(conv_data: conv_in_data) return conv_weight;
	function extract_conv_weight_2(conv_data: conv_in_data) return conv_weight;
	function extract_fullConnect_data(conv_data: conv_in_data) return fullConnect_data;
	function extract_fullConnect_weight(conv_data: conv_in_data) return fullConnect_weight;
	function combine_conv_data(pixel: conv_pixel; weight1: conv_weight; weight2: conv_weight) return conv_in_data;
	function combine_fullConnect_data(data: fullConnect_data; weight: fullConnect_weight) return conv_in_data;
	function two_int19_to_conv_out_data(a, b : int19) return conv_out_data;
	function int29_to_conv_out_data(a : int29) return conv_out_data;
	function conv_out_data_to_two_int19(conv_data : conv_out_data) return int19_vector;
	function conv_out_data_to_int29(conv_data : conv_out_data) return int29;
	function int19_vector_to_slv(input_vector : int19_vector) return std_logic_vector;
	
	
	---function for calculation
	function log2of (num : integer) return integer; 
	function String_To_Char_Vector(s : in string) return char_vector;
	function Convert_Int_Array_To_Signed(input_array : integer_array) return int45_vector;

	
end package data_pack;


package body data_pack is

	-- Function to convert integer array to int45_vector
	function Convert_Int_Array_To_Signed(input_array : integer_array) return int45_vector is
		variable result_array : int45_vector(input_array'range);
	begin
		for i in input_array'range loop
			result_array(i) := to_signed(input_array(i), INT45_WIDTH);
		end loop;
		return result_array;
	end function;

	
	function log2of (num : integer) return integer is
		variable result : integer;
	begin
		if(num=1) then return 1;
		end if;
		result:= 1+log2of(num/2);
		return result;
	end function log2of;

	function String_To_Char_Vector(s : in string) return char_vector is
		variable result : char_vector(s'range);
	begin
		for i in s'range loop
			result(i) := character'pos(s(i));
		end loop;
		return result;
	end function String_To_Char_Vector;


	--data extection function:
	function extract_conv_pixel(conv_data: conv_in_data) return conv_pixel is
		 variable pixel : conv_pixel;
		 variable offset : integer :=INT8_WIDTH*filter_weight_size*3;
	begin
		 for i in 0 to filter_size-1 loop
			  pixel(i) := signed(conv_data(offset -i*INT8_WIDTH-1 downto 
			  offset -(i+1)*INT8_WIDTH));
		 end loop;
		 return pixel;
	end function;


	function extract_conv_weight_1(conv_data: conv_in_data) return conv_weight is
		 variable weight : conv_weight;
		 variable offset : integer :=INT8_WIDTH*filter_weight_size*2;
	begin
		 for i in 0 to filter_size-1 loop
			  weight(i) :=  signed(conv_data(offset -i*INT8_WIDTH-1 downto 
			  offset -(i+1)*INT8_WIDTH));
		 end loop;
		 return weight;
	end function;

	function extract_conv_weight_2(conv_data: conv_in_data) return conv_weight is
		 variable weight : conv_weight;
		 variable offset : integer :=INT8_WIDTH*filter_weight_size;
	begin
		 for i in 0 to filter_size-1 loop
			  weight(i) :=  signed(conv_data(offset -i*INT8_WIDTH-1 downto 
			  offset -(i+1)*INT8_WIDTH));
		 end loop;
		 return weight;
	end function;

	function extract_fullConnect_data(conv_data: conv_in_data) return fullConnect_data is
		 variable data : fullConnect_data;
		 constant offset : integer := num_of_fullconnected_mode_size * (INT19_WIDTH+INT8_WIDTH);
	begin
		 for i in 0 to num_of_fullconnected_mode_size-1 loop
			  data(i) := signed(conv_data((offset - i*INT19_WIDTH-1) downto (offset - (i+1)*INT19_WIDTH)));
		 end loop;
		 return data;
	end function;

	function extract_fullConnect_weight(conv_data: conv_in_data) return fullConnect_weight is
		 variable weight : fullConnect_weight;
		 constant offset : integer := num_of_fullconnected_mode_size * INT8_WIDTH;
	begin
		 for i in 0 to num_of_fullconnected_mode_size-1 loop
			  weight(i) := signed(conv_data((offset - i*INT8_WIDTH-1) downto (offset - (i+1)*INT8_WIDTH)));
		 end loop;
		 return weight;
	end function;

	--data combine for multi block function:
	function combine_conv_data(pixel: conv_pixel; weight1: conv_weight; weight2: conv_weight) return conv_in_data is
		 variable conv_data : conv_in_data;
		 variable offset : integer :=pixel_input_size*INT8_WIDTH;
	begin
		for i in 0 to filter_size-1 loop
			conv_data(offset -i*INT8_WIDTH-1 downto offset -(i+1)*INT8_WIDTH) := std_logic_vector(weight2(i));
		end loop;
		for i in 0 to filter_size-1 loop
			conv_data(offset*2 -i*INT8_WIDTH-1 downto offset*2 -(i+1)*INT8_WIDTH) := std_logic_vector(weight1(i));
		end loop;
		for i in 0 to filter_size-1 loop
			conv_data(offset*3 -i*INT8_WIDTH-1 downto offset*3 -(i+1)*INT8_WIDTH) := std_logic_vector(pixel(i));
		end loop;
		return conv_data;
	end function;


	function combine_fullConnect_data(data: fullConnect_data; weight: fullConnect_weight) return conv_in_data is
		 variable conv_data : conv_in_data;
	begin
		 for i in 0 to num_of_fullconnected_mode_size-1 loop
			  conv_data((num_of_fullconnected_mode_size-i)*INT19_WIDTH-1+num_of_fullconnected_mode_size*INT8_WIDTH downto 
			  (num_of_fullconnected_mode_size-(i+1))*INT19_WIDTH +num_of_fullconnected_mode_size*INT8_WIDTH) := std_logic_vector(data(i));
		 end loop;
		 for i in 0 to num_of_fullconnected_mode_size-1 loop
			  conv_data((num_of_fullconnected_mode_size-i)*INT8_WIDTH-1 downto (num_of_fullconnected_mode_size-(i+1))*INT8_WIDTH) := std_logic_vector(weight(i));
		 end loop;
		 return conv_data;
	end function;

	--data transfer for outputs for multi block function:
	function two_int19_to_conv_out_data(a, b : int19) return conv_out_data is
		 variable conv_data : conv_out_data;
	begin
		 conv_data(INT19_WIDTH-1 downto 0) := std_logic_vector(a);
		 conv_data(2*INT19_WIDTH-1 downto INT19_WIDTH) := std_logic_vector(b);
		 return conv_data;
	end function;

	function int29_to_conv_out_data(a : int29) return conv_out_data is
		variable conv_data : conv_out_data:=(others=>'0');
		variable tmp : int38;
	begin
		tmp:=resize(a,INT38_WIDTH);
		conv_data:= std_logic_vector(tmp);
		return conv_data;
	end function;

	function conv_out_data_to_two_int19(conv_data : conv_out_data) return int19_vector is
		 variable result : int19_vector(0 to 1);
	begin
		 result(0) := signed(conv_data(INT19_WIDTH-1 downto 0));
		 result(1) := signed(conv_data(2*INT19_WIDTH-1 downto INT19_WIDTH));
		 return result;
	end function;


	function conv_out_data_to_int29(conv_data : conv_out_data) return int29 is
		 variable result : int29;
	begin
		 result := signed(conv_data(INT29_WIDTH-1 downto 0));
		 return result;
	end function;

	function int19_vector_to_slv(input_vector : int19_vector) return std_logic_vector is
		variable result : std_logic_vector((input_vector'length * INT19_WIDTH)-1 downto 0);
		variable index  : integer := 0;
	begin
		for i in input_vector'range loop
			result((i+1)*INT19_WIDTH - 1 downto i*INT19_WIDTH) := std_logic_vector(input_vector(i));
		end loop;
		return result;
	end function;


end package body data_pack;