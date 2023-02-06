--------------------------------------------------------------------------------
-- Title       : Modulo-10 Accumulator
-- Project     : Lab 8 - Frequency Counter
--------------------------------------------------------------------------------
-- File        : mod10a.vhd
-- Author      : Brian Yoon <syoon28@jhu.edu>
-- Created     : Thu Nov  5 08:05:38 2020
-- Last update : Tue Dec 15 14:14:22 2020
-- Standard    : <VHDL-2008 | VHDL-2002 | VHDL-1993 | VHDL-1987>
--------------------------------------------------------------------------------
-- Description: These will suffice as modulo-10 counters for the frequency 
-- counter
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mod10a is
	port (
		x    : in  std_logic_vector(3 downto 0);
		xe   : in  std_logic;
		y    : in  std_logic_vector(3 downto 0);
		ye   : in  std_logic;
		cin  : in  std_logic;
		cout : out std_logic;
		sum  : out std_logic_vector(3 downto 0)
	);
end entity mod10a;

architecture arch of mod10a is
	-- Bit extension to reduce chance of overflow
	signal x_prime : unsigned(4 downto 0) := "00000";
	signal y_prime : unsigned(4 downto 0) := "00000";
	signal u_sum   : unsigned(4 downto 0) := "00000";
begin
	y_prime(3 downto 0) <= unsigned(y) when ye = '1' else "0000";
	x_prime(3 downto 0) <= unsigned(x) when xe = '1' else "0000";
	sum                 <= std_logic_vector(u_sum(3 downto 0)); -- only grab lower 3 bits, since the MSB is a 
	                                                            -- bit extension to prevent overflow 
	                                                            -- during the arithmetic

	modulo_10_count : process (x_prime, y_prime, cin, u_sum)
	begin
		if ((x_prime + y_prime + ("" & cin)) >= "01010") then
			u_sum <= x_prime+y_prime+("" & cin)- "01010";
			cout  <= '1';
		else
			u_sum <= x_prime + y_prime + ("" & cin);
			cout  <= '0';
		end if;
	end process modulo_10_count;
end architecture arch;