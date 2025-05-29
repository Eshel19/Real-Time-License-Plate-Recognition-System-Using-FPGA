library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use WORK.multiplier_pack.ALL;
use WORK.data_pack.ALL;
use WORK.Parallel_Compute_Engine_16_pack.ALL;
use WORK.dmu_pack.ALL;
use WORK.mem_pack.ALL;
use WORK.rc_pack.ALL;
use work.all;

entity OCR_Accelerator is
	GENERIC (
	MAX_out_L : integer := 10;
	MAX_image_w : integer := 400;
	Num_of_units : integer := 16;
	bais_bus_w : integer := INT45_WIDTH
	);
	port(
		clk_in,rst_n,image_load,CU_rst : in std_logic;
		ADDR_PIXEL_START : in unsigned(15 downto 0);
		ADDR_PIXEL_END : in unsigned(15 downto 0);
		output_dig_detect : out unsigned(7 downto 0);
		output_char : out std_logic_vector(MAX_out_L*INT8_WIDTH-1 downto 0);
		done : out std_logic;
		pixel_in : in std_logic_vector(pic_height*INT8_WIDTH-1 downto 0);
		ADDR_PIXEL :out std_logic_vector(log2of(MAX_IMAGE_W)-1 downto 0)

	);
end OCR_Accelerator;


architecture arch_OCR_Accelerator of OCR_Accelerator is

	signal output_char_uncoded : char_vector(MAX_out_L-1 downto 0);
	signal WFC_MEM_q : std_logic_vector(WFC_info.DATA_WIDTH-1 downto 0);
	signal BFC_MEM_q : std_logic_vector(BFC_info.DATA_WIDTH-1 downto 0);
	signal Conv_W_MEM_q : std_logic_vector(CONV_W_info.DATA_WIDTH-1 downto 0);
	signal Conv_B_MEM_q : std_logic_vector(CONV_B_info.DATA_WIDTH-1 downto 0);
	signal Relu_data_Q : std_logic_vector(relu_out_info.DATA_WIDTH-1 downto 0);
	signal Relu_data_in : std_logic_vector(relu_out_info.DATA_WIDTH-1 downto 0);
	signal Model_result : int45;
	signal Multi_data_in : conv_in_data_vector(Num_of_units-1 downto 0);
	signal Multi_bais_in : std_logic_vector(bais_bus_w-1 downto 0);
	signal Multi_data_out :std_logic_vector(conv_data_out_size*Num_of_units-1 downto 0);
	signal Select_mode,next_fc,LL_Read,Done_t,Set_BSC,EN_pixel_reg,S_rst: std_logic;
	
	
---System_SM signal
	signal Start_load_Data,Relu_WR_EN,Relu_RD_en,Check_winner,En_shift_result,is_idle : std_logic;
	signal winner,At_final_line :std_logic;
	
--Memory CU
	signal ADDR_WFC : std_logic_vector(WFC_info.ADDR_WIDTH-1 downto 0);
	signal ADDR_BFC : std_logic_vector(BFC_info.ADDR_WIDTH-1 downto 0);
	signal ADDR_Conv : std_logic_vector(CONV_W_info.ADDR_WIDTH-1 downto 0);
	
	
	signal Relu_out_read_en,full,empty : std_logic;

begin
	done<=done_t;
	DMU: entity work.data_managment_unit
        generic map (
            Num_of_units => Num_of_units,
            bais_bus_w => INT45_WIDTH
        )
        port map (
            pixel_in => pixel_in,
            WFC_MEM_q => WFC_MEM_q,
            BFC_MEM_q => BFC_MEM_q,
            Conv_W_MEM_q => Conv_W_MEM_q,
            Conv_B_MEM_q => Conv_B_MEM_q,
            Relu_data_Q => Relu_data_Q,
            Relu_data_in => Relu_data_in,
            Model_result => Model_result,
            Multi_data_in => Multi_data_in,
            Multi_bais_in => Multi_bais_in,
            Multi_data_out => Multi_data_out,
            Select_mode => Select_mode,
            Set_BSC => Set_BSC,
            rst_n => rst_n,
            clk_in => clk_in,
            EN_pixel_reg => EN_pixel_reg,
				LL_Read => LL_Read,
				
            S_rst => S_rst
        );

		  
		  
	output_char<=char_vector_to_std_logic_vector(output_char_uncoded);	  
