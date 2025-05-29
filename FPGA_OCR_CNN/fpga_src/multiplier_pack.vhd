library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use WORK.data_pack.ALL;


package multiplier_pack is


	constant num_of_DPS_per_block : integer := Total_DPS_Count/pic_height;
	constant num_of_18x18_DSP : integer := num_of_18x18_multi/num_of_18x18_multi_per_DSP;
	constant num_of_9x9_DSP : integer :=num_of_DPS_per_block-num_of_18x18_DSP;
	constant num_of_9x9_multi_DSP : integer :=num_of_9x9_DSP*num_of_9x9_multi_per_DSP;
	constant num_of_9x9_multi_ALM : integer :=num_of_9x9_multi-num_of_9x9_multi_DSP-num_of_18x18_multi;
	constant num_of_18x18_multi_for_Cw1: integer :=num_of_18x18_multi;
	constant num_of_18x18_multi_for_Cw2: integer :=0;
	constant num_of_9x9_multi_DSP_for_Cw2: integer :=num_of_9x9_multi_DSP;
	constant num_of_9x9_multi_DSP_for_Cw1: integer :=0;
	constant num_of_9x9_multi_ALM_for_Cw1: integer :=filter_size-(num_of_18x18_multi_for_Cw1+num_of_9x9_multi_DSP_for_Cw1);
	constant num_of_9x9_multi_ALM_for_Cw2: integer :=filter_size-(num_of_18x18_multi_for_Cw2+num_of_9x9_multi_DSP_for_Cw2);
	constant idx_18x18_Cw1_start : integer := 0;
	constant idx_18x18_Cw1_end   : integer := idx_18x18_Cw1_start + num_of_18x18_multi_for_Cw1 - 1;
	constant idx_18x18_Cw2_start : integer := idx_18x18_Cw1_end + 1;  -- This will be idx_18x18_Cw1_end + 1
	constant idx_18x18_Cw2_end   : integer := idx_18x18_Cw2_start + num_of_18x18_multi_for_Cw2 - 1;
	constant idx_9x9_DSP_Cw1_start : integer := 0;
	constant idx_9x9_DSP_Cw1_end   : integer := idx_9x9_DSP_Cw1_start + num_of_9x9_multi_DSP_for_Cw1 - 1;
	constant idx_9x9_DSP_Cw2_start : integer := idx_9x9_DSP_Cw1_end + 1;
	constant idx_9x9_DSP_Cw2_end   : integer := idx_9x9_DSP_Cw2_start + num_of_9x9_multi_DSP_for_Cw2 - 1;
	constant idx_9x9_ALM_Cw1_start : integer := 0;
	constant idx_9x9_ALM_Cw1_end   : integer := idx_9x9_ALM_Cw1_start + num_of_9x9_multi_ALM_for_Cw1 - 1;
	

		--MUltil datas arrays
	subtype Result_9x9_DSP is int18_vector(0 to num_of_9x9_multi_DSP-1);
	subtype Result_9x9_ALM is int18_vector(0 to num_of_9x9_multi_ALM-1);
	subtype Result_19x8 is int27_vector(0 to num_of_18x18_multi-1);
	
	subtype input_8x8_DSP is int8_vector(0 to num_of_9x9_multi_DSP-1);
	subtype input_8x8_ALM is int8_vector(0 to num_of_9x9_multi_ALM-1);
	
	subtype input_19X8_19 is int19_vector(0 to num_of_18x18_multi-1);
	subtype input_19X8_8 is int8_vector(0 to num_of_18x18_multi-1);
	
	-- Define a record to group the subtypes
	type multiplier_inputs_t is record
		A_8x8_DSP : input_8x8_DSP;
		B_8x8_DSP : input_8x8_DSP;
		A_8x8_ALM : input_8x8_ALM;
		B_8x8_ALM : input_8x8_ALM;
		A_19X8_19 : input_19X8_19;
		B_19X8_8  : input_19X8_8;
	end record;
	
	
	--MUltilpiler functions
	function Multi8x8(a, b: int8) return int18;
	function Multi8x8_Hierarchical(a, b: int8) return int18;
	function Full_matrix_multi_8x8_DSP(a,b :input_8x8_DSP) return Result_9x9_DSP;
	function Full_matrix_multi_8x8_ALM(a,b :input_8x8_ALM) return Result_9x9_ALM;
	function Full_matrix_multi_19x8(a :input_19X8_19;b :input_19X8_8) return Result_19x8;
	function generate_multiplier_inputs(data_in :conv_in_data; select_mode:std_logic) return multiplier_inputs_t;
	function sum_of_9x9(a : int18_vector) return int19;
	function sum_of_19x8(a : int27_vector) return int29;

