-- Testbench for Results_comparator

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Include custom packages
use WORK.data_pack.ALL;
use WORK.rc_pack.ALL;

entity Results_comparator_char_tb is
end entity Results_comparator_char_tb;

architecture arch_Results_comparator_char_tb of Results_comparator_char_tb is
	signal MAX_out_L : integer := 10;
    -- Constants
    constant clk_period : time := 10 ns;
    constant N          : integer := 10; -- Number of models

    -- Signals to interface with the component
    signal data_in       : int45;
    signal clk_in        : std_logic := '0';
    signal rst           : std_logic;
    signal check_winner  : std_logic;
    signal Shift_EN      : std_logic;
    signal output        : char_vector(0 to MAX_out_L-1);
    signal winner_output : std_logic;

    -- Internal signals for testing
    type int45_array is array (0 to N-1) of int45;
    signal model_results : int45_array;
    signal model_index   : integer range 0 to N-1 := 0;
    signal concatenated_output : uint64; -- For accumulating outputs over runs

    -- Access the threshold_arr constant
    -- Assuming threshold_arr is defined in WORK.data_pack or WORK.rc_pack
    -- Ensure the package is correctly included

begin

    -- Instantiate the Results_comparator component
    UUT: entity WORK.Results_comparator_Chars
	 GENERIC map(MAX_out_L=>10)
        port map (
            data_in       => data_in,
            clk_in        => clk_in,
            rst           => rst,
            check_winner  => check_winner,
            Shift_EN      => Shift_EN,
            output        => output,
            winner_output => winner_output
        );

    -- Clock generation process
    clk_process : process
    begin
        while True loop
            clk_in <= '1';
            wait for clk_period / 2;
            clk_in <= '0';
            wait for clk_period / 2;
        end loop;
    end process clk_process;

    -- Stimulus process
    stimulus_process : process
        -- Variables for control flow
        variable run_number : integer := 0;

    begin
        -- Reset the component
        rst <= '1';
        check_winner <= '0';
        Shift_EN <= '0';
        wait for clk_period * 2;
        rst <= '0';

        -- Loop over multiple runs
        for run_number in 1 to 6 loop
            report "Starting run number " & integer'image(run_number);

            -- Initialize model results for this run using a case statement
            case run_number is
                when 1 =>
                    -- First run: model 1 has highest score above threshold
                    model_results(0) <= to_signed(300, 45);
                    model_results(1) <= to_signed(500, 45); -- Highest
                    model_results(2) <= to_signed(250, 45);
                    model_results(3) <= to_signed(350, 45);
                    model_results(4) <= to_signed(450, 45);
                    model_results(5) <= to_signed(200, 45);
                    model_results(6) <= to_signed(150, 45);
                    model_results(7) <= to_signed(100, 45);
                    model_results(8) <= to_signed(50,  45);
                    model_results(9) <= to_signed(400, 45);
                when 2 =>
                    -- Second run: model 3 has highest score above threshold
                    model_results(0) <= to_signed(300, 45);
                    model_results(1) <= to_signed(400, 45);
                    model_results(2) <= to_signed(250, 45);
                    model_results(3) <= to_signed(600, 45); -- Highest
                    model_results(4) <= to_signed(450, 45);
                    model_results(5) <= to_signed(200, 45);
                    model_results(6) <= to_signed(150, 45);
                    model_results(7) <= to_signed(100, 45);
                    model_results(8) <= to_signed(50,  45);
                    model_results(9) <= to_signed(350, 45);
					when 3 =>
                    -- Second run: model 3 has highest score above threshold
                    model_results(0) <= to_signed(300, 45);
                    model_results(1) <= to_signed(400, 45);
                    model_results(2) <= to_signed(250, 45);
                    model_results(3) <= to_signed(32, 45);
                    model_results(4) <= to_signed(450, 45);
                    model_results(5) <= to_signed(200, 45);
                    model_results(6) <= to_signed(150, 45);
                    model_results(7) <= to_signed(100, 45);
                    model_results(8) <= to_signed(50,  45);
                    model_results(9) <= to_signed(9999, 45);  -- Highest
                when 4 =>
                    -- Third run: All results below thresholds
                    for i in 0 to N-1 loop
                        model_results(i) <= to_signed(-1, 45); -- All scores below typical threshold
                    end loop;

					when 5 =>
                    -- Second run: model 3 has highest score above threshold
                    model_results(0) <= to_signed(9999, 45);
                    model_results(1) <= to_signed(400, 45);
                    model_results(2) <= to_signed(250, 45);
                    model_results(3) <= to_signed(32, 45);
                    model_results(4) <= to_signed(450, 45);
                    model_results(5) <= to_signed(200, 45);
                    model_results(6) <= to_signed(150, 45);
                    model_results(7) <= to_signed(100, 45);
                    model_results(8) <= to_signed(50,  45);
                    model_results(9) <= to_signed(9999, 45);  -- Highest
					when 6 =>
                    -- Second run: model 3 has highest score above threshold
                    model_results(0) <= to_signed(9999, 45);
                    model_results(1) <= to_signed(400, 45);
                    model_results(2) <= to_signed(250, 45);
                    model_results(3) <= to_signed(32, 45);
                    model_results(4) <= to_signed(-1, 45);
                    model_results(5) <= to_signed(200, 45);
                    model_results(6) <= to_signed(150, 45);
                    model_results(7) <= to_signed(9999999, 45); -- Highest
                    model_results(8) <= to_signed(50,  45);
                    model_results(9) <= to_signed(9999, 45); 
					when others =>
                    -- Default case (not expected in this scenario)
                    report "Unexpected run number: " & integer'image(run_number) severity warning;
                    -- Initialize all model results to zero
                    for i in 0 to N-1 loop
                        model_results(i) <= (others => '0');
							end loop;
            end case;
				check_winner <= '0';
            wait for clk_period;
            -- Clear previous outputs
--            concatenated_output <= (others => '0');

            -- Process each model
            for model_index in 0 to N-1 loop
                data_in <= model_results(model_index);

                -- Simulate Shift_EN signal to process this model
					 Shift_EN <= '0';
                wait for clk_period * 3;
                Shift_EN <= '1';
                wait for clk_period;
                if(model_index=(N-1)) then
						Shift_EN <= '0';
					   check_winner <= '1';
						wait for clk_period;
					 end if;

                -- Optional: Wait for component to process data
                -- Adjust as per component's timing requirements
            end loop;

            -- After all models processed, signal to check winner
            -- Accumulate output (only if winner_output is '1')
            if winner_output = '1' then
--                concatenated_output <= resize(concatenated_output * 100 + unsigned(output), 64);
            end if;

            -- Report the winner
--            if winner_output = '1' then
--                report "Winner found in run " & integer'image(run_number) &
--                       ": Model " & integer'image(to_integer(unsigned(output))) &
--                       " with score " & integer'image(to_integer(model_results(to_integer(unsigned(output))))) &
--                       " exceeding threshold " & integer'image(to_integer(threshold_arr(to_integer(unsigned(output)))));
--            else
--                report "No winner found in run " & integer'image(run_number);
--            end if;


        end loop;
			check_winner <= '0';
        report "Test completed. Final concatenated output: " & integer'image(to_integer(concatenated_output));

        -- End the simulation
        wait;
    end process stimulus_process;

end architecture arch_Results_comparator_char_tb;
