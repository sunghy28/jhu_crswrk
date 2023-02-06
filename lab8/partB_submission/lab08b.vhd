library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library UNISIM;
use UNISIM.vcomponents.all;

entity lab08b is
	port(
		clk  : in    std_logic; -- 48 MHz USB clock
		ra1  : in    std_logic;
		rc1  : in    std_logic;
		rc3  : in    std_logic;
		rb   : inout std_logic_vector(7 downto 0);
		xin  : in    std_logic; -- Data input that we want to measure the signal of
		xout : out   std_logic  -- The output of the frequency synthesizer.
	);
end lab08b;

architecture arch of lab08b is
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
	component frequency_counter_b is
		port (
			xin          : in  std_logic; -- Clock of the counter.
			req		     : in  std_logic_vector(2 downto 0);
			ack          : out  std_logic_vector(2 downto 0); -- Data input to measure.
			output       : out std_logic_vector(35 downto 0)
		);
	end component frequency_counter_b;
	component frequency_synthesizer_b is
		port (
			data_out : in  std_logic_vector(31 downto 0);
			clk      : in  std_logic;
			xout     : out std_logic
		);
	end component frequency_synthesizer_b;
	signal data_in    : std_logic_vector(15 downto 0);
	signal data_out   : std_logic_vector(31 downto 0);
	type shift_reg_ack is array(0 to(3)) of unsigned(2 downto 0);
	signal ack_synch: shift_reg_ack;
	signal req : unsigned(2 downto 0):="000";
	signal ack_count : unsigned(2 downto 0) := "000";
	signal ack : std_logic_vector(2 downto 0);
	signal ack_edge: std_logic;
	signal ack_nedge: std_logic;
	signal count      : unsigned(23 downto 0) := (others => '0');
	signal inc        : unsigned(23 downto 0) := "000000000000000000000001";
	signal raw_output : std_logic_vector(35 downto 0);
	signal scale      : std_logic_vector(3 downto 0);
	signal refresh    : std_logic := '0';
	signal reset : std_logic;
	signal sq_wave    : std_logic;
	signal pulse_count: unsigned(2 downto 0); -- counts for 3 clock edges after ack has been received
	type shift_reg_out is array (0 to (2)) of std_logic_vector(35 downto 0);
	signal synched_output : shift_reg_out;
	signal s_out : std_logic_vector(35 downto 0);
	signal formatted_output: std_logic_vector(11 downto 0);
	signal clkfx: std_logic;
	signal nclkfx: std_logic;
	signal waiting : std_logic;
	
begin
		gui : lab08_gui port map(clk => clk,ra1 => ra1,rc1 => rc1,rc3 => rc3,rb => rb,
			data_in => data_in,data_out => data_out);
		f_count : frequency_counter_b port map (xin => xin, req => std_logic_vector(req),
			ack => ack, output => raw_output);
		f_synth : frequency_synthesizer_b port map (data_out => data_out, clk => clk,
			xout => sq_wave);
		xout <= sq_wave;

	-- Reference interval process
	ref_interval : process (clk)
	begin
		if rising_edge(clk) then
			if (count = "111101000010001111111111") then
				count   <= "000000000000000000000000";
				refresh <= '1';
			else
				count   <= count + inc;
				refresh <= '0';
			end if;
		end if;
	end process ref_interval;

	scale_determination : process (scale, s_out)
	begin
		if (unsigned(s_out(35 downto 32)) > "0000") then
			formatted_output <= s_out(35 downto 24);
			scale <= "1000";
		elsif (unsigned(s_out(31 downto 28)) > "0000") then
			formatted_output <= s_out(31 downto 20);
			scale <= "0111";
		elsif (unsigned(s_out(27 downto 24)) > "0000") then
			formatted_output <= s_out(27 downto 16);
			scale <= "0110";
		elsif (unsigned(s_out(23 downto 20)) > "0000") then
			formatted_output <= s_out(23 downto 12);
			scale <= "0101";
		elsif (unsigned(s_out(19 downto 16)) > "0000") then
			formatted_output <= s_out(19 downto 8);
			scale <= "0100";
		elsif (unsigned(s_out(15 downto 12)) > "0000") then
			formatted_output <= s_out(15 downto 4);
			scale <= "0011";
		else
			formatted_output <= s_out(11 downto 0);
			scale <= "0010";
		end if;
	end process scale_determination;

	HS_req : process (clk)
	begin
		if rising_edge(clk) then
			if (refresh = '1') then
				if (req + 1 /= ack_synch(3)) then
					req <= req+1;
					waiting <= '0';
				else
					waiting <= '1';
				end if;
			end if;
		end if;
	end process HS_req;

	synchronizer : process (clk)
	begin
		if rising_edge(clk) then
			ack_synch(0) <= unsigned(ack);
			ack_synch(1) <= ack_synch(0);
			ack_synch(2) <= ack_synch(1);
			ack_synch(3) <= ack_synch(2);

			synched_output(0) <= raw_output;
			synched_output(1) <= synched_output(0);
			synched_output(2) <= synched_output(1);
			s_out <= synched_output(2);
		end if;
	end process synchronizer;

	output : process (clk)
	begin
		if rising_edge(clk) then
			if (ack_synch(3) /= ack_synch(2)) then
				if (waiting = '1') then
					data_in (15 downto 4) <= (others => '0');
					data_in (3 downto 0)  <= "0010";				
				else
					if (ack_synch(3) + 1 = ack_synch(2)) then
						data_in(3 downto 0) <= scale;
						data_in(15 downto 4) <= formatted_output;
					else
						data_in (15 downto 4) <= (others => '0');
						data_in (3 downto 0)  <= "0010";	
					end if;
				end if;
			end if;
		end if;
	end process output;


end arch;