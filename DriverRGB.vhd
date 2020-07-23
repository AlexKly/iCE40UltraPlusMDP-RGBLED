Library IEEE;
Use IEEE.STD_LOGIC_1164.ALL;
Use IEEE.STD_LOGIC_UNSIGNED.ALL;

Library sb_ice40_components_syn;
Use sb_ice40_components_syn.components.ALL;

entity DriverRGB is
	port (
			-- RGB Led:
			LED0 	: out std_logic;
			LED1 	: out std_logic;
			LED2 	: out std_logic );
end DriverRGB;

architecture Behavior of DriverRGB is

	-- Generator clock:
	component SB_HFOSC is
		generic (
					CLKHF_DIV	: string := "0b00" );
		port (
				CLKHFPU	: in std_logic;
				CLKHFEN	: in std_logic;

				CLKHF 	: out std_logic );
	end component;

	-- Embedded PWM IP:
	component SB_LEDDA_IP is
		port (
				LEDDCS		: in std_logic;
				LEDDCLK		: in std_logic;
				LEDDDAT7	: in std_logic;
				LEDDDAT6	: in std_logic;
				LEDDDAT5	: in std_logic;
				LEDDDAT4	: in std_logic;
				LEDDDAT3	: in std_logic;
				LEDDDAT2	: in std_logic;
				LEDDDAT1	: in std_logic;
				LEDDDAT0	: in std_logic;
				LEDDADDR3	: in std_logic;
				LEDDADDR2	: in std_logic;
				LEDDADDR1	: in std_logic;
				LEDDADDR0	: in std_logic;
				LEDDDEN 	: in std_logic;
				LEDDEXE		: in std_logic;
				LEDDRST		: in std_logic;

				PWMOUT0		: out std_logic;
				PWMOUT1		: out std_logic;
				PWMOUT2		: out std_logic;
				LEDDON		: out std_logic );
	end component;

	-- RGB Driver:
	component SB_RGBA_DRV is
		generic (
					CURRENT_MODE	: string := "0b0";
					RGB0_CURRENT	: string := "0b000000";
					RGB1_CURRENT	: string := "0b000000";
					RGB2_CURRENT	: string := "0b000000" );
		port (
				CURREN		: in std_logic;
				RGBLEDEN	: in std_logic;
				RGB0PWM		: in std_logic;
				RGB1PWM		: in std_logic;
				RGB2PWM		: in std_logic;

				RGB0 		: out std_logic;
				RGB1 		: out std_logic;
				RGB2 		: out std_logic );
	end component;

	signal innCLK		: std_logic;
	signal dr_red_led	: std_logic;
	signal dr_green_led	: std_logic;
	signal dr_blue_led	: std_logic;
	signal led_en		: std_logic;
	signal led_cs		: std_logic;
	signal led_exe		: std_logic;

	-- Registers embedded PWM IP: 
	signal LEDD_ADR	: std_logic_vector(3 downto 0) := (others => '0');
	signal DAT_Bits	: std_logic_vector(7 downto 0) := (others => '0');

	-- Finite State Machine:
	type LED_Driver is (IDLE, LEDDBR, LEDDONR, LEDDOFR, LEDDBCRR, LEDDBCFR, LEDDPWRR, LEDDPWRG, LEDDPWRB, LEDDCR0, DONE);
	signal PWM_state_reg	: LED_Driver := IDLE;
	signal PWM_state_next	: LED_Driver;

