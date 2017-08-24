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

ENTITY cpu IS
	PORT(
		clk_i		: IN	STD_LOGIC;
		clk_en_i	: IN	STD_LOGIC;
		rst_i		: IN	STD_LOGIC;
		ram_data_i	: IN	STD_LOGIC_VECTOR(7 downto 0);
		ram_data_o	: OUT	STD_LOGIC_VECTOR(7 downto 0);
		ram_addr_o	: OUT	STD_LOGIC_VECTOR(3 downto 0);
		ram_write_o	: OUT	STD_LOGIC;
		hlt_o		: OUT	STD_LOGIC;
		out_val_o	: OUT	STD_LOGIC_VECTOR(7 downto 0);
		out_rdy_o	: OUT	STD_LOGIC;
		debug_sel_i	: IN	STD_LOGIC_VECTOR(3 downto 0);
		debug_out_o	: OUT	STD_LOGIC_VECTOR(7 downto 0)
	);
END cpu;

ARCHITECTURE RTL OF cpu IS

	SIGNAL	rst		: STD_LOGIC := '0';							-- asynchronous reset
	SIGNAL	clk		: STD_LOGIC := '0';							-- CPU clock
	SIGNAL	clk_en	: STD_LOGIC := '0';							-- CPU clock enable (clock ignored if 0)

	type t_cyc_t is (T0, T1, T2, T3, T4, T5);					-- ucode step type
	SIGNAL	t_cyc:	t_cyc_t;									-- current ucode step
	
	SIGNAL	id		: STD_LOGIC := '0';							-- instruction done, reset t_cyc
	SIGNAL	h		: STD_LOGIC := '0';							-- halt clock (for HLT opcode)

	SIGNAL	pc		: UNSIGNED(3 downto 0) := (others => '0');	-- program counter value
	SIGNAL	j		: STD_LOGIC := '0';							-- unconditional jump (load PC from bus)
	SIGNAL	jc		: STD_LOGIC := '0';							-- conditional jump (load PC from bus) if carry set
	SIGNAL	ci		: STD_LOGIC := '0';							-- load PC from bus (for j or jc)
	SIGNAL	co		: STD_LOGIC := '0';							-- output PC on bus
	SIGNAL	ce		: STD_LOGIC := '0';							-- program counter increment

	SIGNAL	mar		: UNSIGNED(3 downto 0) := (others => '0');	-- RAM address register value
	SIGNAL	mi		: STD_LOGIC := '0';							-- load MAR from bus

	SIGNAL	ri		: STD_LOGIC := '0';							-- RAM input (write bus to RAM)
	SIGNAL	ro		: STD_LOGIC := '0';							-- RAM output to bus

	SIGNAL	ir		: UNSIGNED(7 downto 0) := (others => '0');	-- instruction register value
	SIGNAL	ii		: STD_LOGIC := '0';							-- load IR from bus
	SIGNAL	io		: STD_LOGIC := '0';							-- output IR on bus (4-LSB)

	SIGNAL	a		: UNSIGNED(7 downto 0) := (others => '0');	-- A register value
	SIGNAL	ai		: STD_LOGIC := '0';							-- load A from bus
	SIGNAL	ao		: STD_LOGIC := '0';							-- output A on bus

	SIGNAL	e		: UNSIGNED(7 downto 0) := (others => '0');	-- ALU result value (aka "E" for sum symbol)
	SIGNAL	ec		: STD_LOGIC := '0';							-- carry bit of ALU result 
	SIGNAL	eo		: STD_LOGIC := '0';							-- output ALU result on bus 
	SIGNAL	cy		: STD_LOGIC := '0';							-- carry bit register (set from ec when eo asserted)
	SIGNAL	su		: STD_LOGIC := '0';							-- 1 for ALU subraction (else addition)
	
	SIGNAL	b		: UNSIGNED(7 downto 0) := (others => '0');	-- B register value
	SIGNAL	bi		: STD_LOGIC := '0';                         -- load B from bus
	SIGNAL	bo		: STD_LOGIC := '0';                         -- output B on bus

	SIGNAL	o		: UNSIGNED(7 downto 0) := (others => '0');	-- OUT command value
	SIGNAL	oi		: STD_LOGIC := '0';							-- load OUT from bus
	SIGNAL	o_rdy	: STD_LOGIC;								-- 1 when o value valid
	
	SIGNAL	cpu_bus	: UNSIGNED(7 downto 0) := (others => '0');	-- 8-bit CPU internal bus

