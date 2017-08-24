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

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tx_uart is
    generic (
        C_SYSTEM_HZ: integer := 1_000_000;          -- FPGA clock in Hz
        C_BPS:  integer := 9600                     -- UART transmition rate in bits per second (aka baud)
    );
    port (
        rst_i:  in  std_logic;                      -- reset
        clk_i:  in  std_logic;                      -- FPGA clock

        tx_o:   out std_logic;                      -- TX pin output
        busy_o: out std_logic;                      -- high when UART busy transmitting

        data_i: in  std_logic_vector(7 downto 0);   -- data to send
        we_i:   in  std_logic                       -- set high to send byte (when busy_o is low)
    );
end tx_uart;

architecture RTL of tx_uart is
    constant clocks_per_bit: integer := (C_SYSTEM_HZ / C_BPS);  -- determine number of FPGA clocks that will be one bit for UART bits per second

    signal  busy_r:     std_logic;

    signal  bps_counter:    integer range 0 to clocks_per_bit-1;
    signal  shift_out:      std_logic_vector(8 downto 0);
    signal  bit_counter:    integer range 0 to 11;  -- start bit + 8 data bits + stop bit
begin

process(clk_i, rst_i)
begin
    if rst_i='1' then
        bps_counter <= 0;
        bit_counter <= 0;
        tx_o        <= '1';
        busy_r      <= '0';
    elsif rising_edge(clk_i) then

        if bit_counter = 0 then
            busy_r  <= '0';
            tx_o    <= '1';
        else
            busy_r  <= '1';
            tx_o    <= shift_out(0);
        end if;
        
        if we_i = '1' AND bit_counter = 0 then
            shift_out <= data_i & "0";
            bit_counter <= 11;
            bps_counter <= clocks_per_bit - 1;
            busy_r      <= '1';
        elsif bps_counter = 0 then
            bps_counter <= clocks_per_bit - 1;
            if bit_counter /= 0 then
                bit_counter <= bit_counter - 1;
                shift_out <= "1" & shift_out(8 downto 1);
            end if;
        else
            bps_counter <= bps_counter - 1;
        end if;
        
    end if;
end process;
busy_o <= busy_r OR we_i;
end RTL;