begin

	switch_states_proc : process(innCLK)
	begin
		if rising_edge(innCLK) then
			PWM_state_reg <= PWM_state_next;
		end if;
	end process switch_states_proc;

	PWM_fsm_proc : process(PWM_state_reg)
	begin

		case PWM_state_reg is
			when IDLE =>
						led_en			<= '0';
						led_cs			<= '0';
						led_exe			<= '1';
						LEDD_ADR 		<= (others => '0');
						DAT_Bits		<= (others => '0');
						PWM_state_next	<= LEDDBR;
			when LEDDBR =>
							led_en					<= '1';
							led_cs					<= '1';
							led_exe					<= '0';
							LEDD_ADR				<= "1001";
							DAT_Bits(7 downto 0)	<= "11101101";
							PWM_state_next			<= LEDDONR;
			when LEDDONR =>
							led_en					<= '1';
							led_cs					<= '1';
							led_exe					<= '0';
							LEDD_ADR				<= "1010";
							DAT_Bits(7 downto 0)	<= "00010001";	-- Blink ON Time (0.544 sec)
							PWM_state_next			<= LEDDOFR;
			when LEDDOFR =>
							led_en					<= '1';
							led_cs					<= '1';
							led_exe					<= '0';
							LEDD_ADR				<= "1011";
							DAT_Bits(7 downto 0)	<= "00010001";	-- Blink OFF Time (0.544 sec)
							PWM_state_next			<= LEDDBCRR;
			when LEDDBCRR =>
							led_en					<= '1';
							led_cs					<= '1';
							led_exe					<= '0';
							LEDD_ADR				<= "0101";
							DAT_Bits(7)				<= '1';		-- Breathe ON Enable Bit (disable/enable)
							DAT_Bits(6)				<= '1';		-- Breathe Edge Selection Bit
							DAT_Bits(5)				<= '1';		-- Breathe Mode Select Bit
							DAT_Bits(4)				<= '0';		-- RESERVED
							DAT_Bits(3 downto 0)	<= "0011";	-- Breathe ON Rate (Tramp = 0.512 sec)
							PWM_state_next			<= LEDDBCFR;
			when LEDDBCFR =>
							led_en					<= '1';
							led_cs					<= '1';
							led_exe					<= '0';
							LEDD_ADR				<= "0110";
							DAT_Bits(7)				<= '1';		-- Breathe OFF Enable Bit (disable/enable)
							DAT_Bits(6)				<= '0';		-- PWM Range Extend
							DAT_Bits(5)				<= '1';		-- Breathe Mode Select Bit
							DAT_Bits(4)				<= '0';		-- RESERVED
							DAT_Bits(3 downto 0)	<= "0011";	-- Breathe OFF Rate (Tramp = 0.512 sec)
							PWM_state_next			<= LEDDPWRR;
			when LEDDPWRR =>
							led_en					<= '1';
							led_cs					<= '1';
							led_exe					<= '0';
							LEDD_ADR				<= "0001";
							DAT_Bits(7 downto 0)	<= "00000001";	-- RED Pulse Width
							PWM_state_next			<= LEDDPWRG;
			when LEDDPWRG =>
							led_en					<= '1';
							led_cs					<= '1';
							led_exe					<= '0';
							LEDD_ADR				<= "0010";
							DAT_Bits(7 downto 0)	<= "11111111";	-- GREEN Pulse Width
							PWM_state_next			<= LEDDPWRB;
			when LEDDPWRB =>
							led_en 					<= '1';
							led_cs					<= '1';
							led_exe					<= '0';
							LEDD_ADR				<= "0011";
							DAT_Bits(7 downto 0)	<= "00011111";	-- BLUE Pulse Width (PWG)
							PWM_state_next			<= LEDDCR0;
			when LEDDCR0 =>
							led_en					<= '1';
							led_cs					<= '1';
							led_exe					<= '0';
							LEDD_ADR				<= "1000";
							DAT_Bits(7)				<= '1';		-- LED Driver Enable Bit (disable/enable)
							DAT_Bits(6)				<= '1';		-- Flick Rate Select Bit (125/250 Hz)
							DAT_Bits(5)				<= '0';		-- PWM Outputs Polarity Select Bit (Active High/Low)
							DAT_Bits(4) 			<= '0';		-- PWM Output Skew Enable Bit
							DAT_Bits(3)				<= '1';		-- Blinking Sequence Quick Stop Enable Bit
							DAT_Bits(2)				<= '0';		-- PWM Mode Selection Bit
							DAT_Bits(1 downto 0)	<= "10";	-- BRMSBEXT
							PWM_state_next			<= DONE;
			when DONE =>
							led_en					<= '0';
							led_cs					<= '0';
							led_exe					<= '1';
							LEDD_ADR(3 downto 0)	<= (others => '0');
							DAT_Bits(7 downto 0)	<= (others => '0');
							PWM_state_next			<= DONE;
		end case;
	end process PWM_fsm_proc;

	u_gen_clk : SB_HFOSC
		generic map (
						CLKHF_DIV	=> "0b00" )	-- "0b00" - 48MHz, "0b01" - 24MHz, "0b10" - 12MHz, "0b11" - 6MHz
		port map (
					CLKHFPU	=> '1',
					CLKHFEN	=> '1',

					CLKHF 	=> innCLK );

	u_embedded_pwm_ip : SB_LEDDA_IP
		port map (
					LEDDCS		=> led_cs,
					LEDDCLK		=> innCLK,
					LEDDDAT7	=> DAT_Bits(7),
					LEDDDAT6	=> DAT_Bits(6),
					LEDDDAT5	=> DAT_Bits(5),
					LEDDDAT4	=> DAT_Bits(4),
					LEDDDAT3	=> DAT_Bits(3),
					LEDDDAT2	=> DAT_Bits(2),
					LEDDDAT1	=> DAT_Bits(1),
					LEDDDAT0	=> DAT_Bits(0),
					LEDDADDR3	=> LEDD_ADR(3),
					LEDDADDR2	=> LEDD_ADR(2),
					LEDDADDR1	=> LEDD_ADR(1),
					LEDDADDR0	=> LEDD_ADR(0),
					LEDDDEN		=> led_en,
					LEDDEXE		=> led_exe,
					LEDDRST		=> '0',

					PWMOUT0		=> dr_red_led,
					PWMOUT1		=> dr_green_led,
					PWMOUT2		=> dr_blue_led,
					LEDDON		=> open );

	u_rgb_dr : SB_RGBA_DRV
		generic map (
						CURRENT_MODE	=> "0b0",		-- "0b0" - Full Current Mode, "0b1" - Half Current Mode
						RGB0_CURRENT	=> "0b000011",	-- "0b000001" = 4mA for Full Mode; 2mA for Half Mode. "0b000011" = 8mA for Full Mode; 4mA for Half Mode.
						RGB1_CURRENT	=> "0b000011",	-- "0b000111" = 12mA for Full Mode; 6mA for Half Mode. "0b001111" = 16mA for Full Mode; 8mA for Half Mode
						RGB2_CURRENT	=> "0b000011" )	-- "0b011111" = 20mA for Full Mode; 10mA for Half Mode. "0b111111" = 24mA for Full Mode; 12mA for Half Mode.
		port map (
					CURREN		=> '1',
					RGBLEDEN	=> '1',
					RGB0PWM		=> dr_red_led,
					RGB1PWM		=> dr_green_led,
					RGB2PWM		=> dr_blue_led,
					RGB0		=> LED0,
					RGB1		=> LED1,
					RGB2		=> LED2 );

end Behavior;