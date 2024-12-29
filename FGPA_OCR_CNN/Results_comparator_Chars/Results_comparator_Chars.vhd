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
        clk_in, rst,check_winner,Shift_EN : in std_logic;
        output : out char_vector(0 to MAX_out_L-1);
		  winner_output: out std_logic
    );
end Results_comparator_Chars;


ARCHITECTURE arch_Results_comparator_Chars OF Results_comparator_Chars IS

	signal model_reg_arr	:char_vector(0 to N - 1);
	signal thre_reg_arr : int45_vector(0 to N - 1);
	signal check_winner_1 :std_logic;
	signal correct_max: int45:=(others=>'0');
	signal DEF_NO_WINNER_sig : char;
	signal connect_max_model: char;
	signal result : char_vector(0 to MAX_out_L-1);
	signal correct_is_winner: std_logic;
	signal Shift_EN_1 :std_logic;
	signal result_time10_t: uint64;

BEGIN
	DEF_NO_WINNER_sig<=DEF_NO_WINNER;
	correct_is_winner<= '1' when (not (connect_max_model=DEF_NO_WINNER_sig) and check_winner='1') else '0';
	
	process(clk_in,rst)
		variable NewGreater: std_logic;
		variable result_time10: uint64;
	begin
		if(rst='1') then
			model_reg_arr<=Model_outputs_chars;
			thre_reg_arr<=threshold_arr;
			correct_max<=to_signed(1,INT45_WIDTH);
			connect_max_model<=DEF_NO_WINNER;
			for i in 0 to MAX_out_L-1 loop
				result(i)<=0;
			end loop;
			check_winner_1<='0';
			Shift_EN_1<='0';
			winner_output<='0';
		elsif(rising_edge(clk_in)) then
			Shift_EN_1<=Shift_EN;
			check_winner_1<=check_winner;
			winner_output<=correct_is_winner;
			if(Shift_EN_1='1') then
				model_reg_arr<=model_reg_arr(1 to N-1) & model_reg_arr(0);
				thre_reg_arr<=thre_reg_arr(1 to N-1) & thre_reg_arr(0);
			end if;
			if(check_winner_1='1') then
--				model_reg_arr<=Model_outputs_chars;
--				thre_reg_arr<=threshold_arr;
				correct_max<=to_signed(1,INT45_WIDTH);
				connect_max_model<=DEF_NO_WINNER;
			else
			if(((thre_reg_arr(0)<data_in) and (correct_max<data_in))) then 
				NewGreater:='1';
			else
				NewGreater:='0';
			end if;
				if(Shift_EN='1') then
					if(NewGreater='1') then
						correct_max<=data_in;
						connect_max_model<=model_reg_arr(0);
--					else
--						correct_max<=correct_max;
--						connect_max_model<=connect_max_model;
					end if;
				end if;
				
			end if;
--			result_time10:=MultiByTenADD(result,resize(connect_max_model,INT64_WIDTH));
--			result_time10_t<=result_time10;
			if(correct_is_winner='1') then
				result<=result(1 to N-1) & connect_max_model;
			else 
				result<=result;
			end if;
		end if;
	end process;
	output<=result;
end arch_Results_comparator_Chars;