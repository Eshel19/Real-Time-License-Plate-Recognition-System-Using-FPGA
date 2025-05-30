library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;
use work.all;
use WORK.data_pack.ALL;
use WORK.dmu_pack.ALL;
use WORK.mem_pack.ALL;


package testbench_pack is


-- functions for testbench

	function sum_8x19_products(a: fullConnect_data; b: fullConnect_weight) return int29;
	function sum_9x8_products(a: conv_pixel; b: conv_weight) return int19;
	function create_int8_vector_9(input1, input2, input3, input4, input5, input6, input7, input8, input9: integer) return int8_vector;
	function create_int8_vector_8(input1, input2, input3, input4, input5, input6, input7, input8: integer) return int8_vector;
	function create_int19_vector_8(input1, input2, input3, input4, input5, input6, input7, input8: integer) return int19_vector;
	function read_mif(
		file_name : in string;
		address   : in integer;
		data_width : in integer
	) return std_logic_vector;
	
	
end package testbench_pack;


package body testbench_pack is


	------------------------------------
	--- Function for TB
	-----------------------------------
	function create_int19_vector_8(input1, input2, input3, input4, input5, input6, input7, input8: integer) return int19_vector is
		 variable result: int19_vector(0 to num_of_fullconnected_mode_size-1);
	begin
		 result(0) := to_signed(input1, INT19_WIDTH);
		 result(1) := to_signed(input2, INT19_WIDTH);
		 result(2) := to_signed(input3, INT19_WIDTH);
		 result(3) := to_signed(input4, INT19_WIDTH);
		 result(4) := to_signed(input5, INT19_WIDTH);
		 result(5) := to_signed(input6, INT19_WIDTH);
		 result(6) := to_signed(input7, INT19_WIDTH);
		 result(7) := to_signed(input8, INT19_WIDTH);
		 return result;
	end function;

	function create_int8_vector_8(input1, input2, input3, input4, input5, input6, input7, input8: integer) return int8_vector is
		 variable result: int8_vector(0 to num_of_fullconnected_mode_size-1);
	begin
		 result(0) := to_signed(input1, INT8_WIDTH);
		 result(1) := to_signed(input2, INT8_WIDTH);
		 result(2) := to_signed(input3, INT8_WIDTH);
		 result(3) := to_signed(input4, INT8_WIDTH);
		 result(4) := to_signed(input5, INT8_WIDTH);
		 result(5) := to_signed(input6, INT8_WIDTH);
		 result(6) := to_signed(input7, INT8_WIDTH);
		 result(7) := to_signed(input8, INT8_WIDTH);
		 return result;
	end function;


	function create_int8_vector_9(input1, input2, input3, input4, input5, input6, input7, input8, input9: integer) return int8_vector is
		 variable result: int8_vector(0 to filter_weight_size-1);
	begin
		 result(0) := to_signed(input1, INT8_WIDTH);
		 result(1) := to_signed(input2, INT8_WIDTH);
		 result(2) := to_signed(input3, INT8_WIDTH);
		 result(3) := to_signed(input4, INT8_WIDTH);
		 result(4) := to_signed(input5, INT8_WIDTH);
		 result(5) := to_signed(input6, INT8_WIDTH);
		 result(6) := to_signed(input7, INT8_WIDTH);
		 result(7) := to_signed(input8, INT8_WIDTH);
		 result(8) := to_signed(input9, INT8_WIDTH);
		 return result;
	end function;



	function sum_8x19_products(a: fullConnect_data; b: fullConnect_weight) return int29 is
		 variable result: int29 := (others => '0');
	begin
		 for i in 0 to 7 loop
			  result := result + resize(a(i) * b(i), INT29_WIDTH);
		 end loop;
		 return result;
	end function;


	function sum_9x8_products(a: conv_pixel; b: conv_weight) return int19 is
		 variable result: int19 := (others => '0');
	begin
		 for i in 0 to 8 loop
			  result := result + resize(a(i) * b(i), INT19_WIDTH);
		 end loop;
		 return result;
	end function;
	
	


	function read_mif(
		 file_name  : in string;
		 address    : in integer;
		 data_width : in integer
	) return std_logic_vector is
		 file mif_file    : text;
		 variable line_buffer : line;
		 variable line_str    : string(1 to 900000); -- Adjust as needed
		 variable data_val    : std_logic_vector(data_width-1 downto 0);
	begin
		 -- Open the MIF file for reading
		 file_open(mif_file, file_name, read_mode);

		 -- Skip the header lines (assume the data starts from a specific line)
		 for i in 1 to address loop
			  readline(mif_file, line_buffer);
		 end loop;

		 -- Read the line corresponding to the address
		 readline(mif_file, line_buffer);
		 read(line_buffer, line_str);

		 -- Convert the string to std_logic_vector
		 data_val := (others => '0'); -- Initialize with zeros
		 for i in 1 to data_width loop
			  if line_str(i) = '1' then
					data_val(data_width-i) := '1';
			  else
					data_val(data_width-i) := '0';
			  end if;
		 end loop;

		 -- Close the file
		 file_close(mif_file);

		 return data_val;
	end function;

	



	
end package body testbench_pack;