-- Testbench for OCR_CNN

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Include required packages
use WORK.multiplier_pack.ALL;
use WORK.data_pack.ALL;
use WORK.Parallel_Compute_Engine_16_pack.ALL;
use WORK.dmu_pack.ALL;
use WORK.mem_pack.ALL;
use WORK.rc_pack.ALL;
use WORK.all;

entity OCR_Accelerator_tb is
end OCR_Accelerator_tb;

architecture Arch_OCR_Accelerator_tb of OCR_Accelerator_tb is

    -- Constants and signal declarations
    constant MAX_out_L      : integer := 10;
    constant MAX_image_w    : integer := 400;
    constant Num_of_units   : integer := 16;

    signal clk_in       : std_logic := '0';
    signal rst          : std_logic := '1';
    signal image_load    : std_logic := '0';
    signal ADDR_PIXEL_END : integer range 0 to MAX_image_w := MAX_image_w;
    signal output_char  : char_vector(0 to MAX_out_L - 1);
    signal done         : std_logic;
    signal pixel_in     : std_logic_vector(pic_height * INT8_WIDTH - 1 downto 0);
    signal ADDR_PIXEL   : std_logic_vector(log2of(MAX_image_w) - 1 downto 0);

    -- Clock period definition
    constant clk_period : time := 10 ns;

    -- Component declarations
    component OCR_Accelerator is
        generic (
            MAX_out_L    : integer := 10;
            MAX_image_w  : integer := 400;
            Num_of_units : integer := 16;
            bais_bus_w   : integer := INT45_WIDTH
        );
        port(
            clk_in, rst, image_load : in std_logic;
            ADDR_PIXEL_END : in integer range 0 to MAX_image_w;
            output : out char_vector(0 to MAX_out_L - 1);
            done : out std_logic;
            pixel_in : in std_logic_vector(pic_height * INT8_WIDTH - 1 downto 0);
            ADDR_PIXEL : out std_logic_vector(log2of(MAX_image_w) - 1 downto 0)
        );
    end component;

    component XROM is
        generic (
            mif_fn     : string := "643_object_0.mif";
            DATA_WIDTH : integer := INT8_WIDTH*pic_height;
            ADDR_WIDTH : integer := log2of(MAX_image_w);  -- Adjusted to match ADDR_PIXEL width
            DATA_DEPTH : integer := 400  -- Assuming depth matches MAX_image_w
        );
        port (
            aclr    : in std_logic := '0';
            address : in std_logic_vector(ADDR_WIDTH - 1 downto 0);
            clock   : in std_logic := '1';
            q       : out std_logic_vector(DATA_WIDTH - 1 downto 0)
        );
    end component;

    -- Signals for connecting XROM and OCR_CNN
    signal rom_q : std_logic_vector(INT8_WIDTH*pic_height - 1 downto 0);

begin

    -- Instantiate the OCR_CNN
    uut : OCR_Accelerator
        generic map (
            MAX_out_L    => MAX_out_L,
            MAX_image_w  => MAX_image_w,
            Num_of_units => Num_of_units,
            bais_bus_w   => INT45_WIDTH
        )
        port map (
            clk_in        => clk_in,
            rst           => rst,
            image_load     => image_load,
            ADDR_PIXEL_END => 77,
            output        => output_char,
            done          => done,
            pixel_in      => pixel_in,
				--pixel_in => "01111111011111110111111101111111011111110111111101111111011111110111111101111111011111110111111101111111011111110111111101111111",
            ADDR_PIXEL    => ADDR_PIXEL
        );

    -- Instantiate the XROM
    rom_inst : XROM
        generic map (
            mif_fn     => "643_object_0.mif",
            DATA_WIDTH => INT8_WIDTH*pic_height,
            ADDR_WIDTH => log2of(MAX_image_w),
            DATA_DEPTH => MAX_image_w
        )
        port map (
            aclr    => rst,
            address => ADDR_PIXEL,
            clock   => clk_in,
            q       => rom_q
        );

    -- Connecting the ROM output to the pixel_in input of OCR_CNN
    -- Since pixel_in expects a vector of pic_height * INT8_WIDTH bits, we need to align the data
	 pixel_in<=rom_q;
--    process(clk_in)
--    begin
--        if rising_edge(clk_in) then
--            -- Load the pixel_in with data from ROM
--            -- Adjust this logic as per how you want to load multiple pixels
--            pixel_in <= (others => '0');
--            pixel_in(INT8_WIDTH - 1 downto 0) <= rom_q;
--        end if;
--    end process;

    -- Clock generation
    clk_process : process
    begin
        clk_in <= '0';
        wait for clk_period / 2;
        clk_in <= '1';
        wait for clk_period / 2;
    end process;

    -- Stimulus process
    stim_proc : process
    begin
        -- Initialize inputs
        rst <= '1';
        image_load <= '0';
        wait for 20 ns;
        rst <= '0';

        -- Start data loading
        image_load <= '1';
        wait for 100 ns; -- Adjust timing as needed
        image_load <= '0';

        -- Wait for the OCR_CNN to process the data
        wait until done = '1';

        -- End simulation
        wait;
    end process;

end Arch_OCR_Accelerator_tb;
