library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.textio.all;
use work.all;
use WORK.data_pack.ALL;
use WORK.dmu_pack.ALL;
use WORK.mem_pack.ALL;
use WORK.testbench_pack.ALL;


entity tb_functions is
end entity;

architecture behavior of tb_functions is

begin

    -- Test process for both multipliers
    process
        -- Variables for 8x8 multiplier
        variable a8, b8       : int8;
        variable result8      : int18;
        variable expected8    : integer;
        variable actual8      : integer;
        variable passed8      : boolean;
        variable test_case8   : integer := 0;

        -- Variables for 19x8 multiplier
        variable a19          : int19;
        variable b8_19        : int8;
        variable result19x8   : int27;
        variable expected19x8 : integer;
        variable actual19x8   : integer;
        variable passed19x8   : boolean;
        variable test_case19x8: integer := 0;

    begin
        -- Testing Multi8x8 function
        report "Starting tests for Multi8x8 function";

        --------------------------------------------------------------------
        -- Test case 1 for Multi8x8: Both positive
        test_case8 := test_case8 + 1;
        a8 := to_signed(12, 8);
        b8 := to_signed(34, 8);
        result8 := Multi8x8(a8, b8);
        expected8 := 12 * 34;
        actual8 := to_integer(result8);
        passed8 := (actual8 = expected8);
        report "Multi8x8 Test case " & integer'image(test_case8) &
               ": a=" & integer'image(to_integer(a8)) & ", b=" & integer'image(to_integer(b8)) &
               ", result=" & integer'image(actual8) &
               " (expected " & integer'image(expected8) & ")" &
               ", passed=" & boolean'image(passed8);
        assert passed8 severity error;

        --------------------------------------------------------------------
        -- Test case 2 for Multi8x8: One positive, one negative
        test_case8 := test_case8 + 1;
        a8 := to_signed(-15, 8);
        b8 := to_signed(25, 8);
        result8 := Multi8x8(a8, b8);
        expected8 := -15 * 25;
        actual8 := to_integer(result8);
        passed8 := (actual8 = expected8);
        report "Multi8x8 Test case " & integer'image(test_case8) &
               ": a=" & integer'image(to_integer(a8)) & ", b=" & integer'image(to_integer(b8)) &
               ", result=" & integer'image(actual8) &
               " (expected " & integer'image(expected8) & ")" &
               ", passed=" & boolean'image(passed8);
        assert passed8 severity error;

        --------------------------------------------------------------------
        -- Test case 3 for Multi8x8: Both negative
        test_case8 := test_case8 + 1;
        a8 := to_signed(-20, 8);
        b8 := to_signed(-30, 8);
        result8 := Multi8x8(a8, b8);
        expected8 := (-20) * (-30);
        actual8 := to_integer(result8);
        passed8 := (actual8 = expected8);
        report "Multi8x8 Test case " & integer'image(test_case8) &
               ": a=" & integer'image(to_integer(a8)) & ", b=" & integer'image(to_integer(b8)) &
               ", result=" & integer'image(actual8) &
               " (expected " & integer'image(expected8) & ")" &
               ", passed=" & boolean'image(passed8);
        assert passed8 severity error;

        -- Additional test cases for Multi8x8 can be added here...

        report "Completed tests for Multi8x8 function";

        --------------------------------------------------------------------
        -- Testing Multi19x8 function
        report "Starting tests for Multi19x8 function";

        --------------------------------------------------------------------
        -- Test case 1 for Multi19x8: Both positive
        test_case19x8 := test_case19x8 + 1;
        a19 := to_signed(150000, 19);
        b8_19 := to_signed(75, 8);
        result19x8 := Multi19x8(a19, b8_19);
        expected19x8 := 150000 * 75;
        actual19x8 := to_integer(result19x8);
        passed19x8 := (actual19x8 = expected19x8);
        report "Multi19x8 Test case " & integer'image(test_case19x8) &
               ": A=" & integer'image(to_integer(a19)) & ", B=" & integer'image(to_integer(b8_19)) &
               ", result=" & integer'image(actual19x8) &
               " (expected " & integer'image(expected19x8) & ")" &
               ", passed=" & boolean'image(passed19x8);
        assert passed19x8 severity error;

        --------------------------------------------------------------------
        -- Test case 2 for Multi19x8: Negative A, positive B
        test_case19x8 := test_case19x8 + 1;
        a19 := to_signed(-150000, 19);
        b8_19 := to_signed(75, 8);
        result19x8 := Multi19x8(a19, b8_19);
        expected19x8 := -150000 * 75;
        actual19x8 := to_integer(result19x8);
        passed19x8 := (actual19x8 = expected19x8);
        report "Multi19x8 Test case " & integer'image(test_case19x8) &
               ": A=" & integer'image(to_integer(a19)) & ", B=" & integer'image(to_integer(b8_19)) &
               ", result=" & integer'image(actual19x8) &
               " (expected " & integer'image(expected19x8) & ")" &
               ", passed=" & boolean'image(passed19x8);
        assert passed19x8 severity error;

        -- Additional test cases for Multi19x8 can be added here...

        report "Completed tests for Multi19x8 function";

        --------------------------------------------------------------------
        -- Indicate completion of all tests
        report "All tests completed successfully.";
        wait;
    end process;



	
end architecture behavior;
