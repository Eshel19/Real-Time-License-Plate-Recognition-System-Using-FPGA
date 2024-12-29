library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use WORK.data_pack.ALL;
use WORK.rc_pack.ALL;

entity Results_comparator is
    Port (
        data_in : in int45;
        clk_in, rst,check_winner,Shift_EN : in std_logic;
        output : out uint64;
		  winner_output: out std_logic
    );
end Results_comparator;


ARCHITECTURE arch_Results_comparator OF Results_comparator IS

	signal model_reg_arr	: Model_regArray(0 to N - 1);
	signal thre_reg_arr : int45_vector(0 to N - 1);
	signal check_winner_1 :std_logic;
	signal correct_max: int45:=(others=>'0');
	signal DEF_NO_WINNER_sig : unsigned(WIDTH_Model_reg downto 0);
	signal connect_max_model: unsigned(WIDTH_Model_reg downto 0);
	signal result : uint64;
	signal correct_is_winner: std_logic;
	signal Shift_EN_1 :std_logic;
	signal result_time10_t: uint64;

BEGIN
	DEF_NO_WINNER_sig<=DEF_NO_WINNER;
	correct_is_winner<= '1' when (not (connect_max_model=DEF_NO_WINNER_sig) and check_winner='1') else '0';
--	winner_output<=correct_is_winner;
	
	process(clk_in,rst)
		variable NewGreater: std_logic;
		variable result_time10: uint64;
	begin
		if(rst='1') then
			for i in 0 to N - 1 loop
				model_reg_arr(i)<=to_unsigned(i,WIDTH_Model_reg+1);
			end loop;
			
			thre_reg_arr<=threshold_arr;
			correct_max<=to_signed(1,INT45_WIDTH);
			connect_max_model<=DEF_NO_WINNER;
			result<=(others=>'0');
			check_winner_1<='0';
			Shift_EN_1<='0';
			winner_output<='0';
		elsif(rising_edge(clk_in)) then
			Shift_EN_1<=Shift_EN;
			check_winner_1<=check_winner;
			winner_output<=correct_is_winner;
			if(check_winner_1='1') then
				for i in 0 to N - 1 loop
					model_reg_arr(i)<=to_unsigned(i,WIDTH_Model_reg+1);
				end loop;
				thre_reg_arr<=threshold_arr;
				correct_max<=to_signed(1,INT45_WIDTH);
				connect_max_model<=DEF_NO_WINNER;
			else
				if(Shift_EN_1='1') then
					model_reg_arr<=model_reg_arr(1 to N-1) & model_reg_arr(0);
					thre_reg_arr<=thre_reg_arr(1 to N-1) & thre_reg_arr(0);
				end if;
				if(Shift_EN='1') then
					if(((thre_reg_arr(0)<data_in) and (correct_max<data_in))) then 
						NewGreater:='1';
					else
						NewGreater:='0';
					end if;
					
					if(NewGreater='1') then
						correct_max<=data_in;
						connect_max_model<=model_reg_arr(0);
					else
						correct_max<=correct_max;
						connect_max_model<=connect_max_model;
					end if;
				end if;
				
			end if;
			result_time10:=MultiByTenADD(result,resize(connect_max_model,INT64_WIDTH));
			result_time10_t<=result_time10;
			if(correct_is_winner='1') then
				result<=result_time10;
			else 
				result<=result;
			end if;
		end if;
	end process;
	output<=result;
end arch_Results_comparator;