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

ENTITY alu IS
    PORT(
        a_i         : IN    UNSIGNED(7 downto 0);
        b_i         : IN    UNSIGNED(7 downto 0);
        sub_i       : IN    STD_LOGIC;
        result_o    : OUT   UNSIGNED(7 downto 0);
        carry_o     : OUT   STD_LOGIC
    );
END alu;

ARCHITECTURE RTL OF alu IS

    SIGNAL  val : UNSIGNED(8 downto 0) := (others => '0');  -- includes carry

BEGIN

    PROCESS(sub_i, a_i, b_i)
    BEGIN
        if (sub_i = '1') then
            val <= ('0' & a_i) - ('0' & b_i);
        else
            val <= ('0' & a_i) + ('0' & b_i);
        end if;
    END PROCESS;
    
    result_o    <= val(7 downto 0);
    carry_o     <= val(8);

end ARCHITECTURE RTL;
