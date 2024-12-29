library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use WORK.my_pack.ALL;

entity tb_MultiMultiplierEngine is
end tb_MultiMultiplierEngine;

architecture Behavioral of tb_MultiMultiplierEngine is
    -- Component Declaration for the Unit Under Test (UUT)
    component MultiMultiplierEngine
    Port (
      data_in : in conv_in_data;
      select_mode : in std_logic;
      clk_in : in std_logic;
      rst : in std_logic;
      output : out conv_out_data
    );
    end component;

    -- Signals to connect to UUT
    signal data_in_tb : conv_in_data := (others => '0');
    signal select_mode_tb : std_logic := '0';
    signal clk_in_tb : std_logic := '0';
    signal rst_tb : std_logic := '0';
    signal output_tb : conv_out_data;
    signal conv_weight1, conv_weight2, conv_weight1_t, conv_weight2_t : conv_weight;
    signal pixel_in, pixel_in_t : conv_pixel;
    signal Connect_data_in, Connect_data_in_t : fullConnect_data;
    signal Connect_weight_in, Connect_weight_in_t : fullConnect_weight;
    signal output_int19_left, output_int19_right,output_int19_left_t, output_int19_right_t : int19;
    signal output_int29,output_int29_t : int29;
    -- Clock period definition
    constant clk_period : time := 10 ns;