end multiplier_pack;


package body multiplier_pack is

	function generate_multiplier_inputs(data_in :conv_in_data; select_mode:std_logic) 
	return multiplier_inputs_t is
		variable conv_w1,conv_w2: conv_weight;
		variable pixel_in : conv_pixel;
		variable fully_data :fullConnect_data ;
		variable fully_weight : fullConnect_weight;
		variable result : multiplier_inputs_t;
	begin
		
		pixel_in:=extract_conv_pixel(data_in);
		conv_w1:=extract_conv_weight_1(data_in);
		conv_w2:=extract_conv_weight_2(data_in);
		fully_data:=extract_fullConnect_data(data_in);
		fully_weight:=extract_fullConnect_weight(data_in);

		if(num_of_18x18_multi_for_Cw1>0) then
			for i in 0 to num_of_18x18_multi_for_Cw1-1 loop
				result.A_19x8_19(i):=resize(pixel_in(i),INT19_WIDTH);
				result.B_19x8_8(i):=conv_w1(i);
			end loop;
		end if;
		if(num_of_9x9_multi_DSP_for_Cw1>0) then
			for i in 0 to num_of_9x9_multi_DSP_for_Cw1-1 loop
				result.A_8x8_DSP(i):=pixel_in(i+num_of_9x9_multi_DSP_for_Cw1);
				result.B_8x8_DSP(i):=conv_w1(i+num_of_9x9_multi_DSP_for_Cw1);
			end loop;
		end if;
		if(num_of_9x9_multi_ALM_for_Cw1>0) then
			for i in 0 to num_of_9x9_multi_ALM_for_Cw1-1 loop
				result.A_8x8_ALM(i):=pixel_in(i+num_of_9x9_multi_DSP_for_Cw1+num_of_18x18_multi_for_Cw1);
				result.B_8x8_ALM(i):=conv_w1(i+num_of_9x9_multi_DSP_for_Cw1+num_of_18x18_multi_for_Cw1);
			end loop;
		end if;
		if(num_of_18x18_multi_for_Cw2>0) then
			for i in 0 to num_of_18x18_multi_for_Cw2-1 loop
				result.A_19x8_19(i+num_of_18x18_multi_for_Cw1):=resize(pixel_in(i),INT19_WIDTH);
				result.B_19x8_8(i+num_of_18x18_multi_for_Cw1):=conv_w2(i);
			end loop;
		end if;
		if(num_of_9x9_multi_DSP_for_Cw2>0) then
			for i in 0 to num_of_9x9_multi_DSP_for_Cw2-1 loop
				result.A_8x8_DSP(i+num_of_9x9_multi_DSP_for_Cw1):=pixel_in(i+num_of_18x18_multi_for_Cw2);
				result.B_8x8_DSP(i+num_of_9x9_multi_DSP_for_Cw1):=conv_w2(i+num_of_18x18_multi_for_Cw2);
			end loop;
		end if;
		if(num_of_9x9_multi_ALM_for_Cw2>0) then
			for i in 0 to num_of_9x9_multi_ALM_for_Cw2-1 loop
				result.A_8x8_ALM(i+num_of_9x9_multi_ALM_for_Cw1):=pixel_in(i+num_of_18x18_multi_for_Cw2+num_of_9x9_multi_ALM_for_Cw2);
				result.B_8x8_ALM(i+num_of_9x9_multi_ALM_for_Cw1):=conv_w2(i+num_of_18x18_multi_for_Cw2+num_of_9x9_multi_ALM_for_Cw2);
			end loop;
		end if;
		
		if(select_mode='1') then
			for i in 0 to fully_data'length-1 loop
				result.A_19x8_19(i):=fully_data(i);
				result.B_19x8_8(i):=fully_weight(i);
			end loop;
		end if;
		return result;
	end function;
	
	
	function Full_matrix_multi_8x8_DSP(a,b :input_8x8_DSP) return Result_9x9_DSP is
		variable result :Result_9x9_DSP;
	begin
		for i in 0 to 2 loop
			result(i*3):=resize(a(i*3)*b(i*3),18);
			result(i*3+1):=resize(a(i*3+1)*b(i*3+1),18);
			result(i*3+2):=resize(a(i*3+2)*b(i*3+2),18);
		end loop;
		return result;
	end function;


	function Full_matrix_multi_8x8_ALM(a,b :input_8x8_ALM) return Result_9x9_ALM is
		variable result :Result_9x9_ALM;
	begin
		for i in 0 to result'length-1 loop
			result(i):=Multi8x8(a(i),b(i));
		end loop;
		return result;
	end function;

	function Full_matrix_multi_19x8(a :input_19X8_19;b :input_19X8_8) return Result_19x8 is
		variable result :Result_19x8;
		variable abs_A: uint19_vector(0 to num_of_18x18_multi-1);
		variable abs_B: uint8_vector(0 to num_of_18x18_multi-1);
		variable sign_A, sign_B: std_logic_vector(0 to num_of_18x18_multi-1);
		variable sign_Result: std_logic_vector(0 to num_of_18x18_multi-1);
		variable product_unsigned: uint27_vector(0 to num_of_18x18_multi-1);
	begin
		for i in 0 to num_of_18x18_multi-1 loop 
		-- Extract sign bits
			sign_A(i) := A(i)(18);  -- MSB of A
			sign_B(i) := B(i)(7);   -- MSB of B

			-- Compute absolute values
			if sign_A(i) = '1' then
				abs_A(i) := unsigned(-a(i));
			else
				abs_A(i) := unsigned(a(i));
			end if;

			if sign_B(i) = '1' then
				abs_B(i) := unsigned(-b(i));
			else
				abs_B(i) := unsigned(b(i));
			end if;
		end loop;
		-- Perform unsigned multiplication
		
		for i in 0 to num_of_18x18_DSP-1 loop
			product_unsigned(i*2) := abs_A(i*2) * abs_B(i*2);
			product_unsigned(i*2+1) := abs_A(i*2+1) * abs_B(i*2+1);

		end loop;
		-- Determine the sign of the result
		for i in 0 to num_of_18x18_multi-1 loop 
			if sign_A(i) = sign_B(i) then
				sign_Result(i) := '0';  -- Positive result
			else
				sign_Result(i) := '1';  -- Negative result
			end if;

			-- Convert the unsigned product to signed
			if sign_Result(i) = '1' then
				result(i) := -signed(product_unsigned(i));
			else
				result(i) := signed(product_unsigned(i));
			end if;
		end loop;
		return result;
	end function;
	
	function sum_of_9x9(a : int18_vector) return int19 is
		variable s01, s23, s45, s67 : int19;
		variable s018, s2345 : int19;
		variable result : int19;
	begin
		-- Pairwise sums
		s01 := resize(a(0), 19) + resize(a(1), 19);
		s23 := resize(a(2), 19) + resize(a(3), 19);
		s45 := resize(a(4), 19) + resize(a(5), 19);
		s67 := resize(a(6), 19) + resize(a(7), 19);

		-- Intermediate sums
		s2345 := s23 + s45;
		s018 := s01 + s67;

	-- Final result
		result := s018 + s2345 + resize(a(8), 19);
		return result;
	end function;

	function sum_of_19x8(a : int27_vector) return int29 is
		 variable s01, s23, s45, s67 : int29;
		 variable s0123, s4567 : int29;
		 variable result : int29;
	begin
		 -- Pairwise sums
		 s01 := resize(a(0), 29) + resize(a(1), 29);
		 s23 := resize(a(2), 29) + resize(a(3), 29);
		 s45 := resize(a(4), 29) + resize(a(5), 29);
		 s67 := resize(a(6), 29) + resize(a(7), 29);

		 -- Intermediate tree
		 s0123 := s01 + s23;
		 s4567 := s45 + s67;

		 -- Final result
		 result := s0123 + s4567;
		 return result;
	end function;
	
	

	function Multi8x8(a, b: int8) return int18 is
		 variable result: signed(16 downto 0) := (others => '0');  -- 17 bits
		 variable abs_a: signed(8 downto 0);  -- 9 bits
		 variable abs_b: unsigned(8 downto 0);  -- 9 bits
		 variable sign_a, sign_b: std_logic;
		 variable sign_result: std_logic;
		 variable shifted_value: int17_vector(0 to 8);  -- 17 bits
		 variable final_result: int18;
	begin
		 -- Extract sign bits
		 sign_a := a(7);
		 sign_b := b(7);

		 -- Compute absolute values
		 if sign_a = '1' then
			  abs_a := resize(a, 9);     -- Extend `a` to 9 bits
			  abs_a := -abs_a;           -- Compute two's complement
		 else
			  abs_a := resize(a, 9);     -- Simply resize `a`
		 end if;

		 if sign_b = '1' then
			  abs_b := unsigned(resize(b, 9));  -- Extend `b` to 9 bits
			  abs_b := unsigned(-signed(abs_b)); -- Compute two's complement
		 else
			  abs_b := unsigned(resize(b, 9));   -- Simply resize `b`
		 end if;

		 -- Shift-and-add multiplication
		 for i in 0 to 8 loop
			  if abs_b(i) = '1' then
					-- Shift abs_a left by i bits
					shifted_value(i) := resize(abs_a, 17) sll i;
			  else
					shifted_value(i) := (others => '0');
			  end if;
		 end loop;

		 -- Sum the shifted values
		 result := (others => '0');
		 for i in 0 to 8 loop
			  result := result + shifted_value(i);
		 end loop;

		 -- Determine the sign of the result
		 if sign_a = sign_b then
			  sign_result := '0';  -- Positive
		 else
			  sign_result := '1';  -- Negative
		 end if;

		 -- Adjust the sign of the result
		 if sign_result = '1' then
			  final_result := resize(-result, INT18_WIDTH);  -- Ensure `final_result` is `int18`
		 else
			  final_result := resize(result, INT18_WIDTH);
		 end if;

		 return final_result;
		 
	end function;

	function Multi8x8_Hierarchical(a, b: int8) return int18 is
		variable abs_a, abs_b : unsigned(7 downto 0);
		variable sign_a, sign_b : std_logic;
		variable partial_results : int17_vector(0 to 7); -- To store partial multiplication results
		variable temp_results_1 : int18_vector(0 to 3);  -- Intermediate results (4)
		variable temp_results_2 : int18_vector(0 to 1);  -- Intermediate results (2)
		variable final_result : int18 := (others => '0');
		variable result : signed(17 downto 0) := (others => '0');
	begin
	-- Extract sign bits and compute absolute values
		sign_a := a(7);
		sign_b := b(7);
		abs_a := unsigned(a);
		abs_b := unsigned(b);

		-- Partial multiplications
		for i in 0 to 7 loop
		  if abs_a(i) = '1' then
				partial_results(i) := resize(signed(unsigned(abs_b) sll i),17);  -- Shifted partial products
		  else
				partial_results(i) := (others => '0');
		  end if;
		end loop;

		-- Step 1: Sum partial results into 4 intermediate results
		for i in 0 to 3 loop
		  temp_results_1(i) := resize(partial_results(2*i), 18) + resize(partial_results(2*i + 1), 18);
		end loop;

		-- Step 2: Sum 4 intermediate results into 2 results
		for i in 0 to 1 loop
		  temp_results_2(i) := temp_results_1(2*i) + temp_results_1(2*i + 1);
		end loop;

		-- Step 3: Sum 2 intermediate results into the final result
		final_result := temp_results_2(0) + temp_results_2(1);

		-- Adjust the sign of the result
		if sign_a = sign_b then
		  result := signed(final_result);
		else
		  result := -signed(final_result);
		end if;

		return result;
	end function;
		
end package body multiplier_pack;