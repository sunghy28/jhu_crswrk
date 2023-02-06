--------------------------------------------------------------------------------
-- Title       : Part B - SPI Protocal
-- Project     : Lab 7 - Serial Converter
--------------------------------------------------------------------------------
-- File        : lab07b.vhd
-- Author      : Brian Yoon <syoon28@jhu.edu>
-- Created     : Mon Nov 30 20:31:47 2020
-- Last update : Tue Dec  1 11:50:26 2020
-- Standard    : <VHDL-2008 | VHDL-2002 | VHDL-1993 | VHDL-1987>
--------------------------------------------------------------------------------
-- Description: Main module that implement the SPI transmission protocol to 
-- communicate a byte between the FPGA and the PIC.
--------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity lab07b is
	port(
		clk : in    std_logic;
		ra1 : in    std_logic;
		rc1 : in    std_logic;
		rc3 : in    std_logic;
		rb  : inout std_logic_vector(7 downto 0);
		rx  : out   std_logic;
		tx  : in    std_logic;
		nss : out   std_logic;
		sck : out   std_logic;
		sdi : out   std_logic;
		sdo : in    std_logic;
		scl : inout std_logic;
		sda : inout std_logic
	);
end lab07b;

architecture arch of lab07b is
	component lab07_gui
		port(
			clk      : in    std_logic;
			ra1      : in    std_logic;
			rc1      : in    std_logic;
			rc3      : in    std_logic;
			rb       : inout std_logic_vector(7 downto 0);
			data_in  : in    std_logic_vector(7 downto 0);
			data_out : out   std_logic_vector(7 downto 0);
			trig_out : out   std_logic
		);
	end component;
	signal data_in  : std_logic_vector(7 downto 0);
	signal data_out : std_logic_vector(7 downto 0);
	signal trig_out : std_logic;
	signal sck_temp : std_logic            := '0';
	signal sck_acc  : unsigned(7 downto 0) := (others => '0');
	signal state_tx : unsigned(3 downto 0) := "0000";
	signal state_rx : unsigned(3 downto 0) := "0000";
	--signal state_rx: unsigned(3 downto 0):="0000";
	signal sck_edge_detector : std_logic_vector(1 downto 0);

	signal edge  : std_logic := '0';
	signal nedge : std_logic := '0';

	signal data_sampled : std_logic_vector(7 downto 0) := "00000000";
	signal nss_temp     : std_logic;
	signal sdo_synch    : std_logic_vector(3 downto 0);
