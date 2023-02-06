library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library UNISIM;
use UNISIM.vcomponents.all;

entity lab06a is
	port(
		clk:    in    std_logic;
		ra1:    in    std_logic;
		rc1:    in    std_logic;
		rc3:    in    std_logic;
		rb:     inout std_logic_vector(7 downto 0);
		but:    in    std_logic;
		data:   in    std_logic_vector(15 downto 0) -- the 16 data channels
	);
end lab06a;

architecture arch of lab06a is
	signal dir:    std_logic_vector(3 downto 0);
	signal ndir:   std_logic;
	signal start:  std_logic_vector(3 downto 0);
	signal shift:  std_logic_vector(3 downto 0);
	type sr is array (3 downto 0) of std_logic_vector(7 downto 0);
	signal rb_in:  sr;
	signal rb_out: std_logic_vector(7 downto 0);
	signal doa:    std_logic_vector(31 downto 0); -- using (7 downto 0)
	signal addra:  std_logic_vector(13 downto 0); -- using (13 downto 3)
	signal wea:    std_logic_vector(3 downto 0);
	signal dia:    std_logic_vector(31 downto 0); -- using (7 downto 0)
	signal addrb:  std_logic_vector(13 downto 0); -- using (13 downto 4)
	signal web:    std_logic_vector(3 downto 0);
	signal dib:    std_logic_vector(31 downto 0); -- using (15 downto 0)
	signal counta: unsigned(10 downto 0);
	signal countb: unsigned(9 downto 0); -- maximum of 2^10-1=1024 memory locations
	signal but_start : std_logic_vector(3 downto 0);
begin
	------------------------------------------------------------------
	-- Control signal assignements
	------------------------------------------------------------------
	ndir<=not rc3;

	addra<=std_logic_vector(counta)&"000";
	dia(7 downto 0)<=rb_in(3);
	dia(31 downto 8)<=(others=>'0');
	rb_out<=doa(7 downto 0);

	------------------------------------------------------------------
	-- I/O buffer instantiation
	------------------------------------------------------------------
	pic_rb: for index in 7 downto 0 generate
		IOBUF_rb: IOBUF generic map(DRIVE=>12,IOSTANDARD=>"LVCMOS33",
			SLEW=>"SLOW") port map(O=>rb_in(0)(index),IO=>rb(index),
			I=>rb_out(index),T=>ndir);
	end generate;

	------------------------------------------------------------------
	-- Block RAM instantiation
	------------------------------------------------------------------
	mem: RAMB16BWER
		generic map(
			DATA_WIDTH_A=>9,
			DATA_WIDTH_B=>18,
			SIM_DEVICE=>"SPARTAN6"
		)port map(
			DOA=>doa,
			DOPA=>open,
			DOB=>open,
			DOPB=>open,
			ADDRA=>addra,
			CLKA=>clk,
			ENA=>'1',
			REGCEA=>'1',
			RSTA=>'0',
			WEA=>wea,
			DIA=>dia,
			DIPA=>"0000",
			ADDRB=>addrb,
			CLKB=>clk,
			ENB=>'1',
			REGCEB=>'1',
			RSTB=>'0',
			WEB=>web,
			DIB=>dib,
			DIPB=>"0000"
		);

	------------------------------------------------------------------
	-- Shift registers for metastability
	------------------------------------------------------------------
	process(clk)
	begin
		if rising_edge(clk) then
			-- dir bit shift register for metastability
			dir<=dir(2 downto 0)&rc3;
			-- start bit shift register for metastability
			start<=start(2 downto 0)&ra1;
			-- shift bit shift register for metastability
			shift<=shift(2 downto 0)&rc1;
			-- rb bus shift register for metastability
			rb_in(3 downto 1)<=rb_in(2 downto 0);
		end if;
	end process;

	------------------------------------------------------------------
	-- Port A state machine
	------------------------------------------------------------------
	process(clk)
	begin
		if rising_edge(clk) then
			-- read/write ports
			if (shift(3)='0') and (shift(2)='1') then
				if (start(3)='1') then
					counta<=b"000_0000_0000";
				else
					counta<=counta+1;
				end if;
				if (dir(3)='0') then
					wea<=b"1111";
				else
					wea<="0000";
				end if;
			else
				wea<="0000";
			end if;
		end if;
	end process;

	----------------------------------------------------------------------------
	-- Port B connections
	----------------------------------------------------------------------------
	dib <= (15 downto 0 => '0') & data; -- Driving the 16 MSB to 0 since they are unused. 
										-- The lower 16 bits are the data bits sampled 
										-- from the PIC (ideally).
	addrb <= std_logic_vector(countb) & "0000";

	------------------------------------------------------------------
	-- Shift registers for metastability
	------------------------------------------------------------------
	process(clk)
	begin
		if rising_edge(clk) then
			but_start<=but_start(2 downto 0)&but;
		end if;
	end process;

	port_b : process (clk)
	begin	
		if rising_edge(clk) then
			if (but_start(3) = '1') then
				countb<=b"00_0000_0000";
				web <=b"1111"; -- write enable for port B set to high
			elsif (countb = b"11_1111_1111") then 	-- check for overflow, indicating 
													-- that we're at the last mem address
				web <= b"0000"; -- write enable set to low
			else
				countb<=countb+1;
			end if;
		end if;
	end process port_b;
end arch;
