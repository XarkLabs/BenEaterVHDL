--
-- Based on Ben Eater's build of the SAP breadboard computer and his excellent videos.
-- https://eater.net/
--
-- Copyright (c) 2017 Ken Jordan
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
-- 
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
-- 
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library machxo2;
use machxo2.all;

-- Microwavemont-A2 hook-up is as follows:
--
-- Pins 1-8 are "output" register of CPU (binary for LED, e.g.)
-- Pin 9 is 9600 baud 8N1 serial CPU trace output TX (use USB serial adapter)
-- Pin22 is reset (active LOW)-- Pin21 is "wait" (will halt CPU clock while high)
-- pin20 is clock LED (blicks with "slow" clock)

ENTITY Microwavemont_top IS
	generic
	(
		C_SYSTEM_HZ:	integer	:= 12_000_000;	-- master clock (in Hz)
		C_TARGET_HZ:	integer := 2			-- speed of "slow" clock in Hz used by CPU
												-- needs to be low so CPU trace has time
	);

	PORT(
		clk_12mhz	: IN	STD_LOGIC;
		led1		: OUT	STD_LOGIC;
		led2		: OUT	STD_LOGIC;
		led3		: OUT	STD_LOGIC;
		led4		: OUT	STD_LOGIC;
		led5		: OUT	STD_LOGIC;
		led6		: OUT	STD_LOGIC;
		led7		: OUT	STD_LOGIC;
		led8		: OUT	STD_LOGIC;
		ledneg		: OUT	STD_LOGIC;
		seg1neg		: OUT	STD_LOGIC;
		seg2neg		: OUT	STD_LOGIC;
		sda			: OUT	STD_LOGIC;
		buzzer		: OUT	STD_LOGIC;		
		btn1		: IN	STD_LOGIC;
		btn2		: IN	STD_LOGIC
	);
END Microwavemont_top;

ARCHITECTURE RTL of Microwavemont_top is

	SIGNAL	rst		: STD_LOGIC := '0';							-- asynchronous reset
	SIGNAL	clk		: STD_LOGIC := '0';							-- CPU clock
	SIGNAL	clk_en	: STD_LOGIC := '0';							-- CPU clock enable (clock ignored if 0)
	SIGNAL	halt	: STD_LOGIC := '0';							-- CPU halted

	SIGNAL	cpu_out	: STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
	SIGNAL	cpu_out_rdy : STD_LOGIC;	

	SIGNAL	tx_o	: STD_LOGIC;	
	
	SIGNAL	led		: STD_LOGIC := '0';
	
	SIGNAL	spi_sck	: STD_LOGIC := '0';
	SIGNAL	spi_mosi: STD_LOGIC := '0';
	SIGNAL	spi_dc	: STD_LOGIC := '0';
	SIGNAL	spi_cs	: STD_LOGIC := '0';
	
	SIGNAL	vled	: STD_LOGIC_VECTOR(7 downto 0);				-- "virtual" LEDs multiplexed with 7-segment onto real LEDs
	SIGNAL	segments: STD_LOGIC_VECTOR(7 downto 0);				-- 7-segment segments (a, b, c, d, e, f, g, dp)

	SIGNAL 	number_r	: STD_LOGIC_VECTOR (7 downto 0);		-- 8-bit number to display in hex
	SIGNAL 	decimals_r	: STD_LOGIC_VECTOR (1 downto 0);		-- decimal point for each digit (left, right)
	SIGNAL 	blank_r	: STD_LOGIC_VECTOR (1 downto 0);		-- decimal point for each digit (left, right)

	SIGNAL 	counter		: UNSIGNED (12 downto 0);				-- count to 0x1ffff for ~= 244Hz @ 12Mhz clock
	SIGNAL 	digit		: INTEGER range 0 to 2;					-- digit number being multiplexed (0 = rightmost)

