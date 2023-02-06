--------------------------------------------------------------------------------
-- Title       : Modulo-10 Accumulator
-- Project     : Lab 8 - Frequency Counter
--------------------------------------------------------------------------------
-- File        : mod10a.vhd
-- Author      : Brian Yoon <syoon28@jhu.edu>
-- Created     : Thu Nov  5 08:05:38 2020
-- Last update : Tue Dec 15 14:33:52 2020
-- Standard    : <VHDL-2008 | VHDL-2002 | VHDL-1993 | VHDL-1987>
--------------------------------------------------------------------------------
-- Description: These will suffice as modulo-10 counters for the frequency 
-- counter
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mod10a_b is
	port (
		x    : in  std_logic_vector(3 downto 0);
		y    : in  std_logic_vector(3 downto 0);
		cin  : in  std_logic;
		cout : out std_logic;
		sum  : out std_logic_vector(3 downto 0)
	);
end entity mod10a_b;

architecture arch of mod10a_b is
	signal xprime: unsigned(4 downto 0);
	signal yprime: unsigned(4 downto 0);
	signal usum: unsigned(4 downto 0);
begin
	sum                 <= std_logic_vector(usum(3 downto 0)); -- only grab lower 3 bits, since the MSB is a 
	                                                            -- bit extension to prevent overflow 
	                                                            -- during the arithmetic

	xprime(3 downto 0) <= unsigned(x);
	yprime(3 downto 0) <= unsigned(y);

	modulo_10_count : process (xprime,yprime,cin,usum)
	begin
		if ((xprime + yprime + ("" & cin)) >= "01010") then
			usum <= xprime+yprime+("" & cin)- "01010";
			cout  <= '1';
		else
			usum <= xprime + yprime + ("" & cin);
			cout  <= '0';
		end if;
	end process modulo_10_count;
end architecture arch;