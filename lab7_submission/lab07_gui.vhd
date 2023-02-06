library IEEE;
use IEEE.std_logic_1164.all;
library UNISIM;
use UNISIM.vcomponents.all;

entity lab07_gui is
	port(
		clk:      in    std_logic;
		ra1:      in    std_logic;
		rc1:      in    std_logic;
		rc3:      in    std_logic;
		rb:       inout std_logic_vector(7 downto 0);
		data_in:  in    std_logic_vector(7 downto 0);
		data_out: out   std_logic_vector(7 downto 0);
		trig_out: out   std_logic
	);
end lab07_gui;

architecture arch of lab07_gui is
	signal dir:    std_logic_vector(3 downto 0);
	signal ndir:   std_logic;
	signal start:  std_logic_vector(3 downto 0);
	signal shift:  std_logic_vector(3 downto 0);
	type sr is array (3 downto 0) of std_logic_vector(7 downto 0);
	signal rb_in:  sr;
	signal rb_out: std_logic_vector(7 downto 0);
begin
	------------------------------------------------------------------
	-- Control signal assignements
	------------------------------------------------------------------
	ndir<=not rc3;

	------------------------------------------------------------------
	-- I/O buffer instantiation
	------------------------------------------------------------------
	pic_rb: for index in 7 downto 0 generate
		IOBUF_rb: IOBUF generic map(DRIVE=>12,IOSTANDARD=>"LVCMOS33",
			SLEW=>"SLOW") port map(O=>rb_in(0)(index),IO=>rb(index),
			I=>rb_out(index),T=>ndir);
	end generate;

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
	-- State machine
	------------------------------------------------------------------
	process(clk)
	begin
		if rising_edge(clk) then
			-- read/write ports
			if (shift(3)='0') and (shift(2)='1') then
				if (dir(3)='0') then
					if (start(3)='1') then
						data_out<=rb_in(3);
						trig_out<='1';
					else
						trig_out<='0';
					end if;
				else
					if (start(3)='1') then
						rb_out<=data_in;
						trig_out<='0';
					else
						rb_out<=b"00000000";
						trig_out<='0';
					end if;
				end if;
			else
				trig_out<='0';
			end if;
		end if;
	end process;
end arch;
