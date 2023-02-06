--------------------------------------------------------------------------------
-- Title       : Synchronous Frequency Counter Module 
-- Project     : Lab 8 - Frequency Counter
--------------------------------------------------------------------------------
-- File        : frequency_counter.vhd
-- Author      : Brian Yoon <syoon28@jhu.edu>
-- Created     : Wed Nov  4 16:25:51 2020
-- Last update : Tue Dec  8 23:02:28 2020
-- Standard    : <VHDL-2008 | VHDL-2002 | VHDL-1993 | VHDL-1987>
--------------------------------------------------------------------------------
-- Description: Module that describes the frequency counter used in Lab 8, 
-- part A. Designed such that the frequency counter is clocked by the 48 MHz 
-- signal from clk and also uses 9 modulo-10 counters (which are mod10 addition 
-- blocks whose sums are registered at the rising edge clock signal). 
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity frequency_counter is
	port (
		clk          : in  std_logic; -- Clock of the counter.
		ref_sig      : in  std_logic; -- Reference interval pulse
		input        : in  std_logic; -- Data input to measure.
		scale_output : out std_logic_vector(3 downto 0);
		output       : out std_logic_vector(35 downto 0) -- 8 4-bit digits that 
	                                                     -- represents the frequency (we 
	                                                     -- do not need the 9th counter 
	                                                     -- for Part A since this version 
	                                                     -- of the frequency counter can 
	                                                     -- only count up to 24 MHz).
	);
end entity frequency_counter;

architecture arch of frequency_counter is
	-- Modulo-m counter
	component mod10a is
		port (
			x    : in  std_logic_vector(3 downto 0);
			xe   : in  std_logic;
			y    : in  std_logic_vector(3 downto 0);
			ye   : in  std_logic;
			cin  : in  std_logic;
			cout : out std_logic;
			sum  : out std_logic_vector(3 downto 0)
		);
	end component mod10a;
	signal cout : std_logic_vector(8 downto 0); -- cout(7) unused, since that is 
	                                            -- the last counter
	signal edge_reg    : std_logic_vector(1 downto 0)  := (others => '0');
	signal counter_out : std_logic_vector(35 downto 0) := (others => '0');
	signal sums        : std_logic_vector(35 downto 0) := (others => '0');
	signal edge        : std_logic                     := '0';
	signal to_measure  : std_logic_vector(3 downto 0);
	signal scale       : std_logic_vector(3 downto 0) := "0010";
begin
	output <= counter_out;
	scale_output <= scale;
	c0 : mod10a
		port map (
			x    => counter_out(3 downto 0),
			y    => "0011", -- add 2 more to cin every edge detection so each detection increments by 3.
			xe   => '1',
			ye   => edge,
			cin  => '0',
			cout => cout(0),
			sum  => sums(3 downto 0)
		);
	c1 : mod10a
		port map (
			x    => counter_out(7 downto 4),
			y    => "0000",
			xe   => '1',
			ye   => '1',
			cin  => cout(0),
			cout => cout(1),
			sum  => sums(7 downto 4)
		);
	c2 : mod10a
		port map (
			x    => counter_out(11 downto 8),
			y    => "0000",
			xe   => '1',
			ye   => '1',
			cin  => cout(1),
			cout => cout(2),
			sum  => sums(11 downto 8)
		);
	c3 : mod10a
		port map (
			x    => counter_out(15 downto 12),
			y    => "0000",
			xe   => '1',
			ye   => '1',
			cin  => cout(2),
			cout => cout(3),
			sum  => sums(15 downto 12)
		);
	c4 : mod10a
		port map (
			x   => counter_out(19 downto 16),
			y   => "0000",
			xe  => '1',
			ye  => '1',
			cin => cout(3),

			cout => cout(4),
			sum  => sums(19 downto 16)
		);
	c5 : mod10a
		port map (
			x    => counter_out(23 downto 20),
			y    => "0000",
			xe   => '1',
			ye   => '1',
			cin  => cout(4),
			cout => cout(5),
			sum  => sums(23 downto 20)
		);
	c6 : mod10a
		port map (
			x    => counter_out(27 downto 24),
			y    => "0000",
			xe   => '1',
			ye   => '1',
			cin  => cout(5),
			cout => cout(6),
			sum  => sums(27 downto 24)
		);
	c7 : mod10a
		port map (
			x    => counter_out(31 downto 28),
			y    => "0000",
			xe   => '1',
			ye   => '1',
			cin  => cout(6),
			cout => cout(7),
			sum  => sums(31 downto 28)
		);
	c8 : mod10a
		port map (
			x    => counter_out(35 downto 32),
			y    => "0000",
			xe   => '1',
			ye   => '1',
			cin  => cout(7),
			cout => cout(8),
			sum  => sums(35 downto 32)
		);
	-- scale mapping based on has_value signal:
	scale_mapping : process (counter_out, scale)
	begin
		--if rising_edge(clk) then
		if (unsigned(counter_out(35 downto 32)) > "0000") then
			scale <= "1000";
		elsif (unsigned(counter_out(31 downto 28)) > "0000") then
			scale <= "0111";
		elsif (unsigned(counter_out(27 downto 24)) > "0000") then
			scale <= "0110";
		elsif (unsigned(counter_out(23 downto 20)) > "0000") then
			scale <= "0101";
		elsif (unsigned(counter_out(19 downto 16)) > "0000") then
			scale <= "0100";
		elsif (unsigned(counter_out(15 downto 12)) > "0000") then
			scale <= "0011";
		else
			scale <= "0010";
		end if;
	--end if;
	end process scale_mapping;

	-- Flip flops for counter outputs:
	flip_flops : process (clk, ref_sig)
	begin
		if rising_edge(clk) then
			if (ref_sig = '1') and (edge = '1' ) then
				counter_out <= "000000000000000000000000000000000011";
			elsif (ref_sig = '1') then
				counter_out <= (others => '0');
			else
				counter_out <= sums;
			end if;
		end if;
	end process flip_flops;

	-- Metastability for the input (which comes from xin)
	synchronizer : process (clk)
	begin
		if rising_edge(clk) then
			to_measure <= to_measure(2 downto 0) & input;
		end if;
	end process synchronizer;

	-- Edge Detection Process:
	edge_detection : process (clk)
	begin
		if rising_edge(clk) then
			if ((to_measure(3)='0') and (to_measure(2)='1')) then
				edge <= '1';
			else
				edge <= '0';
			end if;
		end if;
	end process edge_detection;
end architecture arch;