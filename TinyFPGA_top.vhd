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

-- TinyFPGA-A2 hook-up is as follows:
--
-- Pins 1-8 are "output" register of CPU (binary for LED, e.g.)
-- Pin 9 is 9600 baud 8N1 serial CPU trace output TX (use USB serial adapter)
-- Pin22 is reset (active LOW)
-- Pin21 is "wait" (will halt CPU clock while high)
-- pin20 is clock LED (blicks with "slow" clock)

ENTITY TinyFPGA_top IS
    generic
    (
        C_SYSTEM_HZ:    integer := 19_000_000;  -- master clock (in Hz)
        C_TARGET_HZ:    integer := 2            -- speed of "slow" clock in Hz used by CPU
                                                -- needs to be low so CPU trace has time
    );

    PORT(
        pin1        : OUT   STD_LOGIC;
        pin2        : OUT   STD_LOGIC;
        pin3_sn     : OUT   STD_LOGIC;
        pin4_mosi   : OUT   STD_LOGIC;
        pin5        : OUT   STD_LOGIC;
        pin6        : OUT   STD_LOGIC;
        pin7_done   : OUT   STD_LOGIC;
        pin8_pgmn   : OUT   STD_LOGIC;
        pin9_jtgnb  : OUT   STD_LOGIC;
        pin16       : OUT   STD_LOGIC;
        pin17       : OUT   STD_LOGIC;
        pin18_cs    : OUT   STD_LOGIC;
        pin19_sclk  : OUT   STD_LOGIC;
        pin20_miso  : OUT   STD_LOGIC;
        pin21       : IN    STD_LOGIC;
        pin22       : IN    STD_LOGIC
    );
END TinyFPGA_top;

ARCHITECTURE RTL of TinyFPGA_top is

    -- Lattice MachXO2 internal oscillator
    COMPONENT OSCH
        -- synthesis translate_off
        GENERIC (NOM_FREQ: string := "19.00");
        -- synthesis translate_on
        PORT(
            STDBY:      IN  std_logic;
            OSC:        OUT std_logic;
            SEDSTDBY:   OUT std_logic
        );
    END COMPONENT;

    attribute NOM_FREQ : string;
    attribute NOM_FREQ of OSCinst0 : label is "19.00";

    SIGNAL  rst     : STD_LOGIC := '0';                         -- asynchronous reset
    SIGNAL  clk     : STD_LOGIC := '0';                         -- CPU clock
    SIGNAL  clk_en  : STD_LOGIC := '0';                         -- CPU clock enable (clock ignored if 0)
    SIGNAL  halt    : STD_LOGIC := '0';                         -- CPU halted

    SIGNAL  cpu_out : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    
    SIGNAL  tx_o    : STD_LOGIC;    
    
    SIGNAL  led     : STD_LOGIC := '0';
    
    SIGNAL  spi_sck : STD_LOGIC := '0';
    SIGNAL  spi_mosi: STD_LOGIC := '0';
    SIGNAL  spi_dc  : STD_LOGIC := '0';
    SIGNAL  spi_cs  : STD_LOGIC := '0';

BEGIN

    -- instantiate MachXO2 internal oscillator @ ~19 Mhz (close enough for 9600 baud)
    OSCInst0: OSCH
    -- synthesis translate_off
    GENERIC MAP( NOM_FREQ => "19.00" )
    -- synthesis translate_on
    PORT MAP (
        STDBY       => '0',
        OSC         => clk,
        SEDSTDBY    => open
    );

    pin20_miso  <= led AND (NOT pin21) AND (not halt);
    rst         <= NOT pin22;
    pin9_jtgnb  <= tx_o;
    
    PROCESS(clk, rst)
        VARIABLE count :    INTEGER RANGE 0 TO ((C_SYSTEM_HZ/C_TARGET_HZ)/2);
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
                    clk_en <= '1' AND (NOT pin21);
                END IF;
            END IF;
        END IF;
    END PROCESS;

    sys: entity work.system
    generic map (
        C_SYSTEM_HZ => C_SYSTEM_HZ
    )
    port map(
        clk_i       => clk, 
        clk_en_i    => clk_en,
        rst_i       => rst,
        out_o       => cpu_out,
        halt_o      => halt,
        tx_o        => tx_o
    );
    
    pin1        <= cpu_out(0);
    pin2        <= cpu_out(1);
    pin3_sn     <= cpu_out(2);
    pin4_mosi   <= cpu_out(3);
    pin5        <= cpu_out(4);
    pin6        <= cpu_out(5);
    pin7_done   <= cpu_out(6);
    pin8_pgmn   <= cpu_out(7);

END ARCHITECTURE RTL;
