library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

-- Include the data_managment_unit entity and other relevant definitions
use work.all;
use WORK.data_pack.ALL;
use WORK.dmu_pack.ALL;
use WORK.mem_pack.ALL;
use WORK.testbench_pack.ALL;

entity tb_data_management_unit is
end entity tb_data_management_unit;

architecture Behavioral of tb_data_management_unit is
	constant Num_of_units : integer := 16;
	constant bais_bus_w : integer := 45;
	signal pixel_in       : std_logic_vector(pic_height*INT8_WIDTH-1 downto 0);
	signal WFC_MEM_q      : std_logic_vector(WFC_info.DATA_WIDTH-1 downto 0);
	signal BFC_MEM_q      : std_logic_vector(BFC_info.DATA_WIDTH-1 downto 0);
	signal Conv_W_MEM_q   : std_logic_vector(CONV_W_info.DATA_WIDTH-1 downto 0);
	signal Conv_B_MEM_q   : std_logic_vector(CONV_B_info.DATA_WIDTH-1 downto 0);
	signal Relu_data_Q    : std_logic_vector(relu_out_info.DATA_WIDTH-1 downto 0);
	signal Relu_data_in   : std_logic_vector(relu_out_info.DATA_WIDTH-1 downto 0);
	signal Model_result   : int45;
	signal Multi_data_in  : conv_in_data_vector(16-1 downto 0);
	signal Multi_bais_in  : std_logic_vector(bais_bus_w-1 downto 0);
	signal Multi_data_out : std_logic_vector(conv_data_out_size*Num_of_units-1 downto 0);
	signal Select_mode    : std_logic := '0';
	signal Update_FC_data : std_logic := '0';
	signal Set_BSC        : std_logic := '0';
	signal rst            : std_logic := '0';
	signal clk_in         : std_logic := '0';
	signal EN_pixel_reg   : std_logic := '0';
	signal S_rst          : std_logic := '0';
	signal LL_read 		 : std_logic := '0';

	constant clk_period : time := 10 ns;


begin

    -- Instantiate the unit under test (UUT)
    uut: entity work.data_managment_unit
        generic map (
            Num_of_units => 16,
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
            rst => rst,
            clk_in => clk_in,
            EN_pixel_reg => EN_pixel_reg,
				LL_read => LL_read,
            S_rst => S_rst
        );
		        -- Read the first line from each MIF file
        pixel_in <= (others=>'0');
        WFC_MEM_q <= (others=>'1');
		  Multi_data_out<=(others=>'1');
        BFC_MEM_q <= read_mif(WFC_info.mif_fn, 3, BFC_info.DATA_WIDTH);
        Conv_W_MEM_q <= read_mif(CONV_W_info.mif_fn, 3, CONV_W_info.DATA_WIDTH);
        Conv_B_MEM_q <= read_mif(CONV_B_info.mif_fn, 3, CONV_B_info.DATA_WIDTH);
        Relu_data_Q <= read_mif(relu_out_info.mif_fn, 3, relu_out_info.DATA_WIDTH);

    -- Clock process
    clk_process: process
    begin
        clk_in <= '0';
        wait for clk_period / 2;
        clk_in <= '1';
        wait for clk_period / 2;
    end process;
    -- Stimulus process
    stimulus: process
    begin
        rst <= '1';
        wait for 20 ns;
        rst <= '0';
        -- Initialize inputs
        Select_mode <= '0';
        Update_FC_data <= '0';
        Set_BSC <= '0';
        EN_pixel_reg <= '0';
        S_rst <= '0';

        -- Wait for global reset
        wait for 100 ns;
        S_rst <= '1';
        wait for 10 ns;
        S_rst <= '0';


        -- Change modes
        Select_mode <= '1';
        wait for 20 ns;
        Select_mode <= '0';

        Update_FC_data <= '1';
        wait for 20 ns;
        Update_FC_data <= '0';

        Set_BSC <= '1';
        wait for 20 ns;
        Set_BSC <= '0';

        EN_pixel_reg <= '1';
        wait for 20 ns;
        EN_pixel_reg <= '0';

        -- Wait for some time to observe the outputs
        wait for 100 ns;

        -- End simulation
        wait;
    end process;
end architecture Behavioral;
