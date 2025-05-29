library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use WORK.multiplier_pack.ALL;
use WORK.data_pack.ALL;


entity MultiMultiplierEngine is
    Port (
        data_in : in conv_in_data;
        select_mode: in std_logic;
        clk_in, rst_n : in std_logic;
        output : out conv_out_data
    );
end MultiMultiplierEngine;

architecture rtl of MultiMultiplierEngine is
    signal Result_a_9x9_DSP  : Result_9x9_DSP;
	 signal Result_b_9x9_ALM : result_9x9_ALM;
    signal Result_c_19x8 : Result_19x8;
	 signal select_mode_tmp : std_logic;
	 signal w1_sum, w2_sum : int19 := (others => '0');
	 signal Result_19x8_sum : int29;
	 signal output_t,output_final : conv_out_data;
	 signal output_l, output_r : std_logic_vector(0 to 18);

begin
	process(clk_in,rst_n)
		variable data : multiplier_inputs_t;
		variable output_mode_1, output_mode_0, output_t : conv_out_data;

	begin
		if rst_n = '0' then
			select_mode_tmp<='0';
			for i in 0 to Result_a_9x9_DSP'length -1 loop
				Result_a_9x9_DSP(i) <=(others => '0');
			end loop;
			for i in 0 to Result_b_9x9_ALM'length-1 loop
				Result_b_9x9_ALM(i) <=(others => '0');
			end loop;
			for i in 0 to Result_c_19x8'length-1 loop
				Result_c_19x8(i) <=(others => '0');
			end loop;
			--Result_19x8_sum<=(others=>'0');
			--w2_sum<=(others=>'0');
		elsif rising_edge(clk_in) then
			data := generate_multiplier_inputs(data_in, select_mode);
			Result_a_9x9_DSP <= Full_matrix_multi_8x8_DSP(data.A_8x8_DSP, data.B_8x8_DSP);
			Result_b_9x9_ALM <= Full_matrix_multi_8x8_ALM(data.A_8x8_ALM, data.B_8x8_ALM);
			--w2_sum<=sum_of_9x9(Full_matrix_multi_8x8_DSP(data.A_8x8_DSP, data.B_8x8_DSP));
			Result_c_19x8 <= Full_matrix_multi_19x8(data.A_19X8_19, data.B_19X8_8);
			--Result_19x8_sum<=sum_of_19x8(Full_matrix_multi_19x8(data.A_19X8_19, data.B_19X8_8));
			select_mode_tmp<=select_mode;

		end if;

		
	end process;
		w1_sum<=resize(Result_b_9x9_ALM(0),19) when select_mode_tmp = '0' else (others => '0');
		--w1_sum<=resize(Result_b_9x9_ALM(0),19);
		w2_sum<=sum_of_9x9(Result_a_9x9_DSP);
		Result_19x8_sum<=sum_of_19x8(Result_c_19x8);
		output_t <= int29_to_conv_out_data(w1_sum + Result_19x8_sum);-- when select_mode_tmp = '0' else int29_to_conv_out_data(Result_19x8_sum);
		output_final(18 downto 0)<=output_t(18 downto 0);
		output_final(37 downto 19)<=output_t(37 downto 19) when select_mode_tmp = '1' else std_logic_vector(w2_sum);
		output <=output_final;
end architecture;
