library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Include custom packages
use WORK.data_pack.ALL;
use WORK.mem_pack.ALL;

package dmu_pack is
	-- Define a 3x3 pixel group
	type int8_vector_9ele_array is array (natural range <>) of int8_vector(filter_size-1 downto 0);
	type int19_vector_8ele_array is array (natural range <>) of int19_vector(((relu_out_info.DATA_WIDTH/INT19_WIDTH)/pic_height)/3-1 downto 0);
	type int8_vector_8ele_array is array (natural range <>) of int8_vector(((WFC_info.DATA_WIDTH/INT8_WIDTH)/pic_height)-1 downto 0);

	
	function generate_pixel_groups(
			 buffer_left : int8_vector;  -- Input buffer A with downto indexing
			 buffer_mid : int8_vector;  -- Input buffer B with downto indexing
			 buffer_right : int8_vector   -- Input buffer C with downto indexing
	) return int8_vector_9ele_array;
	
	function fill_FC_right(
		input : int19_vector;
		FC_vector : int19_vector;
		sub_pic_w: integer
	)return int19_vector;
	
	function generate_mode_0_input(
			pixel_arr : int8_vector_9ele_array; w1,w2 : int8_vector; Num_of_units: integer
	) return conv_in_data_vector;
		
	function generate_mode_1_input(
			result_arr : int19_vector_8ele_array; 
			w_arr : int8_vector_8ele_array; 
			Num_of_units: integer
	) return conv_in_data_vector;	
		
	function split_to_int19_vector(
			input :std_logic_vector
	) return int19_vector;
		
	function split_to_int19_8ele_group(
			input :std_logic_vector;
			num_of_groups : integer
	) return int19_vector_8ele_array;
	
	function split_to_int8_vector(
			input :std_logic_vector 
	) return int8_vector;
	
	function split_to_int8_9ele_group(
			input :std_logic_vector;
			num_of_groups : integer
	) return int8_vector_9ele_array;
	
	function split_to_int8_8ele_group(
			input :std_logic_vector;
			num_of_groups : integer
	) return int8_vector_8ele_array;
	
	function split_to_int19_vec_8ele_group(
			input :int19_vector;
			num_of_groups : integer
	) return int19_vector_8ele_array;	
	
	
	function int19_vector_to_std_logic_vector(
		input : int19_vector
	) return std_logic_vector;
	
end package dmu_pack;


