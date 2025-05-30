library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use WORK.data_pack.ALL;

entity System_SM_tb is
    -- Testbench has no ports
end System_SM_tb;

architecture Behavioral of System_SM_tb is
    -- Component Declaration
    component System_SM is
        GENERIC (
            MAX_out_L    : integer := 10;
            MAX_IMAGE_W  : integer := 400;
            T_RAM        : integer := 1;
            T_find_winner: integer := 1
        );
        port(
            clk_in, rst, data_load, winner, At_final_line : in std_logic;
            done, Start_load_Data, EN_pixel_reg, Relu_out_write_en, S_rst, Select_mode,
            Update_FC_data, Set_BSC, Check_winner, En_shift_result : out std_logic
        );
    end component;

    -- Internal Signals
    signal clk_in_tb           : std_logic := '0';
    signal rst_tb              : std_logic := '0';
    signal data_load_tb        : std_logic := '0';
    signal winner_tb           : std_logic := '0';
    signal At_final_line_tb    : std_logic := '0';

    signal done_tb             : std_logic;
    signal Start_load_Data_tb  : std_logic;
    signal EN_pixel_reg_tb     : std_logic;
    signal Relu_out_write_en_tb: std_logic;
    signal S_rst_tb            : std_logic;
    signal Select_mode_tb      : std_logic;
    signal Update_FC_data_tb   : std_logic;
    signal Set_BSC_tb          : std_logic;
    signal Check_winner_tb     : std_logic;
    signal En_shift_result_tb  : std_logic;
begin
	
    -- Instantiate the Unit Under Test (UUT)
    UUT: System_SM
        generic map(
            MAX_out_L     => 10,
            MAX_IMAGE_W   => 400,
            T_RAM         => 1,
            T_find_winner => 1
        )
        port map(
            clk_in           => clk_in_tb,
            rst              => rst_tb,
            data_load        => data_load_tb,
            winner           => winner_tb,
            At_final_line    => At_final_line_tb,
            done             => done_tb,
            Start_load_Data  => Start_load_Data_tb,
            EN_pixel_reg     => EN_pixel_reg_tb,
            Relu_out_write_en=> Relu_out_write_en_tb,
            S_rst            => S_rst_tb,
            Select_mode      => Select_mode_tb,
            Update_FC_data   => Update_FC_data_tb,
            Set_BSC          => Set_BSC_tb,
            Check_winner     => Check_winner_tb,
            En_shift_result  => En_shift_result_tb
        );
		      -- Clock Generation Process
    clk_process : process
    begin
        while True loop
            clk_in_tb <= '0';
            wait for 5 ns;
            clk_in_tb <= '1';
            wait for 5 ns;
        end loop;
    end process;
    -- Stimuli Process
    stim_proc: process
    begin
        -- Initial Reset
        rst_tb <= '1';
        wait for 20 ns;
        rst_tb <= '0';
        wait for 10 ns;

        -- Scenario 1: Start Loading Data
        data_load_tb <= '1';
        wait for 30 ns;
        data_load_tb <= '0';
        wait for 20 ns;

        -- Scenario 2: At Final Line
        At_final_line_tb <= '1';
        wait for 10 ns;
        At_final_line_tb <= '0';
        wait for 20 ns;

        -- Scenario 3: Winner Detected
        winner_tb <= '1';
        wait for 10 ns;
        winner_tb <= '0';
        wait for 20 ns;

        -- Scenario 4: Combined Signals
        data_load_tb    <= '1';
        At_final_line_tb<= '1';
        winner_tb       <= '1';
        wait for 30 ns;
        data_load_tb    <= '0';
        At_final_line_tb<= '0';
        winner_tb       <= '0';
        wait for 20 ns;

        -- End Simulation
        wait;
    end process;
	     -- Monitoring Process (Optional)
    monitor_proc: process(clk_in_tb)
    begin
        if rising_edge(clk_in_tb) then
            report "Time: " & time'image(now) &
                   " | rst: " & std_logic'image(rst_tb) &
                   " | data_load: " & std_logic'image(data_load_tb) &
                   " | At_final_line: " & std_logic'image(At_final_line_tb) &
                   " | winner: " & std_logic'image(winner_tb) &
                   " || Outputs -> done: " & std_logic'image(done_tb) &
                   ", Start_load_Data: " & std_logic'image(Start_load_Data_tb) &
                   ", EN_pixel_reg: " & std_logic'image(EN_pixel_reg_tb);
            -- Add more outputs as needed
        end if;
    end process;

end Behavioral;