BEGIN
	clk			<= clk_12mhz;
	rst			<= NOT btn1;
	buzzer		<= '0';
	
	sda			<= tx_o;
	
	PROCESS(clk, rst)
		VARIABLE count :	INTEGER RANGE 0 TO ((C_SYSTEM_HZ/C_TARGET_HZ)/2);
	BEGIN
		IF(rst = '1') THEN
			count := 0;
			led <= '0';
			clk_en <= '0';
		ELSE
			IF(rising_edge(clk)) THEN
				clk_en <= '0';
				IF(count < ((C_SYSTEM_HZ/C_TARGET_HZ)/2)) THEN
					count := count + 1;
				ELSE
					count := 0;
					led <= NOT led;
					clk_en <= '1' AND btn2;
				END IF;
			END IF;
		END IF;
	END PROCESS;

	sys: entity work.system
	generic map (
		C_SYSTEM_HZ	=> C_SYSTEM_HZ
	)
	port map(
		clk_i		=> clk,	
	    clk_en_i	=> clk_en,
	    rst_i		=> rst,
		out_o		=> cpu_out,
		out_rdy_o	=> cpu_out_rdy,
		halt_o		=> halt,
		tx_o		=> tx_o
	);
	
	vled		<= cpu_out;		-- signal to display on 8 LEDs
	number_r 	<= cpu_out;		-- signal to display as 2 digit hex on 7-segments
	decimals_r	<= halt & ((led AND btn2) AND (NOT halt));	-- decimal points per digit
	blank_r		<= NOT cpu_out_rdy & NOT cpu_out_rdy;	-- blank out per digit


	led1	<= NOT segments(7);
	led2	<= NOT segments(6);
	led3	<= NOT segments(5);
	led4	<= NOT segments(4);
	led5	<= NOT segments(3);
	led6	<= NOT segments(2);
	led7	<= NOT segments(1);
	led8	<= NOT segments(0);

	count_proc: process(clk)
		variable bitnum: integer;
	begin
		if rising_edge(clk) then
			counter <= counter + 1;
			if counter = 0 then
				if (digit >= 2) then
					digit <= 0;
				else
					digit <= digit + 1;
				end if;
			end if;
			 
			bitnum := digit * 4;
			
			case digit is
				when 0 => seg1neg <= '1'; seg2neg <= '0'; ledneg <= '1'; 
				when 1 => seg1neg <= '0'; seg2neg <= '1'; ledneg <= '1'; 
				when 2 => seg1neg <= '1'; seg2neg <= '1'; ledneg <= '0'; 
				when others => seg1neg <= '1'; seg2neg <= '1'; ledneg <= '1';
			end case;
			if (digit >= 2) then
				segments	<= vled;
			else
				segments(0) <= decimals_r(digit);
				if (blank_r(digit) = '1') then
					segments(7 downto 1) <= (others => '0');
				else
					case number_r(bitnum + 3 downto bitnum) is
						when "0000" =>	segments(7 downto 1) <= "1111110";	-- 0
						when "0001" =>	segments(7 downto 1) <= "0110000";	-- 1
						when "0010" =>	segments(7 downto 1) <= "1101101";	-- 2
						when "0011" =>	segments(7 downto 1) <= "1111001";	-- 3
						when "0100" =>	segments(7 downto 1) <= "0110011";	-- 4
						when "0101" =>	segments(7 downto 1) <= "1011011";	-- 5
						when "0110" =>	segments(7 downto 1) <= "1011111";	-- 6
						when "0111" =>	segments(7 downto 1) <= "1110000";	-- 7
						when "1000" =>	segments(7 downto 1) <= "1111111";	-- 8
						when "1001" =>	segments(7 downto 1) <= "1111011";	-- 9
						when "1010" =>	segments(7 downto 1) <= "1110111";	-- A
						when "1011" =>	segments(7 downto 1) <= "0011111";	-- b
						when "1100" =>	segments(7 downto 1) <= "1001110";	-- C
						when "1101" =>	segments(7 downto 1) <= "0111101";	-- d
						when "1110" =>	segments(7 downto 1) <= "1001111";	-- E
						when "1111" =>	segments(7 downto 1) <= "1000111";	-- F
						when others =>	segments(7 downto 1) <= "0000000";	-- others blank
					end case;
				end if;
			end if;
		end if;
	end process;

END ARCHITECTURE RTL;
