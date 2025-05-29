library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Include custom packages
use WORK.data_pack.ALL;
use WORK.dmu_pack.ALL;
use WORK.mem_pack.ALL;

entity data_managment_unit is
	GENERIC (
		Num_of_units : integer := 16;
		Size_of_FC_vec : integer := pic_height*sub_pic_w;
		PIXEL_DEF_VALUE : integer := 127;
		bais_bus_w : integer := INT45_WIDTH
	);
	port(
		pixel_in : in std_logic_vector(pic_height*INT8_WIDTH-1 downto 0);
		WFC_MEM_q : in std_logic_vector(WFC_info.DATA_WIDTH-1 downto 0);
		BFC_MEM_q : in std_logic_vector(BFC_info.DATA_WIDTH-1 downto 0);
		Conv_W_MEM_q : in std_logic_vector(CONV_W_info.DATA_WIDTH-1 downto 0);
		Conv_B_MEM_q : in std_logic_vector(CONV_B_info.DATA_WIDTH-1 downto 0);
		Relu_data_Q : in std_logic_vector(relu_out_info.DATA_WIDTH-1 downto 0);
		Relu_data_in : out std_logic_vector(relu_out_info.DATA_WIDTH-1 downto 0);
		Model_result : out int45;
		Multi_data_in : out conv_in_data_vector(Num_of_units-1 downto 0);
		Multi_bais_in : out std_logic_vector(bais_bus_w-1 downto 0);
		Multi_data_out : in std_logic_vector(conv_data_out_size*Num_of_units-1 downto 0);
		Select_mode,Set_BSC,rst_n,clk_in,EN_pixel_reg,LL_read,S_rst: in std_logic
		
	);
	
end entity data_managment_unit;


