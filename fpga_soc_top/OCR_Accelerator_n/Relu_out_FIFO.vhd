library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use WORK.data_pack.ALL;
use WORK.mem_pack.ALL;

entity Relu_out_FIFO is
GENERIC (
	mif_fn:string:=relu_out_info.mif_fn;
	DATA_WIDTH : integer := relu_out_info.DATA_WIDTH;
	ADDR_WIDTH : integer := relu_out_info.ADDR_WIDTH;
	DATA_DEPTH : integer := relu_out_info.DATA_DEPTH
	);
    Port (
		rst_n		: IN STD_LOGIC;
		clk_in		: IN STD_LOGIC;
		Relu_data_in		: IN STD_LOGIC_VECTOR (DATA_WIDTH-1 DOWNTO 0);
		Relu_WR_EN		: IN STD_LOGIC ;
		Relu_RD_EN : IN STD_LOGIC;
		Relu_data_Q		: OUT STD_LOGIC_VECTOR (DATA_WIDTH-1 DOWNTO 0);
		S_rst : in std_logic
    );
end Relu_out_FIFO;

architecture arch_Relu_out_FIFO of Relu_out_FIFO is

	signal read_addr,write_addr,write_addr_1,read_addr_1,read_addr_n,write_addr_n : integer range 0 to (DATA_DEPTH-1);
	signal read_addr_ung,write_addr_ung: unsigned(ADDR_WIDTH-1 downto 0);
	signal rdaddress_in,wraddress_in : STD_LOGIC_VECTOR (ADDR_WIDTH-1 DOWNTO 0);
	signal data_in_count : integer range 0 to ADDR_Relu_write_start;
	signal rd_en,wr_en: std_logic;
	
	component DP_RAM IS
		GENERIC (
			mif_fn:string:=relu_out_info.mif_fn;
			DATA_WIDTH : integer := relu_out_info.DATA_WIDTH;
			ADDR_WIDTH : integer := relu_out_info.ADDR_WIDTH;
			DATA_DEPTH : integer := relu_out_info.DATA_DEPTH
		);
		PORT
		(
			aclr		: IN STD_LOGIC  := '0';
			clock		: IN STD_LOGIC  := '1';
			data		: IN STD_LOGIC_VECTOR (DATA_WIDTH-1 DOWNTO 0);
			enable		: IN STD_LOGIC  := '1';
			rdaddress		: IN STD_LOGIC_VECTOR (ADDR_WIDTH-1 DOWNTO 0);
			rden		: IN STD_LOGIC  := '1';
			wraddress		: IN STD_LOGIC_VECTOR (ADDR_WIDTH-1 DOWNTO 0);
			wren		: IN STD_LOGIC  := '0';
			q		: OUT STD_LOGIC_VECTOR (DATA_WIDTH-1 DOWNTO 0)
		);
	end component DP_RAM;

begin

	read_addr_n<=addr_incress(read_addr,ADDR_Relu_write_start,ADDR_Relu_end);
	write_addr_n<=addr_incress(write_addr,ADDR_Relu_write_start,ADDR_Relu_end);
	rd_en<=(Relu_RD_en);
	wr_en<=(Relu_WR_en);
	--read_addr_ung <= to_unsigned(read_addr, rdaddress_in'length) when rd_en='1'else to_unsigned(ADDR_Relu_read_junk, wraddress_in'length);
	read_addr_ung <= to_unsigned(read_addr, rdaddress_in'length);
	write_addr_ung <= to_unsigned(write_addr, wraddress_in'length) when wr_en='1' else to_unsigned(ADDR_Relu_write_junk, wraddress_in'length);
	rdaddress_in<= STD_LOGIC_VECTOR(read_addr_ung);
	wraddress_in<= STD_LOGIC_VECTOR(write_addr_ung);
	
	
	
	
	
	RELU_MEM : DP_RAM 
			generic map(
				mif_fn=>relu_out_info.mif_fn,
				DATA_WIDTH => relu_out_info.DATA_WIDTH,
				ADDR_WIDTH => relu_out_info.ADDR_WIDTH,
				DATA_DEPTH => relu_out_info.DATA_DEPTH)
			port map(
				aclr=>rst_n,
				clock=>clk_in,
				data=>Relu_data_in,
				rdaddress=>rdaddress_in,
				wraddress=>wraddress_in,
				rden=>'1',
				wren=>'1',
				enable=>'1',
				q=>Relu_data_Q
			);
	process (clk_in,rst_n)
	begin
		if(rst_n='0') then
			read_addr<=ADDR_Relu_read_start;
			write_addr<=ADDR_Relu_write_start;
		elsif(rising_edge(clk_in)) then	
			if(S_rst='1') then
				read_addr<=ADDR_Relu_read_start;
				write_addr<=ADDR_Relu_write_start;
			else
				if(rd_en='1') then
					read_addr<=read_addr_n;
				end if;
				if(wr_en='1') then
					write_addr<=write_addr_n;
				end if;
			end if;
			
		end if;
	end process;
	
end architecture arch_Relu_out_FIFO;