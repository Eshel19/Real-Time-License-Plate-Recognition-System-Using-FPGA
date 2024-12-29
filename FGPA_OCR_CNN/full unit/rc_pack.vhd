library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use WORK.data_pack.ALL;


package rc_pack is


	-- For integer array (assuming 256 elements)
--	constant threshold_arr : int45_vector(0 to N-1):=(
--		to_signed(1,INT45_WIDTH),
--		to_signed(2,INT45_WIDTH),
--		to_signed(3,INT45_WIDTH),
--		to_signed(4,INT45_WIDTH),
--		to_signed(5,INT45_WIDTH),
--		to_signed(6,INT45_WIDTH),
--		to_signed(7,INT45_WIDTH),
--		to_signed(8,INT45_WIDTH),
--		to_signed(9,INT45_WIDTH),
--		to_signed(10,INT45_WIDTH)
--	);
	constant threshold_arr : int45_vector(0 to N-1) := Convert_Int_Array_To_Signed(integer_values_threshold);
	constant Model_outputs_chars : char_vector(0 to N - 1):=String_To_Char_Vector(Model_outputs_str);
	constant WIDTH_Model_reg : integer := log2of(N);
	constant DEF_NO_WINNER: char :=0;
	type Model_regArray is array (natural range <>) of unsigned(WIDTH_Model_reg-1 downto 0);

--
--
--
--	-- Attribute for integer array
--	attribute ram_init_file : string;
--	attribute ram_init_file of threshold_arr : constant is thre_mif;
--	
	function MultiByTenADD(a,b:uint64) return uint64;
	



end package rc_pack;


package body rc_pack is

	function MultiByTenADD(a,b: uint64) return uint64 is
		variable a_10,result: uint64;
	begin
		a_10:=(a sll 3) + (a sll 1);
		result:=a_10+b;
		return result;
	end function MultiByTenADD;



end package body rc_pack;