architecture arch_data_managment_unit of data_managment_unit is
	signal pixel_buffer_1,pixel_in_1,pixel_buffer_2,pixel_buffer_3 : int8_vector(pic_height-1 downto 0);
	constant pad_bais : std_logic_vector(BFC_info.DATA_WIDTH-CONV_B_info.DATA_WIDTH-1 downto 0):=(others=>'0');
	signal Multi_data_out_reg :  std_logic_vector(conv_data_out_size*Num_of_units-1 downto 0);
	signal pixel_groups : int8_vector_9ele_array(pic_height - 1 downto 0);
	signal input_mode_0,input_mode_1 :  conv_in_data_vector(Num_of_units-1 downto 0);
	signal Relu_data_Q_t,FC_FULL : int19_vector((Relu_data_Q'length/INT19_WIDTH)-1 downto 0);
	signal BSC : int19_vector(((Relu_data_Q'length/INT19_WIDTH)/3)*2-1 downto 0);
	signal FC_L,FC_R : int19_vector(Size_of_FC_vec-1 downto 0);
	signal mode_1_data : int19_vector_8ele_array(Num_of_units-1 downto 0);
	signal Conv_W_MEM_q_t : int8_vector_9ele_array(num_of_conv_filter-1 downto 0);
	signal WFC_MEM_q_t : int8_vector_8ele_array(Num_of_units-1 downto 0);
	signal Multi_data_out_t : int19_vector(Num_of_units*2-1 downto 0);
	signal Multi_data_L,Multi_data_R : int19_vector(Num_of_units-1 downto 0);
	signal BSC_t : int19_vector(num_of_18x18_multi*pic_height-1 downto 0);
	
	constant pad_BCS : int19_vector(num_of_18x18_multi*pic_height-1 downto 0):=(others=>(others=>'0'));
	constant int_PIXEL_DEF_VALUE : int8:=to_signed(PIXEL_DEF_VALUE,INT8_WIDTH);
	constant WHITE_COL : int8_vector(pic_height-1 downto 0):=(others=>int_PIXEL_DEF_VALUE);
begin

	--pixel_buffer_1<=split_to_int8_vector(pixel_in);
	pixel_buffer_1<=WHITE_COL when LL_read='1' else split_to_int8_vector(pixel_in);
	WFC_MEM_q_t<=split_to_int8_8ele_group(WFC_MEM_q,Num_of_units);
	
   pixel_groups <= generate_pixel_groups(pixel_buffer_3, pixel_buffer_2, pixel_buffer_1);
	Relu_data_Q_t<=split_to_int19_vector(Relu_data_Q);
	Conv_W_MEM_q_t<=split_to_int8_9ele_group(Conv_W_MEM_q,2);
	Multi_data_out_t<=split_to_int19_vector(Multi_data_out);
	
	--FC_L<=Relu_data_Q_t(Size_of_FC_vec*2-1 downto Size_of_FC_vec);
	Multi_data_R<=Multi_data_out_t(Num_of_units-1 downto 0);
	Multi_data_L<=Multi_data_out_t(Num_of_units*2-1 downto Num_of_units);
	FC_L<=fill_FC_right(Multi_data_L,Relu_data_Q_t(Size_of_FC_vec*2-1 downto Size_of_FC_vec),sub_pic_w);
	
	FC_R<=fill_FC_right(Multi_data_R,Relu_data_Q_t(Size_of_FC_vec-1 downto 0),sub_pic_w);
	--FC_R<=Relu_data_Q_t(Size_of_FC_vec-1 downto 0);
	
	--Multi_data_R<=Multi_data_out_t(Num_of_units-1 downto 0);
	--FC_FULL<=FC_L(Size_of_FC_vec-1-Num_of_units downto 0) & Multi_data_L & FC_R(Size_of_FC_vec-1-Num_of_units downto 0) & Multi_data_R;
	FC_FULL<=FC_L&FC_R;	
	
	BSC_t<=Relu_data_Q_t(Relu_data_Q_t'length-1 downto (Relu_data_Q_t'length/3)*2) when Set_BSC = '1' 
						else BSC(BSC'length-1 downto num_of_18x18_multi*pic_height);
	mode_1_data<=split_to_int19_vec_8ele_group(BSC_t,Num_of_units);
	input_mode_0<=generate_mode_0_input(pixel_groups,Conv_W_MEM_q_t(1),Conv_W_MEM_q_t(0),Num_of_units);
	input_mode_1<=generate_mode_1_input(mode_1_data,WFC_MEM_q_t,Num_of_units);
	Multi_data_in<=input_mode_0 when Select_mode='0' else input_mode_1;
	Multi_bais_in<=pad_bais&Conv_B_MEM_q when Select_mode='0' else BFC_MEM_q;
	
--	BSC_t

	Relu_data_in<=int19_vector_to_std_logic_vector(FC_FULL);
	Model_result<=signed(Multi_data_out(INT45_WIDTH-1 downto 0));
	
	
	
	process(clk_in,rst_n)
	begin
		if(rst_n='0') then
			--Multi_data_out_reg<=(others=>'0');
			for i in pixel_buffer_3'range loop
				pixel_buffer_3(i)<=int_PIXEL_DEF_VALUE;
				pixel_buffer_2(i)<=int_PIXEL_DEF_VALUE;
				
			end loop;
			for i in BSC'range loop
				BSC(i)<=(others=>'0');
			end loop;
		elsif(rising_edge(clk_in)) then
			--Multi_data_out_reg<=Multi_data_out;
			if(s_rst='1') then
				for i in pixel_buffer_3'range loop
					pixel_buffer_2(i)<=int_PIXEL_DEF_VALUE;
					pixel_buffer_3(i)<=int_PIXEL_DEF_VALUE;
				end loop;
			elsif(EN_pixel_reg='1' and LL_read='0') then
				pixel_buffer_3<=pixel_buffer_2;
				pixel_buffer_2<=pixel_buffer_1;
			end if;
			if(Set_BSC='1') then
				BSC<=Relu_data_Q_t(BSC'length-1 downto 0);
			else
				BSC<=BSC(BSC'length-num_of_18x18_multi*pic_height-1 downto 0)&pad_BCS;
			end if;
		end if;
	end process;
	
	
	
end architecture arch_data_managment_unit;