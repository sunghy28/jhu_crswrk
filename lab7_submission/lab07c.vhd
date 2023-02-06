--------------------------------------------------------------------------------
-- Title       : Part C - I2C Protocol
-- Project     : Lab 7 - Serial Converter
--------------------------------------------------------------------------------
-- File        : lab07c.vhd
-- Author      : Brian Yoon <syoon28@jhu.edu>
-- Created     : Tue Dec  1 11:43:05 2020
-- Last update : Thu Dec  3 18:20:56 2020
-- Standard    : <VHDL-2008 | VHDL-2002 | VHDL-1993 | VHDL-1987>
--------------------------------------------------------------------------------
-- Description: Main module that implements the I2C protocol to communicate a 
-- byte between the FPGA and the PIC.
--------------------------------------------------------------------------------


library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity lab07c is
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
end lab07c;

architecture arch of lab07c is
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
	signal data_in      : std_logic_vector(7 downto 0);
	signal data_out     : std_logic_vector(7 downto 0);
	signal data_temp    : std_logic_vector(7 downto 0);
	signal scl_acc      : unsigned(7 downto 0)         := (others => '0');
	signal wait_5_acc   : unsigned(7 downto 0)         := (others => '0');
	signal wait_2_5_acc : unsigned(6 downto 0)         := (others => '0');
	signal state_main   : std_logic_vector(7 downto 0) := "00000000";
	signal sda_synch    : std_logic_vector(3 downto 0);
	signal scl_synch    : std_logic_vector(3 downto 0);

	signal rw        : std_logic;
	signal wait_5    : std_logic;
	signal wait_2_5  : std_logic;
	signal trig_out  : std_logic;
	signal scl_edge  : std_logic;
	signal scl_nedge : std_logic;
	signal active    : std_logic := '0'; -- 0 for idle, 1 for active transmission