package body dmu_pack is


	----split for pixel
	function split_to_int8_vector(
			input :std_logic_vector 
	) return int8_vector is
		variable result : int8_vector((input'length/INT8_WIDTH)-1 downto 0);
	begin
		for i in result'range loop
			result(i):=signed(input((i+1)*INT8_WIDTH-1 downto i*INT8_WIDTH));
		end loop;
		return result;
	end function;

	function generate_pixel_groups(
		 buffer_left : int8_vector;  -- Input buffer A with downto indexing
		 buffer_mid : int8_vector;  -- Input buffer B with downto indexing
		 buffer_right : int8_vector   -- Input buffer C with downto indexing
	) return int8_vector_9ele_array is
		 constant pic_height : integer := buffer_left'length;  -- Number of pixels in each buffer
		 constant group_size : integer := 9;                -- Each group has 9 elements

		 -- Define the array to hold all the pixel groups with downto indexing
		 variable num_groups : integer := pic_height;
		 variable groups : int8_vector_9ele_array(num_groups - 1 downto 0);  -- Groups indexed from highest to lowest
		 variable pg : int8_vector(group_size - 1 downto 0);            -- Pixel group with downto indexing
		 variable idx : integer;
	begin
		 -- Iterate over each group from highest to lowest index
		 for i in num_groups - 1 downto 0 loop
			  -- Initialize the pixel group with zeros
			  pg := (others => (others => '0'));

			  -- Assign pixels to the pixel group

			  -- Top Row (indices 8, 7, 6)
			  if i = num_groups - 1 then
					-- Zero-padding at the top edge
					pg(8) :=MAX_INT8; --(others => '0');
					pg(7) :=MAX_INT8; --(others => '0');
					pg(6) :=MAX_INT8; --(others => '0');
			  else
					idx := i + 1;
					pg(8) := buffer_left(idx);
					pg(7) := buffer_mid(idx);
					pg(6) := buffer_right(idx);
			  end if;

			  -- Middle Row (indices 5, 4, 3)
			  idx := i;
			  pg(5) := buffer_left(idx);
			  pg(4) := buffer_mid(idx);
			  pg(3) := buffer_right(idx);

			  -- Bottom Row (indices 2, 1, 0)
			  if i = 0 then
					-- Zero-padding at the bottom edge
					pg(2) :=MAX_INT8; --(others => '0');
					pg(1) :=MAX_INT8; --(others => '0');
					pg(0) :=MAX_INT8; --(others => '0');
			  else
					idx := i - 1;
					pg(2) := buffer_left(idx);
					pg(1) := buffer_mid(idx);
					pg(0) := buffer_right(idx);
			  end if;

			  -- Store the pixel group in the groups array
			  groups(i) := pg;
		 end loop;

		 return groups;
	end function;
	
	function fill_FC_right(
		input : int19_vector;
		FC_vector : int19_vector;
		sub_pic_w: integer
	) return int19_vector is
		variable result : int19_vector(FC_vector'length-1 downto 0);
		variable temp  : int19_vector(FC_vector'length-1 downto 0);
	begin
		temp:=FC_vector;
		for i in input'range loop
			result(((i+1)*sub_pic_w)-1 downto i*(sub_pic_w)):=temp(((i+1)*sub_pic_w)-2 downto i*(sub_pic_w))&input(i);
		end loop;
		return result;
	end function;
	
	
	function generate_mode_0_input(pixel_arr : int8_vector_9ele_array; w1,w2 : int8_vector; Num_of_units: integer) return conv_in_data_vector is
		variable result : conv_in_data_vector(Num_of_units-1 downto 0);
	begin
		for i in result'range loop
			result(i):=combine_conv_data(pixel_arr(i),w1,w2);
		end loop;
		return result;
	end function;
	
	function generate_mode_1_input(
			result_arr : int19_vector_8ele_array; 
			w_arr : int8_vector_8ele_array; 
			Num_of_units: integer
		)return conv_in_data_vector is 
		variable result : conv_in_data_vector(Num_of_units-1 downto 0);
		
	begin
		for i in result'range loop
			result(i):=combine_fullConnect_data(result_arr(i),w_arr(i));
		end loop;
		return result;
	end function;
	
	
	
	----split for Relu_data
	function split_to_int19_vector(
			input :std_logic_vector
	) return int19_vector is
		variable result : int19_vector((input'length/INT19_WIDTH)-1 downto 0);
	begin
		for i in result'range loop
			result(i):=signed(input((i+1)*INT19_WIDTH-1 downto i*INT19_WIDTH));
		end loop;
		return result;
	end function;
		
	function int19_vector_to_std_logic_vector(
		input : int19_vector
	) return std_logic_vector is
		variable result : std_logic_vector(input'length * INT19_WIDTH - 1 downto 0);
	begin
	
		for i in input'range loop
			result((i+1)*INT19_WIDTH-1 downto i*INT19_WIDTH) := std_logic_vector(input(i));
		end loop;
		return result;
	end function;
		

	function split_to_int19_8ele_group(
			input :std_logic_vector;
			num_of_groups : integer
	) return int19_vector_8ele_array is
		variable result_split : int19_vector((input'length/INT19_WIDTH)-1 downto 0);
		variable result : int19_vector_8ele_array(num_of_groups-1 downto 0);
	begin
		result_split:=split_to_int19_vector(input);
		for i in result'range loop
			result(i):=result_split((i+1)*(result_split'length/num_of_groups)-1 downto i*(result_split'length/num_of_groups));
		end loop;
		return result;
	end function;
	
	
	
	----split vector int8 to 9 element group
	function split_to_int8_9ele_group(
			input :std_logic_vector;
			num_of_groups : integer
	) return int8_vector_9ele_array is
		variable result_split : int8_vector((input'length/INT8_WIDTH)-1 downto 0);
		variable result : int8_vector_9ele_array(num_of_groups-1 downto 0);
	begin
		result_split:=split_to_int8_vector(input);
		for i in result'range loop
			result(i):=result_split((i+1)*(result_split'length/num_of_groups)-1 downto i*(result_split'length/num_of_groups));
		end loop;
		return result;
	end function;

	----split vector int8 to  element group
	function split_to_int8_8ele_group(
			input :std_logic_vector;
			num_of_groups : integer
	) return int8_vector_8ele_array is
		variable result_split : int8_vector((input'length/INT8_WIDTH)-1 downto 0);
		variable result : int8_vector_8ele_array(num_of_groups-1 downto 0);
	begin
		result_split:=split_to_int8_vector(input);
		for i in result'range loop
			result(i):=result_split((i+1)*(result_split'length/num_of_groups)-1 downto i*(result_split'length/num_of_groups));
		end loop;
		return result;
	end function;
	
	function split_to_int19_vec_8ele_group(
			input :int19_vector;
			num_of_groups : integer
	) return int19_vector_8ele_array is
		variable result : int19_vector_8ele_array(num_of_groups-1 downto 0);
	begin
		for i in result'range loop
			result(i):=input((i+1)*(input'length/num_of_groups)-1 downto i*(input'length/num_of_groups));
		end loop;
		return result;
	end function;
	
	
end package body dmu_pack;