begin
		gui : lab07_gui port map(clk => clk,ra1 => ra1,rc1 => rc1,rc3 => rc3,rb => rb,
			data_in => data_in,data_out => data_out,trig_out => trig_out);

	-- These signals are not used in the SPI protocol and will therefore 
	-- be kept in their idle state
	rx  <= '1';
	scl <= 'Z';
	sda <= 'Z';
	sck <= sck_temp;
	nss <= nss_temp;

	-- SCK pulses at 100 kHz, so accumulate by half the period and invert the 
	-- signal when the accumulator rolls over at 239 (so SCK inverts at 200kHz 
	-- frequency, which simulates the 100kHz clock frequency we want to achieve).
	sck_gen : process (clk)
	begin
		if rising_edge(clk) then
			-- idle state for clock - only activated when slave select is low
			if nss_temp = '1' then 
				sck_temp <= '0';
				sck_acc  <= "00000000";
			else
				if (sck_acc = "11101111") then
					sck_acc  <= "00000000";
					sck_temp <= not sck_temp;
				else
					sck_acc  <= sck_acc + 1;
					sck_temp <= sck_temp;
				end if;
			end if;
		end if;
	end process sck_gen;

	sck_edge : process (clk)
	begin
		if rising_edge(clk) then
			sck_edge_detector(0) <= sck_temp;
			sck_edge_detector(1) <= sck_edge_detector(0);
		end if;
	end process sck_edge;

	edge  <= not sck_edge_detector(1) and sck_edge_detector(0);
	nedge <= not sck_edge_detector(0) and sck_edge_detector(1);
	synchronizer : process (clk)
	begin
		if rising_edge(clk) then
			sdo_synch <= sdo_synch(2 downto 0) & sdo;
		end if;
	end process synchronizer;

	-- State machine to handle transmitting data to PIC
	FSM_TX : process (clk)
	begin
		if rising_edge(clk) then
			case (state_tx) is
				-- State 0: Idle until trigger
				when "0000" => 
					if trig_out = '1' then
						state_tx <= "0001";      -- advance to state 1
						nss_temp <= '0';         -- bring slave select low
						sdi      <= data_out(7); -- send out msb first
					else
						nss_temp <= '1';
						sdi      <= '0';
					end if;
				-- State 1: Sample MSB bit, move to bit 6 when edge has been detected
				when "0001" =>            
					if (nedge = '1') then 
						state_tx <= "0010";
						sdi      <= data_out(6);
					end if;
				-- State 2: Sample bit 6, move to bit 5 on rising edge
				when "0010" =>            
					if (nedge = '1') then 
						state_tx <= "0011";
						sdi      <= data_out(5);
					end if;
				-- State 3: Sample bit 5, move to bit 4 on rising edge
				when "0011" =>            
					if (nedge = '1') then 
						state_tx <= "0100";
						sdi      <= data_out(4);
					end if;
				-- State 4: Sample bit 4, move to bit 3 on rising edge
				when "0100" =>            
					if (nedge = '1') then 
						state_tx <= "0101";
						sdi      <= data_out(3);
					end if;
				-- State 5: Sample bit 3, move to bit 2 on rising edge
				when "0101" =>            
					if (nedge = '1') then 
						state_tx <= "0110";
						sdi      <= data_out(2);
					end if;
				-- State 6: Sample bit 2, move to bit 1 on rising edge
				when "0110" =>            
					if (nedge = '1') then 
						state_tx <= "0111";
						sdi      <= data_out(1);
					end if;
				-- State 7: Sample bit 1, move to bit 0 on rising edge
				when "0111" =>            
					if (nedge = '1') then 
						state_tx <= "1000";
						sdi      <= data_out(0);
					end if;
				when "1000" =>
					if (nedge = '1') then
						state_tx <= "1001";
						sdi      <= '0';
					end if;
				-- Move to idle state after rising edge (in case last bit has to be sampled)
				when others => 
					state_tx <= "0000";
					nss_temp <= '1';
					sdi      <= '0';
			end case;
		end if;
	end process FSM_TX;

	-- State machine to handle receiving data from PIC
	FSM_RX : process (clk)
	begin
		if rising_edge(clk) then
			case (state_rx) is
				when "0000" => -- State 0: Idle State
					if (nss_temp = '0') then
						state_rx <= "0001";
					end if;
				when "0001" => -- State 1: Sample bit 7
					if (edge = '1') then
						state_rx        <= "0010";
						data_sampled(7) <= sdo_synch(3);
					end if;
				when "0010" => -- State 2: Sample bit 6
					if (edge = '1') then
						state_rx        <= "0011";
						data_sampled(6) <= sdo_synch(3);
					end if;
				when "0011" => -- State 3: Sample bit 5
					if (edge = '1') then
						state_rx        <= "0100";
						data_sampled(5) <= sdo_synch(3);
					end if;
				when "0100" => -- State 4: Sample bit 4
					if (edge = '1') then
						state_rx        <= "0101";
						data_sampled(4) <= sdo_synch(3);
					end if;
				when "0101" => -- State 5: Sample bit 3
					if (edge = '1') then
						state_rx        <= "0110";
						data_sampled(3) <= sdo_synch(3);
					end if;
				when "0110" => -- State 6: Sample bit 2
					if (edge = '1') then
						state_rx        <= "0111";
						data_sampled(2) <= sdo_synch(3);
					end if;
				when "0111" => -- State 7: Sample bit 1
					if (edge = '1') then
						state_rx        <= "1000";
						data_sampled(1) <= sdo_synch(3);
					end if;
				when "1000" => -- State 8: Sample bit 0
					if (edge = '1') then
						state_rx        <= "1001";
						data_sampled(0) <= sdo_synch(3);
					end if;
				when others => -- Move to idle state and store sampled data
					state_rx <= "0000";
					data_in  <= data_sampled;
			end case;
		end if;
	end process FSM_RX;
end arch;