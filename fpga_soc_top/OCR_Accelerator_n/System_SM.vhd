library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use WORK.data_pack.ALL;


entity System_SM is
	GENERIC (
		MAX_out_L : integer := 10;
		MAX_IMAGE_W : integer:=400;
		T_RAM : integer :=1;
		T_winner : integer :=1;
		total_filters : integer := 64
	);
	port(
		clk_in,rst_n,image_load,winner,at_final_line,CU_rst : in std_logic;
		S_RST,
		Select_mode,
		Set_BSC,
		next_fc,
		Check_winner,
		Done,
		Start_load_data,
		LL_read,
		Relu_WR_EN,
		EN_pixel_reg,
		is_idle,
		En_shift_result : out std_logic
		);
end System_SM;

ARCHITECTURE arch_System_SM OF System_SM IS
	constant k : integer :=total_filters/2;
	type system_state is (idle,Load_data,LL_wait,Loaded_line,LNL,COV2D_prep,COV2D_prep_LL_FLAG,COV2D_prep_LL,RUN_CONV2D,First_FC,FC_P1,FC_P2,FC_P3,FC_P3_LK,Next_Class,Check_winner_state,wait_winner,Task_complate,error);
	signal corrent_state, next_state : system_state;
	signal Count_load_Wait,Count_load_Wait_t : integer range 0 to T_RAM+1;
	signal count_k,count_k_t : integer range 0 to k+1;
	signal class_count,class_count_t : integer range 0 to N+1;
	signal Count_winner,Count_winner_t : integer range 0 to T_find_winner+1;
	
	
	signal 
		Select_mode_t,
		Set_BSC_t,
		next_fc_t,
		Check_winner_t,
		Done_t,
		Start_load_data_t,
		LL_read_t,
		Relu_WR_EN_t,
		En_shift_result_t,LL_read_EN,LL_flag,LL_flag_t,FL_load_t,FL_load,LL_read_reg : std_logic;
	
begin
	
	LL_read<= LL_read_reg;
	process(clk_in,rst_n)
	begin
		if(rst_n='0') then
			corrent_state<=idle;
			Count_load_Wait<=0;
			Count_winner<=0;
			class_count<=0;
			FL_load<='0';
			LL_flag<='0';
			LL_read_reg<='0';
			count_k<=0;
		elsif(rising_edge(clk_in)) then
			corrent_state<=next_state;
			Count_winner<=Count_winner_t;
			Count_load_Wait<=Count_load_Wait_t;
			class_count<=class_count_t;
			count_k<=count_k_t;
			LL_flag<=LL_flag_t;
			FL_load<=FL_load_t;
			if(CU_rst='1') then
				corrent_state<=idle;
			end if;
			if(corrent_state=idle) then 
				LL_read_reg<='0';
			elsif(LL_read_EN='1') then 
				LL_read_reg<=LL_flag;
			end if;
			
		end if;
	end process;
	
	S_rst<='1' when corrent_state=idle else winner;
	process(Count_load_Wait,image_load,corrent_state,Count_winner,class_count,winner,at_final_line,FL_load,count_k,LL_flag,LL_read_reg)
	begin
		is_idle<='0';
		Select_mode<='0';
		Set_BSC<='0';
		LL_read_EN<='0';
		next_fc<='0';
		Check_winner<='0';
		Done<='0';
		Start_load_data<='0';
		Relu_WR_EN<='0';
		En_shift_result<='0';
		Set_BSC<='0';
		FL_load_t<=FL_load;
		LL_flag_t<=LL_flag;
		Check_winner<='0';
		EN_pixel_reg<='0';
		Count_winner_t<=0;
		count_k_t<=count_k;
		Count_load_Wait_t<=Count_load_wait;
		next_state<=corrent_state; 
		class_count_t<=class_count;
		case corrent_state is
			when idle =>
				is_idle<='1';
				FL_load_t<='0';
				LL_flag_t<='0';
				if(image_load='1') then
					next_state<=Load_data;
				end if;

			when Load_data =>
				Count_load_wait_t<=0;
				Start_load_data<='1';
				next_state<=LL_wait;
			when LL_wait =>
				Count_load_wait_t<=Count_load_wait+1;
				if(T_RAM = Count_load_wait) then
					next_state<=LNL;
				end if;

			when Loaded_line =>
				Count_load_wait_t<=0;
				
				count_k_t<=1;
				
				if(LL_flag='1') then
					next_state<=COV2D_prep_LL;
				else
					if(at_final_line='1') then
						next_state<=COV2D_prep_LL_FLAG;
					else
						next_state<=COV2D_prep;
					end if;
				end if;
			when LNL =>
				--EN_pixel_reg<='1';
				Count_load_wait_t<=0;
				
				count_k_t<=1;
				
				if(LL_flag='1') then
					next_state<=COV2D_prep_LL;
				else
					if(at_final_line='1') then
						next_state<=COV2D_prep_LL_FLAG;
					else
						next_state<=COV2D_prep;
					end if;
				end if;
			when COV2D_prep =>
				count_k_t<=1;
				next_state<=RUN_CONV2D;
			when COV2D_prep_LL_FLAG =>
				count_k_t<=1;
				next_state<=RUN_CONV2D;
				LL_flag_t<='1';
			when COV2D_prep_LL =>
				count_k_t<=1;
				next_state<=RUN_CONV2D;
				LL_read_EN<='1';

			when RUN_CONV2D =>
				count_k_t<=count_k+1;
				Relu_WR_EN<='1';
				if(count_k=k)then
					next_state<=FIrst_FC;
				end if;

			when First_FC =>
				EN_pixel_reg<='1';
				next_state<=FC_P2;
				Select_mode<='1';
				next_fc<='1';
				count_k_t<=1;
				class_count_t<=1;
				Set_BSC<='1';

			when FC_P1 =>
				Select_mode<='1';
				next_state<=FC_P2;
				Set_BSC<='1';

			when FC_P2 =>
				Select_mode<='1';
				next_state<=FC_P3;
				if(count_k=k)then
					next_state<=FC_P3_LK;
				else
					next_state<=FC_P3;
				end if;
			
			
			when FC_P3 =>
				Select_mode<='1';
				count_k_t<=count_k+1;
				next_state<=FC_P1;
				
			when FC_P3_LK=>
				Select_mode<='1';

				if(class_count=N) then
						next_state<=Check_winner_state;
					else
						next_state<=Next_Class;
				end if;

			when Next_Class =>
				En_shift_result<='1';
				Set_BSC<='1';
				next_fc<='1';
				next_state<=FC_P2;
				Select_mode<='1';
				count_k_t<=1;
				class_count_t<=class_count+1;
				
			when Check_winner_state =>
				En_shift_result<='1';
				Check_winner<='1';
				Count_winner_t<=0;
				next_state<=wait_winner;

			when wait_winner =>
				Count_winner_t<=count_winner+1;
				if(Count_winner=T_winner) then
					if(winner='1') then
						if(at_final_line='1') then
							next_state<=Task_complate;
						else
							next_state<=LL_wait;
						end if;
					else
						if(LL_read_reg='1') then
								next_state<=Task_complate;
							else
								next_state<=Loaded_line;
						end if;
					end if;
				end if;

			when Task_complate =>
				Done<='1';
				next_state<=idle;

			when others =>
				  next_state<=error;

		end case;
	end process;
	
end ARCHITECTURE arch_System_SM;