begin
		--------------------------------------------------------------------------------
		-- COMPONENTS AND PARAMETERS
		--------------------------------------------------------------------------------
		gui : lab07_gui port map(clk => clk,ra1 => ra1,rc1 => rc1,rc3 => rc3,rb => rb,
			data_in => data_in,data_out => data_out,trig_out => trig_out);

	-- These signals are not in use, and therefore will be kept in idle state
	rx  <= '1';
	nss <= '1';
	sck <= '0';
	sdi <= '0';
	--------------------------------------------------------------------------------
	-- SCL GENERATION
	--------------------------------------------------------------------------------
	scl_gen : process (clk)
	begin
		if rising_edge(clk) then
			-- Only accumulate if a transmission is in progress
			if (active = '1') then
				-- When count rolls over, set the SCL to either a high 
				-- impedance state or down to 0, depending on the previous 
				-- state of SCL (we're inverting the signal, but cannot 
				-- explicitly drive SCL to '1', and must first drive SCL to 
				-- 'Z', which will be pulled up by the pull-up resistors in 
				-- the PIC).
				if scl_acc = "11101111" then
					scl_acc <= "00000000";
					-- Drive SCL to either a high Z state or '0':
					if (scl = '1') then
						scl <= '0';
					else
						scl <= 'Z';
					end if;
				else
					-- We must first ensure that the accumulation only occurs 
					-- when SCL is at a stable state.
					if (scl_synch(3) = '1' or scl_synch(3) = '0') then
						scl_acc <= scl_acc+1;
					end if;
				end if;
			-- Else, leave in an idle state (scl gets driven to high Z and the 
			-- accumulator count is set to 0)
			else
				scl_acc <= (others => '0');
				scl     <= 'Z';
			end if;
		end if;
	end process scl_gen;

	--------------------------------------------------------------------------------
	-- TIMERS
	--------------------------------------------------------------------------------
	-- Counters that make the FSM wait for 2.5 or 5 us, which is required 
	-- to ensure signal has been held for long enough. This is for the SDA 
	-- signal, since SCL already inverts every 5us (which is half the period 
	-- of the clock that is used for this process).
	process (clk)
	begin
		if rising_edge(clk) then
			if (wait_5 = '1') then
				wait_5_acc <= "00000000";
			else
				wait_5_acc <= (others => '0');
				if (wait_5_acc = "11101111") then
					wait_5_acc <= wait_5_acc;
				else
					wait_5_acc <= wait_5_acc+1;
				end if;
			end if;
		end if;
	end process;

	process (clk)
	begin
		if rising_edge(clk) then
			if (wait_2_5 = '1') then
				wait_2_5_acc <= "0000000";
			else
				if (wait_2_5_acc < "1110111") then
					wait_2_5_acc <= wait_2_5_acc + 1;
				end if;
			end if;
		end if;
	end process;

	--------------------------------------------------------------------------------
	-- SYNCHRONIZER
	--------------------------------------------------------------------------------
	synchronizer : process (clk)
	begin
		if rising_edge(clk) then
			sda_synch <= sda_synch(2 downto 0) & sda;
			scl_synch <= scl_synch(2 downto 0) & scl;
		end if;
	end process synchronizer;
	scl_edge  <= not scl_synch(3) and scl_synch(2);
	scl_nedge <= not scl_synch(2) and scl_synch(3);
	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	-- I2C FSM:
	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	FSM_MAIN : process (clk)
	begin
		if rising_edge(clk) then
			case (state_main) is
				-- STATE 0: Idle state, advance only when trig_out is asserted.
				when "00000000" =>
					if trig_out = '1' then
						state_main <= "00000001";
						-- Lower SDA and wait for 2.5 us before starting the 
						-- SCL generation:
						sda      <= '0';
						rw       <= '0';
						wait_2_5 <= '0';
					else
						sda    <= 'Z';
						active <= '0';
					end if;
				-- STATE 1: Wait 2.5 us then assert active to start 
				-- SCL generation. Also move to STATE A1
				when "00000001" =>
					if (wait_2_5_acc = "1110111") then
						wait_2_5   <= '1';
						active     <= '1';
						state_main <= "00100001";
					end if;
				--------------------------------------------------------------------------------
				-- ADDRESS TRANSMISSION START
				--------------------------------------------------------------------------------
				-- STATE A1.1: Start of address transmission
				when "00100001" =>
					if (scl_nedge = '1') then
						wait_2_5   <= '0';
						state_main <= "00101001";
					end if;
				-- STATE A1.2: Send address bit 6
				when "00101001" =>
					-- Once 2.5 us has passed, assert SDA, then wait for the 
					-- signal to stabilize, and then wait for 5 more us
					if (wait_2_5_acc = "1110111") then
						sda        <= 'Z';
						wait_2_5   <= '1';
						state_main <= "00110001";
					end if;
				-- STATE A1.3: Wait for SDA to stabilize, and then count to 5
				when "00110001" =>
					if (sda_synch(3) = '1') then
						state_main <= "00100010";
						wait_5     <= '0';
					end if;
				-- STATE A2.1
				when "00100010" =>
					if (wait_5_acc = "11101111") then
						if (scl_nedge = '1') then
							wait_5     <= '1';
							wait_2_5   <= '0';
							state_main <= "00101010";
						end if;
					end if;
				-- STATE A2.2: Send address bit 5
				when "00101010" =>
					if (wait_2_5_acc = "1110111") then
						sda        <= '0';
						state_main <= "00110010";
						wait_2_5   <= '1';
					end if;
				-- STATE A2.3
				when "00110010" =>
					if (sda_synch(3) = '1') then
						state_main <= "00100011";
						wait_5     <= '0';
					end if;
				-- STATE A3.1
				when "00100011" =>
					if (wait_5_acc = "11101111") then
						if (scl_nedge = '1') then
							wait_2_5   <= '0';
							wait_5     <= '1';
							state_main <= "00101011";
						end if;
					end if;
				-- STATE A3.2: Send address bit 4
				when "00101011" =>
					if (wait_2_5_acc = "1110111") then
						sda        <= '1';
						state_main <= "00110011";
						wait_2_5   <= '1';
					end if;
				-- STATE A3.3
				when "00110011" =>
					if (sda_synch(3) = '1') then
						state_main <= "00100100";
						wait_5     <= '0';
					end if;
				-- STATE A4.1: Address bits 0 to 3 are all 0s, so consolidate into 
				-- one state.
				when "00100100" =>
					if (wait_5_acc = "11101111") then
						if (scl_nedge = '1') then
							wait_5     <= '1';
							wait_2_5   <= '0';
							state_main <= "00101100";
						end if;
					end if;
				-- STATE A4.2: Wait 2.5 us and then send '0' (No transitions, 
				-- but timing should be kept).
				when "00101100" =>
					if (wait_2_5_acc = "1110111") then
						sda        <= '0';
						wait_5     <= '0';
						wait_2_5   <= '1';
						state_main <= "00100101";
					end if;
				-- STATE A5.1: Address bits 0 to 3 are all 0s, so consolidate into 
				-- one state.
				when "00100101" =>
					if (wait_5_acc = "11101111") then
						if (scl_nedge = '1') then
							wait_5     <= '1';
							wait_2_5   <= '0';
							state_main <= "00101101";
						end if;
					end if;
				-- STATE A5.2: Wait 2.5 us and then send '0' (No transitions, 
				-- but timing should be kept).
				when "00101101" =>
					if (wait_2_5_acc = "1110111") then
						sda        <= '0';
						wait_5     <= '0';
						wait_2_5   <= '1';
						state_main <= "00100110";
					end if;
				-- STATE A6.1: Address bits 0 to 3 are all 0s, so consolidate into 
				-- one state.
				when "00100110" =>
					if (wait_5_acc = "11101111") then
						if (scl_nedge = '1') then
							wait_5     <= '1';
							wait_2_5   <= '0';
							state_main <= "00101110";
						end if;
					end if;
				-- STATE A6.2: Wait 2.5 us and then send '0' (No transitions, 
				-- but timing should be kept).
				when "00101110" =>
					if (wait_2_5_acc = "1110111") then
						sda        <= '0';
						wait_5     <= '0';
						wait_2_5   <= '1';
						state_main <= "00100111";
					end if;
				-- STATE A7.1: Address bits 0 to 3 are all 0s, so consolidate into 
				-- one state.
				when "00100111" =>
					if (wait_5_acc = "11101111") then
						if (scl_nedge = '1') then
							wait_5     <= '1';
							wait_2_5   <= '0';
							state_main <= "00101111";
						end if;
					end if;
				-- STATE A7.2: Wait 2.5 us and then send '0' (No transitions, 
				-- but timing should be kept).
				when "00101111" =>
					if (wait_2_5_acc = "1110111") then
						sda        <= '0';
						wait_5     <= '0';
						wait_2_5   <= '1';
						state_main <= "00000010";
					end if;
				--------------------------------------------------------------------------------
				-- ADDRESS TRANSMISSION END
				--------------------------------------------------------------------------------
				-- STATE 2: FPGA is currently driving the SDA line to send the 
				-- address bits. On the 8th clock cycle (which is the 8th state 
				-- of the FSM that handles the address transmission), the main 
				-- FSM (this one) will send a read/write bit that is low to signal 
				-- to the PIC that the FPGA wants to send bits to store at that 
				-- memory address.
				when "00000010" =>
					if (wait_5_acc = "11101111") then
						if (scl_nedge = '1') then
							-- Advance to wait state
							state_main <= "00000011";
							-- Start the counter for 2.5 us
							wait_2_5 <= '0';
							wait_5   <= '1';
						end if;
					end if;
				when "00000011" =>
					if (wait_2_5_acc = "1110111") then
						wait_2_5 <= '1';
						if (rw = '1') then
							sda        <= 'Z';
							state_main <= "00000100";
						else
							sda        <= '0';
							state_main <= "00000100";
						end if;
					end if;
				when "00000100" =>
					if (sda_synch(3) = '1' or sda_synch(3) = '0') then
						wait_5     <= '0';
						state_main <= "00000101";
					end if;
				-- STATE 4: Wait for ACK signal to be received. If ACK is low, then 
				-- that means that the addresses have been successfully received by 
				-- the PIC and we can start transmitting data bits to the PIC. 
				when "00000101" =>
					-- Recv'd acknowledge from PIC - move on to TX first
					if (wait_5_acc = "11101111") then
						if (scl_edge = '1') then
							state_main <= "00000110";
							wait_2_5   <= '0';
						end if;
					end if;
				when "00000110" =>
					if (wait_2_5_acc = "1110111") then
						if (sda_synch(3) = '0') then
							if (rw = '1') then
								state_main <= "10000001";
							else
								state_main <= "01000001";
							end if;
							wait_2_5 <= '1';
						else
							state_main <= "00010100";
						end if;
					end if;
				--------------------------------------------------------------------------------
				-- TX START
				--------------------------------------------------------------------------------
				-- STATE T1.1: 
				when "01000001" =>
					if (scl_nedge = '1') then
						wait_2_5   <= '0';
						state_main <= "01010001";
					end if;
				-- STATE T1.2
				when "01010001" =>
					if(wait_2_5_acc = "1110111") then
						wait_2_5 <= '1';
						if (data_out(7) = '1') then
							sda        <= 'Z';
							state_main <= "01100001";
						else
							sda        <= data_out(7);
							wait_5     <= '0';
							state_main <= "01000010";
						end if;
					end if;
				-- STATE T1.3
				when "01100001" =>
					if(sda_synch(3) = '1') then
						wait_5     <= '0';
						state_main <= "01000010";
					end if;
				-- STATE T2.1
				when "01000010" =>
					if (wait_5_acc = "11101111") then
						if (scl_nedge = '1') then
							wait_2_5   <= '0';
							wait_5     <= '1';
							state_main <= "01010010";
						end if;
					end if;
				-- STATE T2.2
				when "01010010" =>
					if(wait_2_5_acc = "1110111") then
						wait_2_5 <= '1';
						if (data_out(6) = '1') then
							sda        <= 'Z';
							state_main <= "01100010";
						else
							sda        <= data_out(6);
							state_main <= "01000011";
							wait_5     <= '0';
						end if;
					end if;
				-- STATE T2.3
				when "01100010" =>
					if (sda_synch(3) = '1') then
						state_main <= "01000011";
						wait_5     <= '0';
					end if;
				-- STATE T3.1
				when "01000011" =>
					if (wait_5_acc = "11101111") then
						if (scl_nedge = '1') then
							wait_2_5   <= '0';
							wait_5     <= '1';
							state_main <= "01010011";
						end if;
					end if;
				-- STATE T3.2
				when "01010011" =>
					if(wait_2_5_acc = "1110111") then
						wait_2_5 <= '1';
						if (data_out(5) = '1') then
							sda        <= 'Z';
							state_main <= "01100011";
						else
							sda <= data_out(5);
							--sda <= '0';
							state_main <= "01000100";
							wait_5     <= '0';
						end if;
					end if;
				-- STATE T3.3
				when "01100011" =>
					if (sda_synch(3) = '1') then
						state_main <= "01000100";
						wait_5     <= '0';
					end if;
				-- STATE T4.1
				when "01000100" =>
					if (wait_5_acc = "11101111") then
						if (scl_nedge = '1') then
							wait_2_5   <= '0';
							wait_5     <= '1';
							state_main <= "01010100";
						end if;
					end if;
				-- STATE T4.2
				when "01010100" =>
					if(wait_2_5_acc = "1110111") then
						wait_2_5 <= '1';
						if (data_out(4) = '1') then
							sda        <= 'Z';
							state_main <= "01100100";
						else
							sda        <= data_out(4);
							wait_5     <= '0';
							state_main <= "01000101";
						end if;
					end if;
				-- STATE T4.3
				when "01100100" =>
					if (sda_synch(3) = '1') then
						wait_5     <= '0';
						state_main <= "01000101";
					end if;
				-- STATE T5.1
				when "01000101" =>
					if (wait_5_acc = "11101111") then
						if (scl_nedge = '1') then
							wait_2_5   <= '0';
							wait_5     <= '1';
							state_main <= "01010101";
						end if;
					end if;
				-- STATE T5.2
				when "01010101" =>
					if(wait_2_5_acc = "1110111") then
						wait_2_5 <= '1';
						if (data_out(3) = '1') then
							sda        <= 'Z';
							state_main <= "01100101";
						else
							sda        <= data_out(3);
							wait_5     <= '0';
							state_main <= "01000110";
						end if;
					end if;
				-- STATE T5.3
				when "01100101" =>
					if (sda_synch(3) = '1') then
						wait_5     <= '0';
						state_main <= "01000110";
					end if;
				-- STATE T6.1
				when "01000110" =>
					if (wait_5_acc = "11101111") then
						if (scl_nedge = '1') then
							wait_2_5   <= '0';
							wait_5     <= '1';
							state_main <= "01010110";
						end if;
					end if;
				-- STATE T6.2
				when "01010110" =>
					if(wait_2_5_acc = "1110111") then
						wait_2_5 <= '1';
						if (data_out(2) = '1') then
							sda        <= 'Z';
							state_main <= "01100110";
						else
							sda        <= data_out(2);
							wait_5     <= '0';
							state_main <= "01000111";
						end if;
					end if;
				-- STATE T6.3
				when "01100110" =>
					if (sda_synch(3) = '1') then
						wait_5     <= '0';
						state_main <= "01000111";
					end if;
				-- STATE T7.1
				when "01000111" =>
					if (wait_5_acc = "11101111") then
						if (scl_nedge = '1') then
							wait_2_5   <= '0';
							wait_5     <= '1';
							state_main <= "01010111";
						end if;
					end if;
				--STATE T7.2
				when "01010111" =>
					if(wait_2_5_acc = "1110111") then
						wait_2_5 <= '1';
						if (data_out(1) = '1') then
							sda        <= 'Z';
							state_main <= "01100111";
						else
							sda        <= data_out(1);
							wait_5     <= '0';
							state_main <= "01001000";
						end if;
					end if;
				-- STATE T7.3
				when "01100111" =>
					if (sda_synch(3) = '1') then
						wait_5     <= '0';
						state_main <= "01001000";
					end if;
				-- STATE T8.1
				when "01001000" =>
					if (wait_5_acc = "11101111") then
						if (scl_nedge = '1') then
							wait_2_5   <= '0';
							wait_5     <= '1';
							state_main <= "01011000";
						end if;
					end if;
				-- STATE T8.2
				when "01011000" =>
					if(wait_2_5_acc = "1110111") then
						wait_2_5 <= '1';
						if (data_out(0) = '1') then
							sda        <= 'Z';
							state_main <= "01101000";
						else
							sda        <= data_out(0);
							wait_5     <= '0';
							state_main <= "00000111";
						end if;
					end if;
				-- STATE T8.3
				when "01101000" =>
					if (sda_synch(3) = '1') then
						wait_5     <= '0';
						state_main <= "00000111";
					end if;
				--------------------------------------------------------------------------------
				-- TX END
				--------------------------------------------------------------------------------
				-- STATE 6: FPGA is currently driving the SDA line to write 
				-- data to the PIC. Waiting for "ACK" message from the PIC 
				-- at the 9th clock cycle. If "ACK" is high, then communication 
				-- must be aborted, which is done by setting state_main to the 
				-- default state.
				when "00000111" =>
					if (wait_5_acc = "11101111") then
						if (scl_edge = '1') then
							state_main <= "00001000";
							wait_2_5   <= '0';
						end if;
					end if;
				when "00001000" =>
					if (wait_2_5_acc = "111011") then
						if (sda_synch(3) = '0') then
							state_main <= "00001010";
							wait_5     <= '1';
						else
							state_main <= "00010100";
						end if;
					end if;
				-- STATE 7: FPGA does a start-restart event for the data 
				-- receiving portion of the transaction
				when "00001010" =>
					if (scl_nedge = '1') then
						wait_2_5   <= '0';
						state_main <= "00001011";
					end if;
				-- STATE 8:
				when "00001011" =>
					if (wait_2_5_acc = "1110111") then
						active     <= '0';
						sda        <= 'Z';
						wait_2_5   <= '1';
						state_main <= "00001100";
					end if;
				-- STATE 9:
				when "00001100" =>
					if (sda_synch(3) = '1') then
						wait_5     <= '0';
						state_main <= "00001101";
					end if;
				-- STATE 10:
				when "00001101" =>
					if (wait_5_acc = "11101111") then
						if (scl_synch(3) = '1') then
							sda        <= '0';
							rw         <= '1';
							wait_2_5   <= '0';
							state_main <= "00001110";
						end if;
					end if;
				-- STATE 11: Wait 2.5 us then assert active to start 
				-- SCL generation. Also move to STATE A1
				when "00001110" =>
					if (wait_2_5_acc = "1110111") then
						wait_2_5   <= '1';
						active     <= '1';
						state_main <= "00100001";
					end if;
				--------------------------------------------------------------------------------
				-- RX START
				--------------------------------------------------------------------------------
				-- STATE R1.1
				when "10000001" =>
					if (scl_edge = '1') then
						wait_2_5   <= '0';
						state_main <= "10010001";
					end if;
				-- STATE R1.2
				when "10010001" =>
					if (wait_2_5_acc = "1110111") then
						wait_2_5     <= '1';
						state_main   <= "10000010";
						data_temp(7) <= sda_synch(3);
					end if;
				-- STATE R2.1
				when "10000010" =>
					if (scl_edge = '1') then
						wait_2_5   <= '0';
						state_main <= "10010010";
					end if;
				-- STATE R2.2
				when "10010010" =>
					if (wait_2_5_acc = "1110111") then
						wait_2_5     <= '1';
						state_main   <= "10000011";
						data_temp(6) <= sda_synch(3);
					end if;
				-- STATE R3.1
				when "10000011" =>
					if (scl_edge = '1') then
						wait_2_5   <= '0';
						state_main <= "10010011";
					end if;
				-- STATE R3.2
				when "10010011" =>
					if (wait_2_5_acc = "1110111") then
						wait_2_5     <= '1';
						state_main   <= "10000100";
						data_temp(5) <= sda_synch(3);
					end if;
				-- STATE R4.1
				when "10000100" =>
					if (scl_edge = '1') then
						wait_2_5   <= '0';
						state_main <= "10010100";
					end if;
				-- STATE R4.2
				when "10010100" =>
					if (wait_2_5_acc = "1110111") then
						wait_2_5     <= '1';
						state_main   <= "10000101";
						data_temp(4) <= sda_synch(3);
					end if;
				-- STATE R5.1
				when "10000101" =>
					if (scl_edge = '1') then
						wait_2_5   <= '0';
						state_main <= "10010101";
					end if;
				-- STATE R5.2
				when "10010101" =>
					if (wait_2_5_acc = "1110111") then
						wait_2_5     <= '1';
						state_main   <= "10000110";
						data_temp(3) <= sda_synch(3);
					end if;
				-- STATE R6.1
				when "10000110" =>
					if (scl_edge = '1') then
						wait_2_5   <= '0';
						state_main <= "10010110";
					end if;
				-- STATE R6.2
				when "10010110" =>
					if (wait_2_5_acc = "1110111") then
						wait_2_5     <= '1';
						state_main   <= "10000111";
						data_temp(2) <= sda_synch(3);
					end if;
				-- STATE R7.1
				when "10000111" =>
					if (scl_edge = '1') then
						wait_2_5   <= '0';
						state_main <= "10010111";
					end if;
				-- STATE R7.2
				when "10010111" =>
					if (wait_2_5_acc = "1110111") then
						wait_2_5     <= '1';
						state_main   <= "10001000";
						data_temp(1) <= sda_synch(3);
					end if;
				-- STATE R8.1
				when "10001000" =>
					if (scl_edge = '1') then
						wait_2_5   <= '0';
						state_main <= "10011000";
					end if;
				-- STATE R8.2
				when "10011000" =>
					if (wait_2_5_acc = "1110111") then
						wait_2_5     <= '1';
						state_main   <= "00001111";
						data_temp(0) <= sda_synch(3);
					end if;
				--------------------------------------------------------------------------------
				-- RX END
				--------------------------------------------------------------------------------
				-- STATE 12: On next SCL = '0', FPGA sends ACK signal, which is 
				-- a '1'.
				when "00001111" =>
					if (scl_nedge = '1') then
						wait_2_5   <= '0';
						state_main <= "00010000";
					end if;
				-- STATE 13:
				when "00010000" =>
					if (wait_2_5_acc = "1110111") then
						sda        <= 'Z';
						wait_2_5   <= '1';
						state_main <= "00010100";
					end if;
				-- STATE 14;
				when "00010001" =>
					if (sda_synch(3) = '1') then
						wait_5     <= '0';
						state_main <= "00010010";
					end if;
				-- STATE 15:
				when "00010010" =>
					if (wait_5_acc <= "11101111") then
						wait_5     <= '1';
						sda        <= '0';
						wait_2_5   <= '0';
						state_main <= "00010011";
					end if;
				when "00010011" =>
					if (wait_2_5_acc = "1110111") then
						wait_2_5   <= '1';
						active     <= '0';
						wait_5     <= '0';
						state_main <= "00010100";
					end if;
				--------------------------------------------------------------------------------
				-- CLEANUP
				--------------------------------------------------------------------------------
				when "00010100" =>
					if (wait_5_acc = "11101111") then
						if (scl_synch(3) = '1') then
							sda        <= 'Z';
							wait_5     <= '1';
							state_main <= "00010101";
						end if;
					end if;
				when "00010101" =>
					if (sda_synch(3) = '1') then
						wait_5     <= '0';
						state_main <= "00010110";
					end if;
				when "00010110" =>
					if (wait_5_acc = "11101111") then
						wait_5     <= '1';
						state_main <= "00000000";
						data_in    <= data_temp;
					end if;
				when others =>
					state_main <= "00000000";
			end case;
		end if;
	end process FSM_MAIN;
end arch;