begin
    -- Instantiate the Unit Under Test (UUT)
    uut: MultiMultiplierEngine Port Map (
        data_in => data_in_tb,
        select_mode => select_mode_tb,
        clk_in => clk_in_tb,
        rst => rst_tb,
        output => output_tb
    );
    
    output_int19_left <= conv_out_data_to_two_int19(output_tb)(0);
    output_int19_right <= conv_out_data_to_two_int19(output_tb)(1);
    output_int29 <= conv_out_data_to_int29(output_tb);
	 output_int19_left_t<=sum_9x8_products(pixel_in,conv_weight1);
    output_int19_right_t<=sum_9x8_products(pixel_in,conv_weight2);
	 output_int29_t<=sum_8x19_products(Connect_data_in,Connect_weight_in);
    -- Clock process definitions
    clk_process : process
    begin
        clk_in_tb <= '0';
        wait for clk_period / 2;
        clk_in_tb <= '1';
        wait for clk_period / 2;
    end process clk_process;

    -- Stimulus process
    stim_proc: process
    begin
        -- Initialize Inputs
        rst_tb <= '1';
        wait for clk_period * 2;
        rst_tb <= '0';

        -- Test Case 1: Conv Mode
        pixel_in <= create_int8_vector_9(127, 127, 127, 127, 127, 127, 127, 127, 127);
        conv_weight1 <= create_int8_vector_9(127, 127, 127, 127, 127, 127, 127, 127, 127);
        conv_weight2 <= create_int8_vector_9(-128, -128, -128, -128, -128, -128, -128, -128, -128);
        select_mode_tb <= '0';
        wait for 1 ns;
        data_in_tb <= combine_conv_data(pixel_in, conv_weight1, conv_weight2);
        wait for 1 ns;
        pixel_in_t <= extract_conv_pixel(data_in_tb);
        conv_weight1_t <= extract_conv_weight_1(data_in_tb);
        conv_weight2_t <= extract_conv_weight_2(data_in_tb);
		  wait for clk_period;
		   -- Check expected result
        assert output_int19_left = output_int19_left_t or output_int19_right = output_int19_right_t;
            report "Test Case 1 Failed"
            severity error;
        wait for clk_period * 5;

        -- Test Case 2: Conv Mode
        pixel_in <= create_int8_vector_9(-128, -128, -128, -128, -128, -128, -128, -128, -128);
        conv_weight1 <= create_int8_vector_9(-128, -128, -128, -128, -128, -128, -128, -128, -128);
        conv_weight2 <= create_int8_vector_9(127, 127, 127, 127, 127, 127, 127, 127, 127);
        select_mode_tb <= '0';
        wait for 1 ns;
        data_in_tb <= combine_conv_data(pixel_in, conv_weight1, conv_weight2);
        wait for 1 ns;
        pixel_in_t <= extract_conv_pixel(data_in_tb);
        conv_weight1_t <= extract_conv_weight_1(data_in_tb);
        conv_weight2_t <= extract_conv_weight_2(data_in_tb);
		  wait for clk_period;
		   -- Check expected result
        assert output_int19_left = output_int19_left_t or output_int19_right = output_int19_right_t;
            report "Test Case 1 Failed"
            severity error;
        wait for clk_period * 5;

        -- Test Case 2: Fully Connected Mode
        Connect_data_in <= create_int19_vector_8((2**17)-1,(2**17)-1, (2**17)-1,(2**17)-1,2**17-1,(2**17)-1, (2**17)-1,(2**17)-1);
        Connect_weight_in <= create_int8_vector_8(-128, -128, -128, -128, -128, -128, -128, -128);
        select_mode_tb <= '1';
        wait for 1 ns;
        data_in_tb <= combine_fullConnect_data(Connect_data_in, Connect_weight_in);
        wait for 1 ns;
        Connect_weight_in_t <= extract_fullConnect_weight(data_in_tb);
        Connect_data_in_t <= extract_fullConnect_data(data_in_tb);
		  wait for clk_period;
		  
        -- Check expected result
        assert output_int29 = output_int29_t;
            report "Test Case 2 Failed"
            severity error;
        wait for clk_period * 5;
        -- Additional Test Case 4 
        Connect_data_in <= create_int19_vector_8((2**17)-1,(2**17)-1, (2**17)-1,(2**17)-1,2**17-1,(2**17)-1, (2**17)-1,(2**17)-1);
        Connect_weight_in <= create_int8_vector_8(127, 127, 127, 127, 127, 127, 127, 127);
        select_mode_tb <= '1';

        wait for 1 ns;
        data_in_tb <= combine_fullConnect_data(Connect_data_in, Connect_weight_in);
        wait for 1 ns;
        Connect_weight_in_t <= extract_fullConnect_weight(data_in_tb);
        Connect_data_in_t <= extract_fullConnect_data(data_in_tb);
		  wait for clk_period;
		  
        -- Check expected result
        assert output_int29 = output_int29_t;
            report "Test Case 4 Failed"
            severity error;
        wait for clk_period * 5;
			        -- Additional Test Case 4 
        Connect_data_in <= create_int19_vector_8(-(2**18),-(2**18), -(2**18), -(2**18), -(2**18), -(2**18), -(2**18), -(2**18));
        Connect_weight_in <= create_int8_vector_8(127, 127, 127, 127, 127, 127, 127, 127);
        select_mode_tb <= '1';

        wait for 1 ns;
        data_in_tb <= combine_fullConnect_data(Connect_data_in, Connect_weight_in);
        wait for 1 ns;
        Connect_weight_in_t <= extract_fullConnect_weight(data_in_tb);
        Connect_data_in_t <= extract_fullConnect_data(data_in_tb);
		  wait for clk_period;
		  
        -- Check expected result
        assert output_int29 = output_int29_t;
            report "Test Case 4 Failed"
            severity error;
        wait for clk_period * 5;
		          Connect_data_in <= create_int19_vector_8(-12, 30, -77, 44, -23, -56, 99,5);
        Connect_weight_in <= create_int8_vector_8(0, 1, 2, 4, 8, 16, 32, 64);
        select_mode_tb <= '1';

        wait for 1 ns;
        data_in_tb <= combine_fullConnect_data(Connect_data_in, Connect_weight_in);
        wait for 1 ns;
        Connect_weight_in_t <= extract_fullConnect_weight(data_in_tb);
        Connect_data_in_t <= extract_fullConnect_data(data_in_tb);
		  wait for clk_period;
		  
        -- Check expected result
        assert output_int29 = output_int29_t;
            report "Test Case 4 Failed"
            severity error;
        wait for clk_period * 5;
		          Connect_data_in <= create_int19_vector_8(-12243,241, -(2**18), 1243,0, 11, -(2**18), 123);
        Connect_weight_in <= create_int8_vector_8(127, -12, 0, 21, -90, 17, 27, 7);
        select_mode_tb <= '1';

        wait for 1 ns;
        data_in_tb <= combine_fullConnect_data(Connect_data_in, Connect_weight_in);
        wait for 1 ns;
        Connect_weight_in_t <= extract_fullConnect_weight(data_in_tb);
        Connect_data_in_t <= extract_fullConnect_data(data_in_tb);
		  wait for clk_period;
		  
        -- Check expected result
        assert output_int29 = output_int29_t;
            report "Test Case 4 Failed"
            severity error;
        wait for clk_period * 5;
		  -- Test Case: Conv Mode with Maximum and Minimum Values
			pixel_in <= create_int8_vector_9(127, -128, 127, -128, 127, -128, 127, -128, 127);
			conv_weight1 <= create_int8_vector_9(127, -128, 127, -128, 127, -128, 127, -128, 127);
			conv_weight2 <= create_int8_vector_9(127, -128, 127, -128, 127, -128, 127, -128, 127);
			select_mode_tb <= '0';
			wait for 1 ns;
			data_in_tb <= combine_conv_data(pixel_in, conv_weight1, conv_weight2);
			wait for 1 ns;
			pixel_in_t <= extract_conv_pixel(data_in_tb);
			conv_weight1_t <= extract_conv_weight_1(data_in_tb);
			conv_weight2_t <= extract_conv_weight_2(data_in_tb);
			wait for clk_period;

			-- Check expected result
			assert output_int19_left = output_int19_left_t or output_int19_right = output_int19_right_t
				 report "Test Case: Boundary Values Failed"
				 severity error;
			wait for clk_period * 5;
			-- Test Case: Conv Mode with Intermediate Values
			pixel_in <= create_int8_vector_9(64, 32, 16, 8, 4, 2, 1, 0, -1);
			conv_weight1 <= create_int8_vector_9(-1, 0, 1, 2, 4, 8, 16, 32, 64);
			conv_weight2 <= create_int8_vector_9(1, -1, 0, 1, -1, 0, 1, -1, 0);
			select_mode_tb <= '0';
			wait for 1 ns;
			data_in_tb <= combine_conv_data(pixel_in, conv_weight1, conv_weight2);
			wait for 1 ns;
			pixel_in_t <= extract_conv_pixel(data_in_tb);
			conv_weight1_t <= extract_conv_weight_1(data_in_tb);
			conv_weight2_t <= extract_conv_weight_2(data_in_tb);
			wait for clk_period;

			-- Check expected result
			assert output_int19_left = output_int19_left_t or output_int19_right = output_int19_right_t
				 report "Test Case: Intermediate Values Failed"
				 severity error;
			wait for clk_period * 5;

			-- Test Case: Random Values for Conv Mode
			pixel_in <= create_int8_vector_9(12, -30, 77, -44, 23, 56, -99, 88, 67);
			conv_weight1 <= create_int8_vector_9(-12, 30, -77, 44, -23, -56, 99, -88, -67);
			conv_weight2 <= create_int8_vector_9(34, -78, 45, -12, 5, -43, 21, 76, -99);
			select_mode_tb <= '0';
			wait for 1 ns;
			data_in_tb <= combine_conv_data(pixel_in, conv_weight1, conv_weight2);
			wait for 1 ns;
			pixel_in_t <= extract_conv_pixel(data_in_tb);
			conv_weight1_t <= extract_conv_weight_1(data_in_tb);
			conv_weight2_t <= extract_conv_weight_2(data_in_tb);
			wait for clk_period;

			-- Check expected result
			assert output_int19_left = output_int19_left_t or output_int19_right = output_int19_right_t
				 report "Test Case: Random Values Failed"
				 severity error;
			wait for clk_period * 5;

        -- Add more test cases and expected value checks as needed

        wait;
    end process stim_proc;

end Behavioral;