BEGIN
	-- Ben Eater SAP inspired CPU instruction set:
	--
	-- 0000 xxxx	NOP				no-operation
	-- 0001 mmmm	LDA M			A = RAM[M]
	-- 0010 mmmm	ADD M			A = A+RAM[M]
	-- 0011 mmmm	SUB M			A = A-RAM[M]
	-- 0100 mmmm	STA M			RAM[M] = A
	-- 0101 iiii	LDI N			A = N (4-LSB)
	-- 0110 mmmm	JMP M			PC = M
	-- 0111 mmmm	JCS	M			if (carry) then PC = M
	-- 1000 xxxx	??? (unused, acts like NOP)
	-- 1001 xxxx	??? (unused, acts like NOP)
	-- 1010 xxxx	??? (unused, acts like NOP)
	-- 1011 xxxx	??? (unused, acts like NOP)
	-- 1100 xxxx	??? (unused, acts like NOP)
	-- 1101 xxxx	??? (unused, acts like NOP)
	-- 1110 xxxx	OUT				output A register
	-- 1111 xxxx	HLT				halt CPU clock (forces clock enable low)

	-- internal signals
	rst		<= rst_i;
	clk		<= clk_i;
	clk_en	<= clk_en_i AND (NOT h);	-- force clk_en off if halted
	
	hlt_o	<=	h;
	
	-- RAM signals
	ram_addr_o	<= STD_LOGIC_VECTOR(mar);		-- present MAR to RAM
	ram_data_o	<= STD_LOGIC_VECTOR(cpu_bus);	-- present CPU bus to RAM (in case of write)
	ram_write_o	<= ri AND clk_en;				-- set RAM write signal when RI set and clock enabled)

	-- instantiate PC - 4-bit register & up-counter for current instruction
	pc_reg:	entity work.counter4
	port map(
		clk_i		=> clk,
		clk_en_i	=> clk_en,
		rst_i		=> rst,
		set_i		=> ci,
		inc_i		=> ce,
		value_i		=> cpu_bus(3 downto 0),
		value_o		=> pc
	);
	ci	<= j OR (jc AND cy);	-- load PC on jump or jump carry if carry is set

	-- instantiate MAR - 4-bit register for RAM address
	mar_reg: entity work.reg4
	port map(
		clk_i		=> clk,
		clk_en_i	=> clk_en,
		rst_i		=> rst,
		set_i		=> mi,
		value_i		=> cpu_bus(3 downto 0),
		value_o		=> mar
	);

	-- instantiate IR - 8-bit register for current opcode
	i_reg: entity work.reg8
	port map(
		clk_i		=> clk,
		clk_en_i	=> clk_en,
		rst_i		=> rst,
		set_i		=> ii,
		value_i		=> cpu_bus,
		value_o		=> ir
	);

	-- instantiate A - 8-bit A accumulator register
	a_reg: entity work.reg8
	port map(
		clk_i		=> clk,
		clk_en_i	=> clk_en,
		rst_i		=> rst,
		set_i		=> ai,
		value_i		=> cpu_bus,
		value_o		=> a
	);

	-- instantiate B - 8-bit B argument register
	b_reg: entity work.reg8
	port map(
		clk_i		=> clk,
		clk_en_i	=> clk_en,
		rst_i		=> rst,
		set_i		=> bi,
		value_i		=> cpu_bus,
		value_o		=> b
	);

	-- instantiate ALU (E) - 8-bit add/subtract unit (9-bits out with carry)
	alu_unit: entity work.alu
	port map(
		a_i			=> a,
		b_i			=> b,
		sub_i		=> su,
		result_o 	=> e,
		carry_o		=> ec
	);

	-- carry - store ec (carry from ALU) when eo set (like a private "carry bus")
	carry : PROCESS(rst, clk, clk_en)
	BEGIN
		if (rst = '1') then
			cy <= '0';
		elsif (rising_edge(clk)) then
			if (clk_en = '1') then
				if (eo = '1') then
					cy <= ec;
				end if;
			end if;
		end if;
	END PROCESS carry;

	-- output for OUT opcode
	out_reg: PROCESS(rst, clk, clk_en)
	BEGIN
		if (rst = '1') then
			o_rdy <= '0';
			o <= (others => '0');
		elsif (rising_edge(clk)) then
			if (clk_en = '1') then
				if (oi = '1') then
					o <= cpu_bus;
					o_rdy <= '1';
				end if;
			end if;
		end if;
		out_val_o	<= STD_LOGIC_VECTOR(o);
		out_rdy_o 	<= o_rdy;
	END PROCESS out_reg;
	
	-- bus output (based on control signals)
	bus_out: PROCESS(pc, co, ram_data_i, ro, ir, io, a, ao, e, eo, b, bo)
	BEGIN
		cpu_bus <= (others => '0');
		if (co = '1') then
			cpu_bus(3 downto 0) <= pc;
		end if;
		if (ro = '1') then
			cpu_bus <= unsigned(ram_data_i);
		end if;
		if (io = '1') then
			cpu_bus(3 downto 0) <= ir(3 downto 0);
		end if;
		if (ao = '1') then
			cpu_bus <= a;
		end if;
		if (eo = '1') then
			cpu_bus <= e(7 downto 0);
		end if;
		if (bo = '1') then
			cpu_bus <= b;
		end if;
	END PROCESS bus_out;
	
	-- ucode t_cyc counter (resets with id signal "instruction done")
	ucode_cyc: PROCESS(rst, clk, clk_en)
	BEGIN
		if (rst = '1') then
			t_cyc <= T0;
		elsif (rising_edge(clk)) then
			if (clk_en = '1') then
				if (id = '1') then
					t_cyc <= T0;
				else
					case t_cyc is
						when T0 => t_cyc <= T1;
						when T1 => t_cyc <= T2;
						when T2 => t_cyc <= T3;
						when T3 => t_cyc <= T4;
						when T4 => t_cyc <= T5;
						when T5 => t_cyc <= T0;
						when others => t_cyc <= T0;
					end case;
				end if;
			end if;
		end if;
	END PROCESS ucode_cyc;

	-- CPU control logic (executes on clock falling edge)
	control: PROCESS(rst, clk, clk_en)
	BEGIN
		if (rst = '1') then
			id <= '0'; h  <= '0';		
			co <= '0'; j  <= '0'; jc <= '0'; ce <= '0';	
			mi <= '0'; ri <= '0'; ro <= '0';	
			ii <= '0'; io <= '0';	
			ai <= '0'; ao <= '0';	
			eo <= '0'; su <= '0';	
			bi <= '0'; bo <= '0';	
			oi <= '0';
		elsif (falling_edge(clk)) then
			if (clk_en = '1') then
				id <= '0'; h  <= '0';		
				co <= '0'; j  <= '0'; jc <= '0'; ce <= '0';	
				mi <= '0'; ri <= '0'; ro <= '0';	
				ii <= '0'; io <= '0';	
				ai <= '0'; ao <= '0';	
				eo <= '0'; su <= '0';	
				bi <= '0'; bo <= '0';	
				oi <= '0';
				
				-- "micro-code" to execute opcode in IR register (4-MSB)
				case ir(7 downto 4) is
					when "0000" =>		-- 0000 xxxx	NOP				no-operation
						case t_cyc is
							when T0	=>	co <= '1'; mi <= '1';				-- move PC to M
							when T1	=>	ro <= '1'; ii <= '1'; ce <= '1';	-- move RAM[M] to IR, increment PC
							when T2 =>	id <= '1';							-- instruction done
							when others => null;
						end case;
					when "0001" =>		-- 0001 mmmm	LDA M			A = RAM[M]
						case t_cyc is
							when T0	=>	co <= '1'; mi <= '1';				-- move PC to M
							when T1	=>	ro <= '1'; ii <= '1'; ce <= '1';	-- move RAM[M] to IR, increment PC
							when T2	=>	io <= '1'; mi <= '1';				-- move IR (4-LSB) to M
							when T3	=>	ro <= '1'; ai <= '1'; id <= '1';	-- move RAM[M] to A, instruction done
							when others => null;
						end case;
					when "0010" =>		-- 0010 mmmm	ADD M			A = A+RAM[M]
						case t_cyc is
							when T0	=>	co <= '1'; mi <= '1';				-- move PC to M
							when T1	=>	ro <= '1'; ii <= '1'; ce <= '1';	-- move RAM[M] to IR, increment PC
							when T2	=>	io <= '1'; mi <= '1';				-- move IR (4-LSB) to M
							when T3	=>	ro <= '1'; bi <= '1';				-- move RAM[M] to B
							when T4	=>	eo <= '1'; ai <= '1'; su <= '0'; id <= '1';	-- move E to A, adding, instruction done
							when others => null;
						end case;
					when "0011" =>		-- 0011 mmmm	SUB M			A = A-RAM[M]
						case t_cyc is
							when T0	=>	co <= '1'; mi <= '1';				-- move PC to M
							when T1	=>	ro <= '1'; ii <= '1'; ce <= '1';    -- move RAM[M] to IR, increment PC
							when T2	=>	io <= '1'; mi <= '1';				-- move IR (4-LSB) to M
							when T3	=>	ro <= '1'; bi <= '1';			    -- move RAM[M] to B,
							when T4	=>	eo <= '1'; ai <= '1'; su <= '1'; id <= '1'; -- move E to A, subtracting, instruction done
							when others => null;
						end case;
					when "0100" =>		-- 0100 mmmm	STA M			RAM[M] = A
						case t_cyc is
							when T0	=>	co <= '1'; mi <= '1';				-- move PC to M
							when T1	=>	ro <= '1'; ii <= '1'; ce <= '1';	-- move RAM[M] to IR, increment PC
							when T2	=>	io <= '1'; mi <= '1';				-- move IR (4-LSB) to M
							when T3	=>	ao <= '1'; ri <= '1'; id <= '1';	-- move A to RAM[M], instruction done
							when others => null;
						end case;
					when "0101" =>		-- 0101 nnnn	LDI #N			A = N (4-LSB)
						case t_cyc is
							when T0	=>	co <= '1'; mi <= '1';				-- move PC to M
							when T1	=>	ro <= '1'; ii <= '1'; ce <= '1';    -- move RAM[M] to IR, increment PC
							when T2	=>	io <= '1'; ai <= '1'; id <= '1';	-- move IR (4-LSB) to A, instruction done
							when others => null;
						end case;
					when "0110" =>		-- 0110 mmmm	JMP M			PC = M
						case t_cyc is
							when T0	=>	co <= '1'; mi <= '1';				-- move PC to M
							when T1	=>	ro <= '1'; ii <= '1'; ce <= '1';	-- move PC to M
							when T2	=>	io <= '1'; j  <= '1'; id <= '1';	-- move IR (4-LSB) to PC, instruction done
							when others => null;
						end case;
					when "0111" =>		-- 0111 mmmm	JCS	M			if (carry) then PC = M
						case t_cyc is
							when T0	=>	co <= '1'; mi <= '1';				-- move PC to M
							when T1	=>	ro <= '1'; ii <= '1'; ce <= '1';	-- move RAM[M] to IR, increment PC
							when T2	=>	io <= '1'; jc <= '1'; id <= '1';	-- move IR (4-LSB) to PC if carry set, instruction done
							when others => null;
						end case;
					when "1000" =>		-- 1000 xxxx	---				no-op (not defined)
						case t_cyc is
							when T0	=>	co <= '1'; mi <= '1';				-- move PC to M
							when T1	=>	ro <= '1'; ii <= '1'; ce <= '1';	-- move RAM[M] to IR, increment PC
							when T2 =>	id <= '1';
							when others => null;
						end case;
					when "1001" =>		-- 1001 xxxx	---				no-op (not defined)
						case t_cyc is
							when T0	=>	co <= '1'; mi <= '1';				-- move PC to M
							when T1	=>	ro <= '1'; ii <= '1'; ce <= '1';    -- move RAM[M] to IR, increment PC
							when T2 =>	id <= '1';							-- instruction done
							when others => null;
						end case;
					when "1010" =>		-- 1010 xxxx	---				no-op (not defined)
						case t_cyc is
							when T0	=>	co <= '1'; mi <= '1';				-- move PC to M
							when T1	=>	ro <= '1'; ii <= '1'; ce <= '1';    -- move RAM[M] to IR, increment PC
							when T2 =>	id <= '1';							-- instruction done
							when others => null;
						end case;
					when "1011" =>		-- 1011 xxxx	---				no-op (not defined)
						case t_cyc is
							when T0	=>	co <= '1'; mi <= '1';				-- move PC to M
							when T1	=>	ro <= '1'; ii <= '1'; ce <= '1';    -- move RAM[M] to IR, increment PC
							when T2 =>	id <= '1';							-- instruction done
							when others => null;
						end case;
					when "1100" =>		-- 1100 xxxx	---				no-op (not defined)
						case t_cyc is
							when T0	=>	co <= '1'; mi <= '1';				-- move PC to M
							when T1	=>	ro <= '1'; ii <= '1'; ce <= '1';    -- move RAM[M] to IR, increment PC
							when T2 =>	id <= '1';							-- instruction done
							when others => null;
						end case;
					when "1101" =>		-- 1101 xxxx	---				no-op (not defined)
						case t_cyc is
							when T0	=>	co <= '1'; mi <= '1';				-- move PC to M
							when T1	=>	ro <= '1'; ii <= '1'; ce <= '1';    -- move RAM[M] to IR, increment PC
							when T2 =>	id <= '1';							-- instruction done
							when others => null;
						end case;
					when "1110" =>		-- 1110 xxxx	OUT				output A register
						case t_cyc is
							when T0	=>	co <= '1'; mi <= '1';				-- move PC to M
							when T1	=>	ro <= '1'; ii <= '1'; ce <= '1';	-- move RAM[M] to IR, increment PC
							when T2 =>	ao <= '1'; oi <= '1'; id <= '1';	-- move A to O, instruction done
							when others => null;
						end case;
					when "1111" =>		-- 1111 xxxx	HLT				halt CPU clock
						case t_cyc is
							when T0	=>	co <= '1'; mi <= '1';				-- move PC to M
							when T1	=>	ro <= '1'; ii <= '1'; ce <= '1';	-- move RAM[M] to IR, increment PC
							when T2 =>	h  <= '1';							-- halt
							when T3	=>	id <= '1';							-- insruction done
							when others => null;
						end case;
					when others =>	null;
				end case;
			end if;
		end if;
	END PROCESS control;

	-- This is a simple "debug port" that saves having to run a large number of signals out of this module
	-- but still provides a way to "peer inside" at the CPU state.
	-- Here are how the debug registers are mapped:
	--
	--								debug_out_o	-- debug_sel_i 0000		id h  su cy  0  t  t  t
	-- debug_sel_i 0001		0  ce co ro io ao bo eo
	-- debug_sel_i 0010		jc j  mi ri ii ai bi oi
	-- debug_sel_i 0011		cpu_bus
	-- debug_sel_i 0100		0  0  0  0  mar
	-- debug_sel_i 0101		0  0  0  0  pc
	-- debug_sel_i 0110		i
	-- debug_sel_i 0111		a
	-- debug_sel_i 1000		b
	-- debug_sel_i 1001		o

	debug: PROCESS(t_cyc, h, id, pc, j, jc, ci, co, ce, mar, mi, ri, ro, ir, ii, io, a, ai, ao, e, eo, cy, su, b, bi, bo, o, oi, cpu_bus)
		VARIABLE	bus_save: UNSIGNED(7 downto 0);
	BEGIN
		-- need to capture bus on clock edge to get desired value (as CPU does)
		if (rising_edge(clk)) then
			if (clk_en = '1') then
				bus_save	:= cpu_bus;
			end if;
		end if;
	
		-- the debug port is combinatorial 
		case debug_sel_i is
			when "0000" =>
				debug_out_o(7 downto 3) <= id & h & su & cy & "0";
				case t_cyc is	-- convert t_cyc to binary
					when T0	=>  debug_out_o(2 downto 0)	<= "000";
					when T1 =>  debug_out_o(2 downto 0)	<= "001";
					when T2	=>  debug_out_o(2 downto 0)	<= "010";
					when T3	=>  debug_out_o(2 downto 0)	<= "011";
					when T4	=>  debug_out_o(2 downto 0)	<= "100";
					when T5	=>  debug_out_o(2 downto 0)	<= "101";
					when others => debug_out_o(2 downto 0)	<= "111";
				end case;
			when "0001" =>	debug_out_o	<= "0" & ce & co & ro & io & ao & bo & eo;
			when "0010" =>	debug_out_o	<= STD_LOGIC_VECTOR(bus_save); -- saved cpu_bus value
			when "0011" =>	debug_out_o	<= jc & ci & mi & ri & ii & ai & bi & oi;
			when "0100" =>	debug_out_o	<= "0000" & STD_LOGIC_VECTOR(mar);
			when "0101" =>	debug_out_o	<= "0000" & STD_LOGIC_VECTOR(pc);
			when "0110" =>	debug_out_o	<= STD_LOGIC_VECTOR(ir);
			when "0111" =>	debug_out_o	<= STD_LOGIC_VECTOR(a);
			when "1000" =>	debug_out_o	<= STD_LOGIC_VECTOR(b);
			when "1001" =>	debug_out_o	<= STD_LOGIC_VECTOR(o);
			when others =>	debug_out_o	<= (others => '-');
		end case;
	END PROCESS debug;
	
END ARCHITECTURE RTL;
