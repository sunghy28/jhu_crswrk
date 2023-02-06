--------------------------------------------------------------------------------
-- Title       : Synchronous Frequency Counter Module 
-- Project     : Lab 8 - Frequency Counter
--------------------------------------------------------------------------------
-- File        : frequency_counter_b.vhd
-- Author      : Brian Yoon <syoon28@jhu.edu>
-- Created     : Wed Nov  4 16:25:51 2020
-- Last update : Tue Dec 15 15:52:27 2020
-- Standard    : <VHDL-2008 | VHDL-2002 | VHDL-1993 | VHDL-1987>
--------------------------------------------------------------------------------
-- Description: Module that describes the frequency counter used in Lab 8, 
-- part A. Designed such that the frequency counter is clocked by the 48 MHz 
-- signal from xin and also uses 9 modulo-10 counters (which are mod10 addition 
-- blocks whose sums are registered at the rising edge clock signal). 
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity frequency_counter_b is
	port (
		req      	 : in  std_logic_vector(2 downto 0); -- Reference interval pulse
		xin        	 : in  std_logic; -- Clock signal, which is the input signal we want to measure.
		ack			 : out std_logic_vector(2 downto 0);
		output       : out std_logic_vector(35 downto 0)
	);
end entity frequency_counter_b;

architecture arch of frequency_counter_b is
	-- Modulo-10 counter
	component mod10a_b is
		port (
			x    : in  std_logic_vector(3 downto 0);
			y    : in  std_logic_vector(3 downto 0);
			cin  : in  std_logic;
			cout : out std_logic;
			sum  : out std_logic_vector(3 downto 0)
		);
	end component mod10a_b;
	signal cout : std_logic_vector(8 downto 0); -- cout(8) unused, since that is 
	                                            -- the last counter
	signal counter_out : std_logic_vector(35 downto 0) := (others => '0');
	signal sums        : std_logic_vector(35 downto 0) := (others => '0');
	type shift_reg_req is array(0 to (3)) of unsigned(2 downto 0);
	signal req_synch : shift_reg_req;
	signal ack_curr : unsigned(2 downto 0):="000";
begin
	c0 : mod10a_b
		port map (
			x    => counter_out(3 downto 0),
			y    => "0011",
			cin  => '0', 
			cout => cout(0),
			sum  => sums(3 downto 0)
		);	
	c1 : mod10a_b
		port map (
			x    => counter_out(7 downto 4),
			y    => "0000",
			cin  => cout(0),
			cout => cout(1),
			sum  => sums(7 downto 4)
		);
	c2 : mod10a_b
		port map (
			x    => counter_out(11 downto 8),
			y    => "0000",
			cin  => cout(1),
			cout => cout(2),
			sum  => sums(11 downto 8)
		);
	c3 : mod10a_b
		port map (
			x    => counter_out(15 downto 12),
			y    => "0000",
			cin  => cout(2),
			cout => cout(3),
			sum  => sums(15 downto 12)
		);
	c4 : mod10a_b
		port map (
			x   => counter_out(19 downto 16),
			y   => "0000",
			cin => cout(3),
			cout => cout(4),
			sum  => sums(19 downto 16)
		);
	c5 : mod10a_b
		port map (
			x    => counter_out(23 downto 20),
			y    => "0000",
			cin  => cout(4),
			cout => cout(5),
			sum  => sums(23 downto 20)
		);
	c6 : mod10a_b
		port map (			
			x    => counter_out(27 downto 24),
			y    => "0000",
			cin  => cout(5),
			cout => cout(6),
			sum  => sums(27 downto 24)
		);
	c7 : mod10a_b
		port map (
			x    => counter_out(31 downto 28),
			y    => "0000",
			cin  => cout(6),
			cout => cout(7),
			sum  => sums(31 downto 28)
		);
	c8 : mod10a_b
		port map (
			x    => counter_out(35 downto 32),
			y    => "0000",
			cin  => cout(7),
			cout => cout(8),
			sum  => sums(35 downto 32)
		);

	-- MS to sample req signal at xin frequency
	synchronizer : process (xin, req_synch)
	begin
		if rising_edge(xin) then
			req_synch(0) <= unsigned(req);
			req_synch(1) <= req_synch(0);
			req_synch(2) <= req_synch(1);
			req_synch(3) <= req_synch(2);
		end if;
	end process synchronizer;

	HS_req : process (xin, req_synch, counter_out)
	begin
		if rising_edge(xin) then
			if (req_synch(3) /= req_synch(2)) then
				if (req_synch(3) + 1 = req_synch(2)) then
					output <= counter_out;			
				else
					output <= (others => '0');
				end if;
				counter_out <= "000000000000000000000000000000000011";
				ack <= std_logic_vector(req_synch(2));		
			else
				counter_out <= sums;
			end if;
		end if;
	end process HS_req;
end architecture arch;