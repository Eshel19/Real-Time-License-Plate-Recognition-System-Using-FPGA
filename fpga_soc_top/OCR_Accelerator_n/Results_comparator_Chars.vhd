library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use WORK.data_pack.ALL;
use WORK.rc_pack.ALL;

entity Results_comparator_Chars is
GENERIC (
	MAX_out_L : integer := 10
	);
    Port (
        data_in : in int45;
        clk_in, rst_n,check_winner,Shift_EN,is_idle : in std_logic;
        output : out char_vector(MAX_out_L-1 downto 0);
		  winner_output: out std_logic;
		  dig_detect_count : out unsigned(7 downto 0)
    );
end Results_comparator_Chars;


ARCHITECTURE arch_Results_comparator_Chars OF Results_comparator_Chars IS

	signal model_reg_arr	:char_vector(0 to N - 1);
	signal thre_reg_arr : int45_vector(0 to N - 1);
	signal check_winner_1,check_winner_2 :std_logic;
	signal correct_max: int45:=(others=>'0');
	signal DEF_NO_WINNER_sig : char;
	signal correct_max_model: char;
	signal result : char_vector(MAX_out_L-1 downto 0);
	signal correct_is_winner: std_logic;
	signal Shift_EN_1,Shift_EN_2 :std_logic;
	signal data_in_reg : int45;
	signal NewGreater: std_logic;
	signal dig_detect_count_reg : unsigned(7 downto 0);
BEGIN
	correct_is_winner<= '1' when (not (correct_max_model=DEF_NO_WINNER)) else '0';
	NewGreater<= '1' when (thre_reg_arr(0)<data_in_reg and correct_max<data_in_reg) else '0';
	dig_detect_count<=dig_detect_count_reg;
	process(clk_in,rst_n)
		--variable NewGreater: std_logic;
		variable result_time10: uint64;
	begin
		if(rst_n='0') then
			check_winner_2<='0';
			model_reg_arr<=Model_outputs_chars;
			thre_reg_arr<=threshold_arr;
			correct_max<=to_signed(1,INT45_WIDTH);
			correct_max_model<=DEF_NO_WINNER;
			data_in_reg<=(others=>'0');
			for i in MAX_out_L-1 downto 0 loop
				result(i)<=0;
			end loop;
			dig_detect_count_reg<=to_unsigned(0,INT8_WIDTH);
			check_winner_1<='0';
			Shift_EN_1<='0';
			Shift_EN_2<='0';
			winner_output<='0';
		elsif(rising_edge(clk_in)) then
			Shift_EN_1<=Shift_EN;
			Shift_EN_2<=Shift_EN_1;
			check_winner_1<=check_winner;
			check_winner_2<=check_winner_1;
			if(Shift_EN_1='1') then
				if(NewGreater='1') then
					correct_max<=data_in_reg;
					correct_max_model<=model_reg_arr(0);
				end if;

			end if;
			if(Shift_EN_2='1') then
				model_reg_arr<=model_reg_arr(1 to N-1) & model_reg_arr(0);
				thre_reg_arr<=thre_reg_arr(1 to N-1) & thre_reg_arr(0);
			end if;
			if(check_winner_2='1') then
				winner_output<=correct_is_winner;
				if(correct_is_winner='1') then
					result<=result(MAX_out_L-2 downto 0) & correct_max_model;
					dig_detect_count_reg<=dig_detect_count_reg+1;
				end if;
				correct_max<=MIN_INT45;
				correct_max_model<=DEF_NO_WINNER;
			else 
				winner_output<='0';
			end if;
			if(Shift_EN='1') then
				data_in_reg<=data_in;
			end if;
			
			if(is_idle='1') then
				check_winner_2<='0';
				model_reg_arr<=Model_outputs_chars;
				thre_reg_arr<=threshold_arr;
				correct_max<=to_signed(1,INT45_WIDTH);
				correct_max_model<=DEF_NO_WINNER;
				data_in_reg<=(others=>'0');
				for i in MAX_out_L-1 downto 0 loop
					result(i)<=0;
				end loop;
				dig_detect_count_reg<=to_unsigned(0,INT8_WIDTH);
				check_winner_1<='0';
				Shift_EN_1<='0';
				Shift_EN_2<='0';
				winner_output<='0';
			end if;
		end if;
	end process;
	output<=result;
end arch_Results_comparator_Chars;