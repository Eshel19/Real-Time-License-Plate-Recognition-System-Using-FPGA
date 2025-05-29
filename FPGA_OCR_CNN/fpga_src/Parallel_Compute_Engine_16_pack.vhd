library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use WORK.multiplier_pack.ALL;
use WORK.data_pack.ALL;

package Parallel_Compute_Engine_16_pack is

	function Relu(num :signed) return signed;
	function full_relu_int19(a : int19_vector) return int19_vector;
	function split_R_result(a :conv_out_data_vector) return int19_vector;
	function split_L_result(a :conv_out_data_vector) return int19_vector;
	function split_result(a : conv_out_data_vector) return int29_vector;
	function add_bais_N_results (a : int19_vector; bais : signed) return int19_vector;
	function sum_int29(a : int29_vector) return int45;
	function hierarchical_sum(a : int29_vector) return int45;
	
end package Parallel_Compute_Engine_16_pack;


package body Parallel_Compute_Engine_16_pack is

	function sum_int29(a : int29_vector) return int45 is
		variable result : int45:=(others=>'0');
		
	begin
		if(a'length=1) then
			result:=resize(a(0),result'length);
		else
			result:=a(a'length-1)+sum_int29(a(a'length-2 downto 0));
		end if;
--		for i in a'length-1 downto 0 loop
--			result:=result+a(i);
--		end loop;
		return result;
	end function;
	
	function hierarchical_sum(a : int29_vector) return int45 is
		constant num_pairs_1 : integer := 8;
		constant num_pairs_2 : integer := 4;
		constant num_pairs_3 : integer := 2;
		variable temp_results_1 : int45_vector(0 to num_pairs_1-1);
		variable temp_results_2 : int45_vector(0 to num_pairs_2-1);
		variable temp_results_3 : int45_vector(0 to num_pairs_3-1);
		variable final_sum : int45 := (others => '0');
	begin
		-- Step 1: Sum 16 pairs into 8 results
		for i in 0 to num_pairs_1-1 loop
			temp_results_1(i) := resize(a(2*i), 45) + resize(a(2*i + 1), 45);
		end loop;

		-- Step 2: Sum 8 results into 4 results
		for i in 0 to num_pairs_2-1 loop
			temp_results_2(i) := temp_results_1(2*i) + temp_results_1(2*i + 1);
		end loop;

		-- Step 3: Sum 4 results into 2 results
		for i in 0 to num_pairs_3-1 loop
			temp_results_3(i) := temp_results_2(2*i) + temp_results_2(2*i + 1);
		end loop;

		-- Step 4: Sum 2 results into final sum
		final_sum := temp_results_3(0) + temp_results_3(1);

		return final_sum;
	end function;



	function add_bais_N_results (a : int19_vector; bais :signed) return int19_vector is
		variable result : int19_vector(a'length-1 downto 0);
	begin
		for i in a'length-1 downto 0 loop
			result(i):=a(i)+bais;
		end loop;
		return result;
	end function; 
	
	
	function Relu(num : signed) return signed is
		variable result : signed(num'range);
	begin
		if num(num'left) = '1' then  -- Check if the number is negative
			result:= (others => '0');  -- Return 0
		else
			result:= num;  -- Return the original number if it's non-negative
		end if;
		return result;
	end function;


	function full_relu_int19(a : int19_vector) return int19_vector is
		variable result : int19_vector(a'length-1 downto 0);
	begin
		for i in a'length-1 downto 0 loop
			result(i):=Relu(a(i));
		end loop;
		return result;
	end function;
		
	function split_L_result(a :conv_out_data_vector) return int19_vector is
		variable result : int19_vector(a'length-1 downto 0);
	begin
		for i in a'length-1 downto 0 loop
			result(i):=conv_out_data_to_two_int19(a(i))(0);
		end loop;
		return result;
	end function;
	
	
	function split_R_result(a :conv_out_data_vector) return int19_vector is
		variable result : int19_vector(a'length-1 downto 0);
	begin
		for i in a'length-1 downto 0 loop
			result(i):=conv_out_data_to_two_int19(a(i))(1);
		end loop;
		return result;
	end function;
	
	function split_result(a :conv_out_data_vector) return int29_vector is
		variable result : int29_vector(a'length-1 downto 0);
	begin
		for i in a'length-1 downto 0 loop
			result(i):=conv_out_data_to_int29(a(i));
		end loop;
		return result;
	end function;
	
end package body Parallel_Compute_Engine_16_pack;