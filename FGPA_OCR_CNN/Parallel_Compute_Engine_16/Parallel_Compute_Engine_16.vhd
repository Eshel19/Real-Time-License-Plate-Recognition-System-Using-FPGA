library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use WORK.multiplier_pack.ALL;
use WORK.data_pack.ALL;
use WORK.Parallel_Compute_Engine_16_pack.ALL;


entity Parallel_Compute_Engine_16 is
	GENERIC (
	Num_of_units : integer := 16;
	bais_bus_w : integer := INT45_WIDTH
	);
    Port (
		data_in : in conv_in_data_vector(Num_of_units-1 downto 0);
		select_mode: in std_logic;
		clk_in, rst : in std_logic;
		bais_in : in std_logic_vector(bais_bus_w-1 downto 0);
		output : out std_logic_vector(conv_data_out_size*Num_of_units-1 downto 0)
	);
end Parallel_Compute_Engine_16;

architecture arch_Parallel_Compute_Engine_16 of Parallel_Compute_Engine_16 is

	signal Multi_result : conv_out_data_vector(Num_of_units-1 downto 0);
	signal select_mode_1,select_mode_2 : std_logic;
	signal bais_signed,bais_reg: int45;
	signal bais_L,bais_R : int8;
	signal data_out_L,data_out_R : int19_vector(Num_of_units-1 downto 0);
	signal data_out_29bit : int29_vector(Num_of_units-1 downto 0);
	signal sum_result_int45: int45;
	signal sum_result_L,sum_result_R : int19_vector(Num_of_units-1 downto 0);
	signal output_t,output_t_2 : std_logic_vector(conv_data_out_size*Num_of_units-1 downto 0);
	signal output_R45_M0,output_R45_M1 : std_logic_vector(bais_bus_w-1 downto 0);
	
	
	component MultiMultiplierEngine IS
		Port (
			data_in : in conv_in_data;
			select_mode: in std_logic;
			clk_in, rst : in std_logic;
			output : out conv_out_data
		);
	END component MultiMultiplierEngine;
begin

	data_out_L<=split_L_result(Multi_result);
	data_out_R<=split_R_result(Multi_result);
	
	data_out_29bit<=split_result(Multi_result);
	
	sum_result_L<=add_bais_N_results(data_out_L,bais_L);
	sum_result_R<=add_bais_N_results(data_out_R,bais_R);
	
	sum_result_int45<=bais_reg+hierarchical_sum(data_out_29bit);
	
	output_t<= int19_vector_to_slv(full_relu_int19(sum_result_L))&int19_vector_to_slv(full_relu_int19(sum_result_R));
	
	output_R45_M0<=output_t(bais_bus_w-1 downto 0);
	output_R45_M1<=std_logic_vector(sum_result_int45);
	
	output(conv_data_out_size*Num_of_units-1 downto bais_bus_w)<=output_t(conv_data_out_size*Num_of_units-1 downto bais_bus_w);
	
	output(bais_bus_w-1 downto 0)<=output_R45_M1 when select_mode_1='1' else output_R45_M0;
	
	bais_L<=bais_reg(15 downto 8);
	bais_R<=bais_reg(7 downto 0);
		
	
	MultiMultiplierEngineX16: for i in Num_of_units-1 downto 0 GENERATE
		Multi_unit:MultiMultiplierEngine
		port map(
			data_in=>data_in(i),
			select_mode=>select_mode,
			clk_in=>clk_in, 
			rst=>rst,
			output=>Multi_result(i)
		);
	end GENERATE MultiMultiplierEngineX16;
	
	
	
	process(clk_in,rst)
		
	begin
		if(rst='1') then
			select_mode_1<='0';
			select_mode_2<='0';
			bais_reg<=(others=>'0');
		elsif(rising_edge(clk_in)) then
			select_mode_1<=select_mode;
			select_mode_2<=select_mode_1;
			if((select_mode_1 and select_mode_2)='1') then
				bais_reg<=sum_result_int45;
			else
				bais_reg<=signed(bais_in);
			end if;
		end if;
	end process;

end architecture arch_Parallel_Compute_Engine_16;