--setting up MEMs
	WFC_MEM: entity work.XROM
				GENERIC map(
					mif_fn =>WFC_info.mif_fn ,
					DATA_WIDTH =>WFC_info.DATA_WIDTH, 
					ADDR_WIDTH =>WFC_info.ADDR_WIDTH,
					DATA_DEPTH =>WFC_info.DATA_DEPTH
				)
				PORT map
				(
					aclr=>rst_n,
					address=>ADDR_WFC,
					clock=>clk_in,
					q=>WFC_MEM_q
				);
				
				
	BFC_MEM: entity work.XROM
				GENERIC map(
					mif_fn =>BFC_info.mif_fn ,
					DATA_WIDTH =>BFC_info.DATA_WIDTH, 
					ADDR_WIDTH =>BFC_info.ADDR_WIDTH,
					DATA_DEPTH =>BFC_info.DATA_DEPTH
				)
				PORT map
				(
					aclr=>rst_n,
					address=>ADDR_BFC,
					clock=>clk_in,
					q=>BFC_MEM_q
				);
	

	CONV_W_MEM: entity work.XROM
				GENERIC map(
					mif_fn =>CONV_W_info.mif_fn ,
					DATA_WIDTH =>CONV_W_info.DATA_WIDTH, 
					ADDR_WIDTH =>CONV_W_info.ADDR_WIDTH,
					DATA_DEPTH =>CONV_W_info.DATA_DEPTH
				)
				PORT map
				(
					aclr=>rst_n,
					address=>ADDR_Conv,
					clock=>clk_in,
					q=>Conv_W_MEM_q
				);

			
	CONV_B_MEM: entity work.XROM
				GENERIC map(
					mif_fn =>CONV_B_info.mif_fn ,
					DATA_WIDTH =>CONV_B_info.DATA_WIDTH, 
					ADDR_WIDTH =>CONV_B_info.ADDR_WIDTH,
					DATA_DEPTH =>CONV_B_info.DATA_DEPTH
				)
				PORT map
				(
					aclr=>rst_n,
					address=>ADDR_Conv,
					clock=>clk_in,
					q=>Conv_B_MEM_q
				);
	
	Relu_out_FIFO_MEM: entity work.Relu_out_FIFO
			GENERIC map(
				mif_fn =>relu_out_info.mif_fn ,
				DATA_WIDTH =>relu_out_info.DATA_WIDTH, 
				ADDR_WIDTH =>relu_out_info.ADDR_WIDTH,
				DATA_DEPTH =>relu_out_info.DATA_DEPTH
			)
			PORT map
			(
				rst_n=>rst_n,
				Relu_data_in=>Relu_data_in,
				Relu_WR_EN=>Relu_WR_EN,
				Relu_RD_en=>Relu_RD_en,
				clk_in=>clk_in,
				Relu_data_Q=>Relu_data_Q,
				S_rst=>S_rst
			);
-----------------
	Parallel_Compute_Engine: entity work.Parallel_Compute_Engine_16
						generic map (
							Num_of_units => Num_of_units,
							bais_bus_w => INT45_WIDTH
						)
						port map(
							data_in=>Multi_data_in,
							bais_in=>Multi_bais_in,
							output=>Multi_data_out,
							clk_in=>clk_in,
							select_mode=>select_mode,
							next_fc =>next_fc,
							rst_n=>rst_n
						);
	Results: entity work.Results_comparator_Chars
					generic map (
						MAX_out_L =>MAX_out_L
					)
					port map(
						data_in=>Model_result,
						Shift_EN=>En_shift_result,
						output=>output_char_uncoded,
						clk_in=>clk_in,
						check_winner=>Check_winner,
						rst_n=>rst_n,
						is_idle=>is_idle,
						dig_detect_count=>output_dig_detect,
						winner_output=>winner
					);
	SysCU: entity work.System_SM
				generic map (
						MAX_out_L => MAX_out_L,
						MAX_IMAGE_W =>MAX_IMAGE_W,
						T_RAM =>T_RAM,
						T_winner  =>T_find_winner,
						total_filters =>total_filters
					
				)
				port map(
					clk_in=>clk_in,
					rst_n=>rst_n,
					CU_rst=>CU_rst,
					image_load=>image_load,
					winner=>winner,
					At_final_line =>At_final_line,
					done=>done_t,
					Start_load_Data=>Start_load_Data,
					EN_pixel_reg=>EN_pixel_reg,
					Relu_WR_EN=>Relu_WR_EN,
					S_rst=>S_rst,
					Select_mode=>Select_mode,
					next_fc=>next_fc,
					Set_BSC=>Set_BSC,
					LL_Read=>LL_Read,
					Check_winner=>Check_winner,
					is_idle =>is_idle,
					En_shift_result=>En_shift_result
				);
	MemCU: entity work.Memory_CU
				generic map (
					MAX_IMAGE_W =>MAX_IMAGE_W,
					T_winner  =>T_find_winner,
					total_filters =>total_filters
				)
				port map(
					clk_in=>clk_in,
					rst_n=>rst_n,
					Start_data_load=>Start_load_Data,
					S_rst=>winner,
					ADDR_PIXEL_END=>ADDR_PIXEL_END,
					ADDR_PIXEL_START=>ADDR_PIXEL_START,
					ADDR_WFC=>ADDR_WFC,
					ADDR_PIXEL=>ADDR_PIXEL,
					ADDR_BFC=>ADDR_BFC,
					ADDR_Conv=>ADDR_Conv,
					done=>done_t,
					is_idle =>is_idle,
					At_final_line=>At_final_line,
					Relu_RD_en=>Relu_RD_en
				);
	
end arch_OCR_Accelerator;