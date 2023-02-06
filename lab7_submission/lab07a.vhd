--------------------------------------------------------------------------------
-- Title       : Part A - RS 232 Communication Protocol
-- Project     : Lab 7 - Serial Converter
--------------------------------------------------------------------------------
-- File        : lab07a.vhd
-- Author      : Brian Yoon <syoon28@jhu.edu>
-- Company     : <Company Name>
-- Created     : Fri Nov 27 10:56:54 2020
-- Last update : Fri Dec  4 19:27:38 2020
-- Platform    : <Part Number>
-- Standard    : <VHDL-2008 | VHDL-2002 | VHDL-1993 | VHDL-1987>
--------------------------------------------------------------------------------
-- Description: Main module that implements the RS-232 asynchronous serial 
-- transmission protocol to communicate a byte between the FPGA and the PIC.
--------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity lab07a is
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
end lab07a;

architecture arch of lab07a is
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
	signal data_in       : std_logic_vector(7 downto 0);
	signal data_out      : std_logic_vector(7 downto 0);
	signal baudgen_acc   : unsigned(21 downto 0) := (others => '0'); -- extra bit to prevent overflow
	signal baudgen_acc16 : unsigned(23 downto 0) := (others => '0');
	signal baudgen_sig   : std_logic             := '0';
	signal baudgen_sig16 : std_logic             := '0';
	signal baudgen_max   : unsigned(20 downto 0);
	signal baudgen_max16 : unsigned(22 downto 0);
	signal trig_out      : std_logic;
	signal state_tx      : std_logic_vector(3 downto 0) := "0000";
	signal state_rx      : std_logic_vector(3 downto 0) := "0000";
	signal tx_sample     : std_logic_vector(3 downto 0);
	signal rx_data       : std_logic_vector(7 downto 0);
	signal data_latch: std_logic_vector(7 downto 0);
