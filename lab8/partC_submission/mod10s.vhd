--------------------------------------------------------------------------------
-- Title       : Modulo-10 Subtractor
-- Project     : Lab 8 - Frequency Counter
--------------------------------------------------------------------------------
-- File        : mod10s.vhd
-- Author      : Brian Yoon <syoon28@jhu.edu>
-- Created     : Thu Nov  5 10:17:48 2020
-- Last update : Sat Nov  7 13:33:30 2020
-- Standard    : <VHDL-2008 | VHDL-2002 | VHDL-1993 | VHDL-1987>
--------------------------------------------------------------------------------
-- Description: Modulo-10 subtractor to be used in frequency synthesis 
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mod10s is
	port (
		x    : in  std_logic_vector(3 downto 0);
		y    : in  std_logic_vector(3 downto 0);
		bin  : in  std_logic;                   -- signal indicating that previous component needs to borrow
		bout : out std_logic;                   -- signal indicating that this component needs to borrow
		diff : out std_logic_vector(3 downto 0) -- difference
	);
end entity mod10s;

architecture arch of mod10s is
	signal modulo : unsigned(4 downto 0) := "01010";
	signal u_diff : unsigned(4 downto 0);
begin
	modulo <= "01010";
	diff   <= std_logic_vector(u_diff(3 downto 0));
	modulo_10_subtraction : process(x, y, bin, modulo)
	begin
		if ((modulo + unsigned(x) - unsigned(y) - (""&bin)) < modulo) then
			u_diff <= modulo +unsigned(x) - unsigned(y) -(""&bin) ;
			bout   <= '1'; -- request borrowing
		else
			u_diff <= "00000" + unsigned(x) - unsigned(y) - (""&bin);
			bout   <= '0'; -- no need to borrow 
		end if;
	end process modulo_10_subtraction;
end architecture arch;
