library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Include your packages with constants
use WORK.data_pack.ALL;
use WORK.mem_pack.ALL;

entity Relu_out_FIFO_TB is
	GENERIC (
	mif_fn:string:=relu_out_info.mif_fn;
	DATA_WIDTH : integer := relu_out_info.DATA_WIDTH;
	ADDR_WIDTH : integer := relu_out_info.ADDR_WIDTH;
	DATA_DEPTH : integer := relu_out_info.DATA_DEPTH
	);
end entity;

architecture Behavioral of Relu_out_FIFO_TB is

    -- Signals to connect to the FIFO under test
    signal rst                 : std_logic := '0';
    signal clk_in              : std_logic := '0';
    signal Relu_data_in        : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal Relu_out_Write_en   : std_logic := '0';
    signal Relu_out_Read_en    : std_logic := '0';
    signal Relu_data_Q         : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal full                : std_logic;
    signal empty               : std_logic;
    signal S_rst               : std_logic := '0';

    -- Clock period definition
    constant clk_period : time := 10 ns;


begin

    -- Instantiate the FIFO under test
    uut: entity WORK.Relu_out_FIFO
        generic map (
            mif_fn     => relu_out_info.mif_fn,
            DATA_WIDTH => relu_out_info.DATA_WIDTH,
            ADDR_WIDTH => relu_out_info.ADDR_WIDTH,
            DATA_DEPTH => relu_out_info.DATA_DEPTH
        )
        port map (
            rst_n                 => rst,
            clk_in              => clk_in,
            Relu_data_in        => Relu_data_in,
            Relu_WR_EN   => Relu_out_Write_en,
            Relu_RD_EN    => Relu_out_Read_en,
            Relu_data_Q         => Relu_data_Q,
            S_rst               => S_rst
        );

    -- Clock generation process
    clk_process : process
    begin
        while true loop
            clk_in <= '0';
            wait for clk_period / 2;
            clk_in <= '1';
            wait for clk_period / 2;
        end loop;
    end process;

    -- Stimulus process
    stim_process : process
        variable write_count : integer := 0;
        variable read_count  : integer := 0;
        variable data_value  : std_logic_vector(DATA_WIDTH-1 downto 0);
    begin
        -- Apply reset to initialize the FIFO
        rst <= '0';
        S_rst <= '1';
        wait for 2 * clk_period;
        rst <= '1';
        S_rst <= '0';
        wait for clk_period;

        -- Wait for FIFO to get ready (if necessary)
        wait for clk_period;

        -- **Reading Data from FIFO**
        -- Since the FIFO starts full with MIF data, we'll read data until it's empty
		  
        report "Starting to read data from FIFO";
		  Relu_out_Read_en <= '1';
        wait for clk_period*3;
		  Relu_out_Read_en <= '0';
		  wait for clk_period*2;

        while read_count /= 200 loop
				data_value := std_logic_vector(to_unsigned(9999, DATA_WIDTH));
				Relu_data_in      <= data_value;
				Relu_out_Read_en <= '1';
				Relu_out_Write_en <= '1';
				wait for clk_period;
				data_value := std_logic_vector(to_unsigned(7777, DATA_WIDTH));
				Relu_data_in      <= data_value;
				Relu_out_Write_en <= '1';
            Relu_out_Read_en <= '1';
            wait for clk_period;
				data_value := std_logic_vector(to_unsigned(12345, DATA_WIDTH));
				Relu_data_in      <= data_value;
				Relu_out_Write_en <= '1';
            Relu_out_Read_en <= '1';
				wait for clk_period;
				Relu_out_Write_en <= '0';
				Relu_out_Read_en <= '0';
				wait for clk_period*2;

				if(read_count=ADDR_Relu_write_start) then
					report "read start reading the write values reads: " & integer'image(read_count);
				end if;
            read_count := read_count + 3;
        end loop;
        report "Finished reading data. Total reads: " & integer'image(read_count);

        -- **Writing Data into FIFO**
        -- Now, we'll write new data into the FIFO until it's full
        report "Starting to write data into FIFO";
        while full = '0' loop
            -- Generate some data to write (e.g., incrementing value)
            data_value := std_logic_vector(to_unsigned(write_count, DATA_WIDTH));

            Relu_data_in      <= data_value;
            Relu_out_Write_en <= '1';
            wait for clk_period;
            Relu_out_Write_en <= '0';
            wait for clk_period;

            -- Display the data written
--            report "Wrote data: " & std_logic_vector'image(data_value);
            write_count := write_count + 1;
        end loop;
--        report "Finished writing data. Total writes: " & integer'image(write_count);

        -- **Reading the Newly Written Data**
        -- Reset the counters
        read_count := 0;

        report "Starting to read newly written data from FIFO";
        while empty = '0' loop
            Relu_out_Read_en <= '1';
            wait for clk_period;
            Relu_out_Read_en <= '0';
            wait for clk_period;

            -- Display the data read
--            report "Read data: " & std_logic_vector'image(Relu_data_Q);
            read_count := read_count + 1;
        end loop;
--        report "Finished reading data. Total reads: " & integer'image(read_count);

        -- **End of Simulation**
--        report "Simulation completed successfully." severity note;
        wait;
    end process;

end architecture Behavioral;