begin
		gui : lab07_gui port map(clk => clk,ra1 => ra1,rc1 => rc1,rc3 => rc3,rb => rb,
			data_in => data_in,data_out => data_out,trig_out => trig_out);

	-- Example default state of FPGA outputs. nss, sck, sdi, scl, and sda will all 
	-- be held in their idle states. 
	nss           <= '1';
	sck           <= '0';
	sdi           <= '0';
	scl           <= 'Z';
	sda           <= 'Z';
	baudgen_max   <= (others => '1');
	baudgen_max16 <= (others => '1');

	-- 21 bit accumulator that increments by 5033 should give an approximate 
	-- baudrate of 115200 bits per second.
	baudgen : process (clk)
	begin
		if rising_edge(clk) then
			-- overflow, so need to set the baud signal high and perform modulus on 
			-- accumulator count
			if (baudgen_acc + 5033 >= baudgen_max) then
				baudgen_sig <= '1';
				baudgen_acc <= baudgen_acc + 5033 - baudgen_max;
			else
				baudgen_sig <= '0';
				baudgen_acc <= baudgen_acc + 5033;
			end if;
		end if;
	end process baudgen;

	-- Samples at 16x the rate of the original baudrate, which is the convention 
	-- when sampling a receiving signal.
	baudgen16 : process (clk)
	begin
		if rising_edge(clk) then
			if (baudgen_acc16 + 161061 >= baudgen_max16) then
				baudgen_sig16 <= '1';
				baudgen_acc16 <= baudgen_acc16 + 161061 - baudgen_max16;
			else
				baudgen_sig16 <= '0';
				baudgen_acc16 <= baudgen_acc16 + 161061;
			end if;
		end if;
	end process baudgen16;

	-- State machine to facilitate transmission of byte
	FSM_TX : process (clk)
	begin
		if rising_edge(clk) then
			case (state_tx) is
				when "0000" => -- State 0: Idle
					rx <= '1';
					-- Controlled by trig out
					if (trig_out = '1') then
						data_latch <= data_out;
						state_tx <= "0001"; -- activate FSM - advance to state 1
					end if;
				-- Other states are controlled by baudgen_sig
				when "0001" => -- State 1: Start
					           -- Send zero start bit
					if (baudgen_sig = '1') then
						rx       <= '0';
						state_tx <= "0010"; -- advance to state 2
					end if;
				when "0010" => -- State 2: Bit 0
					if (baudgen_sig = '1') then
						rx       <= data_latch(0);
						state_tx <= "0011"; -- advance to state 3
					end if;
				when "0011" => -- State 3: Bit 1
					if (baudgen_sig = '1') then
						rx       <= data_latch(1);
						state_tx <= "0100"; -- advance to state 4
					end if;
				when "0100" => -- State 4: Bit 2
					if (baudgen_sig = '1') then
						rx       <= data_latch(2);
						state_tx <= "0101"; -- advance to state 5
					end if;
				when "0101" => -- State 5: Bit 3
					if (baudgen_sig = '1') then
						rx       <= data_latch(3);
						state_tx <= "0110"; -- advance to state 6
					end if;
				when "0110" => -- State 6: Bit 4
					if (baudgen_sig = '1') then
						rx       <= data_latch(4);
						state_tx <= "0111"; -- advance to state 7
					end if;
				when "0111" => -- State 7: Bit 5
					if (baudgen_sig = '1') then
						rx       <= data_latch(5);
						state_tx <= "1000"; -- advance to state 8
					end if;
				when "1000" => -- State 8: Bit 6
					if (baudgen_sig = '1') then
						rx       <= data_latch(6);
						state_tx <= "1001"; -- advance to state 9
					end if;
				when "1001" => -- State 9: Bit 7
					if (baudgen_sig = '1') then
						rx       <= data_latch(7);
						state_tx <= "1010"; -- advance to state 10
					end if;
				when others =>
					if baudgen_sig = '1' then
						rx       <= '1';
						state_tx <= "0000";
					end if;
			end case;
		end if;
	end process FSM_TX;

	-- TX signal is an external signal, so send through metastable synchronizer. 
	-- Also, need to detect the edge of the first bit sent as a falling edge.
	MS : process (clk)
	begin
		if rising_edge(clk) then
			if baudgen_sig16 = '1' then
				tx_sample <= tx_sample(2 downto 0) & tx;
			end if;
		end if;
	end process MS;

	-- State machine to facilitate receiving data from PIC.
	FSM_RX : process (clk)
	begin
		if rising_edge(clk) then
			case (state_rx) is
				when "0000" => -- State 0: inspect for start bit. Advance only if start bit is detected
					if (baudgen_sig = '1') then
						-- if (tx_sample(3) = '0' and tx_sample(2) = '1') then -- quiescent high, so 
						-- detect falling edge to activate FSM
						if (tx_sample(3) = '0') then
							state_rx <= "0001";
						end if;
					end if;
				when "0001" => -- State 1: De-serialization starts, get bit 0
					if (baudgen_sig = '1') then
						state_rx   <= "0010";
						rx_data(0) <= tx_sample(3);
					end if;
				when "0010" => -- State 2: Get Bit 1
					if (baudgen_sig = '1') then
						state_rx   <= "0011";
						rx_data(1) <= tx_sample(3);
					end if;
				when "0011" => -- State 3: Get Bit 2
					if (baudgen_sig = '1') then
						state_rx   <= "0100";
						rx_data(2) <= tx_sample(3);
					end if;
				when "0100" => -- State 4: Get Bit 3
					if (baudgen_sig = '1') then
						state_rx   <= "0101";
						rx_data(3) <= tx_sample(3);
					end if;
				when "0101" => -- State 5: Get Bit 4
					if (baudgen_sig = '1') then
						state_rx   <= "0110";
						rx_data(4) <= tx_sample(3);
					end if;
				when "0110" => -- State 6: Get Bit 5
					if (baudgen_sig = '1') then
						state_rx   <= "0111";
						rx_data(5) <= tx_sample(3);
					end if;
				when "0111" => -- State 7: Get Bit 6
					if (baudgen_sig = '1') then
						state_rx   <= "1000";
						rx_data(6) <= tx_sample(3);
					end if;
				when "1000" => -- State 8: Get Bit 7
					if (baudgen_sig = '1') then
						state_rx   <= "1001";
						rx_data(7) <= tx_sample(3);
					end if;
				when others => -- State 9: Send to GUI, set to idle state
					state_rx <= "0000";
					data_in  <= rx_data;
			end case;
		end if;
	end process FSM_RX;
end arch;
