--------------------------------------------------------------------------------
-- Title       : Frequency Synthesizer
-- Project     : Lab 8 - Frequency Counter
--------------------------------------------------------------------------------
-- File        : frequency_synthesizer.vhd
-- Author      : Brian Yoon <syoon28@jhu.edu>
-- Created     : Wed Nov  4 23:52:20 2020
-- Last update : Wed Dec  9 00:12:10 2020
-- Standard    : <VHDL-2008 | VHDL-2002 | VHDL-1993 | VHDL-1987>
--------------------------------------------------------------------------------
-- Description: Module that creates a square wave signal at a frequency specified 
-- by freq (which in the case of the project is given by the MATLAB GUI)
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity frequency_synthesizer is
	port (
		data_out : in  std_logic_vector(31 downto 0);
		clk      : in  std_logic;
		xout     : out std_logic
	);
end entity frequency_synthesizer;

architecture arch of frequency_synthesizer is
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
	component mod10s is
		port (
			x    : in  std_logic_vector(3 downto 0);
			y    : in  std_logic_vector(3 downto 0);
			bin  : in  std_logic;
			bout : out std_logic;
			diff : out std_logic_vector(3 downto 0)
		);
	end component mod10s;
	signal ref_sig     : std_logic := '1';
	signal bouts       : std_logic_vector(1 downto 0);
	signal cout        : std_logic_vector(7 downto 0);
	signal sums        : std_logic_vector(31 downto 0);
	signal diffs       : std_logic_vector(7 downto 0); -- difference outputs for 2 mod-10 subtractors
	signal mux_out     : std_logic_vector(7 downto 0)  := "00000000";
	signal counter_out : std_logic_vector(31 downto 0) := "00000000000000000000000000000000";
	signal sig_gen     : std_logic                     := '0';
	signal overflow    : std_logic                     := '0';
begin
	xout <= sig_gen;
	ref_sig <= '1';
	c0 : mod10a
		port map (
			x    => counter_out(3 downto 0),
			y    => data_out(3 downto 0),
			xe   => ref_sig,
			ye   => ref_sig,
			cin  => '0',
			cout => cout(0),
			sum  => sums(3 downto 0)
		);
	c1 : mod10a
		port map (
			x    => counter_out(7 downto 4),
			y    => data_out(7 downto 4),
			xe   => ref_sig,
			ye   => ref_sig,
			cin  => cout(0),
			cout => cout(1),
			sum  => sums(7 downto 4)
		);
	c2 : mod10a
		port map (
			x    => counter_out(11 downto 8),
			y    => data_out(11 downto 8),
			xe   => ref_sig,
			ye   => ref_sig,
			cin  => cout(1),
			cout => cout(2),
			sum  => sums(11 downto 8)
		);
	c3 : mod10a
		port map (
			x    => counter_out(15 downto 12),
			y    => data_out(15 downto 12),
			xe   => ref_sig,
			ye   => ref_sig,
			cin  => cout(2),
			cout => cout(3),
			sum  => sums(15 downto 12)
		);
	c4 : mod10a
		port map (
			x    => counter_out(19 downto 16),
			y    => data_out(19 downto 16),
			xe   => ref_sig,
			ye   => ref_sig,
			cin  => cout(3),
			cout => cout(4),
			sum  => sums(19 downto 16)
		);
	c5 : mod10a
		port map (
			x    => counter_out(23 downto 20),
			y    => data_out(23 downto 20),
			xe   => ref_sig,
			ye   => ref_sig,
			cin  => cout(4),
			cout => cout(5),
			sum  => sums(23 downto 20)
		);
	c6 : mod10a
		port map (
			x    => counter_out(27 downto 24),
			y    => data_out(27 downto 24),
			xe   => ref_sig,
			ye   => ref_sig,
			cin  => cout(5),
			cout => cout(6),
			sum  => sums(27 downto 24)
		);
	c7 : mod10a
		port map (
			x    => counter_out(31 downto 28),
			y    => data_out(31 downto 28),
			xe   => ref_sig,
			ye   => ref_sig,
			cin  => cout(6),
			cout => cout(7),
			sum  => sums(31 downto 28)
		);
	s0 : mod10s
		port map (
			x    => sums(27 downto 24),
			y    => "0100",
			bin  => '0',
			bout => bouts(0),
			diff => diffs(3 downto 0)
		);
	s1 : mod10s
		port map (
			x    => sums(31 downto 28),
			y    => "0010",
			bin  => bouts(0),
			bout => bouts(1),
			diff => diffs(7 downto 4)
		);
	muxes : process (diffs, bouts, sums)
	begin
		if (bouts(1) = '0') then
			-- values in counter greater than ref value, so simply copy over the difference
			mux_out  <= diffs; -- differences should be 0, so counter rolls over
			overflow <= '1';
		else
			-- borrow required - use the original output
			mux_out  <= sums(31 downto 24);
			overflow <= '0';
		end if;
	end process muxes;

	-- flip flop logic:
	flip_flops : process (clk)
	begin
		if rising_edge(clk) then
			if (overflow = '1') then
				sig_gen <= not sig_gen;
			else
				sig_gen <= sig_gen;
			end if;
			counter_out(23 downto 0)  <= sums(23 downto 0);
			counter_out(31 downto 24) <= mux_out;
		end if;
	end process flip_flops;
end architecture arch;