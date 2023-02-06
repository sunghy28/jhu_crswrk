--------------------------------------------------------------------------------
-- Title       : Part A Driver Module
-- Project     : Lab 8 - Frequency Counter
--------------------------------------------------------------------------------
-- File        : lab08a.vhd
-- Author      : Brian Yoon <syoon28@jhu.edu>
-- Created     : Wed Nov  4 16:11:04 2020
-- Last update : Tue Dec  8 22:59:02 2020
-- Standard    : <VHDL-2008 | VHDL-2002 | VHDL-1993 | VHDL-1987>
--------------------------------------------------------------------------------
-- Description: Main driver module for a frequency counter using the 48MHz FPGA 
-- clock clk, and frequency synthesizer that creates a signal used to test the 
-- functionality of the frequency counter.
--------------------------------------------------------------------------------



library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library UNISIM;
use UNISIM.vcomponents.all;

entity lab08a is
	port(
		clk  : in    std_logic; -- 48 MHz USB clock
		ra1  : in    std_logic;
		rc1  : in    std_logic;
		rc3  : in    std_logic;
		rb   : inout std_logic_vector(7 downto 0);
		xin  : in    std_logic; -- Data input that we want to measure the signal of
		xout : out   std_logic  -- The output of the frequency synthesizer.
	);
end lab08a;

architecture arch of lab08a is
	component lab08_gui
		port(
			clk      : in    std_logic;
			ra1      : in    std_logic;
			rc1      : in    std_logic;
			rc3      : in    std_logic;
			rb       : inout std_logic_vector(7 downto 0);
			data_in  : in    std_logic_vector(15 downto 0);
			data_out : out   std_logic_vector(31 downto 0)
		);
	end component;
	component frequency_counter is
		port (
			clk          : in  std_logic; -- Clock of the counter.
			ref_sig      : in  std_logic;
			input        : in  std_logic; -- Data input to measure.
			scale_output : out std_logic_vector(3 downto 0);
			output       : out std_logic_vector(35 downto 0)
		);
	end component frequency_counter;
	component frequency_synthesizer is
		port (
			data_out : in  std_logic_vector(31 downto 0);
			clk      : in  std_logic;
			xout     : out std_logic
		);
	end component frequency_synthesizer;
	signal data_in    : std_logic_vector(15 downto 0);
	signal data_out   : std_logic_vector(31 downto 0);
	signal count      : unsigned(23 downto 0) := (others => '0');
	signal inc        : unsigned(23 downto 0) := "000000000000000000000001";
	signal raw_output : std_logic_vector(35 downto 0);
	signal scale      : std_logic_vector(3 downto 0);
	signal ref_sig    : std_logic := '0';
	signal sq_wave    : std_logic;
begin
		gui : lab08_gui port map(clk => clk,ra1 => ra1,rc1 => rc1,rc3 => rc3,rb => rb,
			data_in => data_in,data_out => data_out);
		f_count : frequency_counter port map (clk => clk,ref_sig => ref_sig,
			input => xin, scale_output => scale, output => raw_output);
		f_synth : frequency_synthesizer port map (data_out => data_out, clk => clk,
			xout => sq_wave);
	xout <= sq_wave;

	-- Reference interval process
	ref_interval : process (clk)
	begin
		if rising_edge(clk) then
			if (count = "111101000010001111111111") then
				count   <= "000000000000000000000000";
				ref_sig <= '1';
			else
				count   <= count + inc;
				ref_sig <= '0';
			end if;
		end if;
	end process ref_interval;

	output_formatting : process (clk, scale, raw_output, data_in)
	begin
		if rising_edge(clk) then
			if (ref_sig = '1') then
				data_in(3 downto 0) <= scale;
				case (scale) is
					when "0010" =>
						data_in(15 downto 12) <= raw_output(11 downto 8);
						data_in(11 downto 8)  <= raw_output(7 downto 4);
						data_in(7 downto 4)   <= raw_output(3 downto 0);					
					when "0011" => 
						data_in(15 downto 12) <= raw_output(15 downto 12);
						data_in(11 downto 8)  <= raw_output(11 downto 8);
						data_in(7 downto 4)   <= raw_output(7 downto 4);
					when "0100" => 
						data_in(15 downto 12) <= raw_output(19 downto 16);
						data_in(11 downto 8)  <= raw_output(15 downto 12);
						data_in(7 downto 4)   <= raw_output(11 downto 8);
					when "0101" => 
						data_in(15 downto 12) <= raw_output(23 downto 20);
						data_in(11 downto 8)  <= raw_output(19 downto 16);
						data_in(7 downto 4)   <= raw_output(15 downto 12);
					when "0110" => 
						data_in(15 downto 12) <= raw_output(27 downto 24);
						data_in(11 downto 8)  <= raw_output(23 downto 20);
						data_in(7 downto 4)   <= raw_output(19 downto 16);
					when "0111" => 
						data_in(15 downto 12) <= raw_output(31 downto 28);
						data_in(11 downto 8)  <= raw_output(27 downto 24);
						data_in(7 downto 4)   <= raw_output(23 downto 20);
					when "1000" => 
						data_in(15 downto 12) <= raw_output(35 downto 32);
						data_in(11 downto 8)  <= raw_output(31 downto 28);
						data_in(7 downto 4)   <= raw_output(27 downto 24);
					when others =>
						data_in <= data_in;
						null;
				end case;
			end if;
		end if;
	end process output_formatting;


end arch;
