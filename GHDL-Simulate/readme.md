This folder has a very simple Makefile to build and simulate the BenEaterVHDL CPU
with the GHDL VHDL simulation package.  This is something you can do without having
any FPGA hardware.  You just need the free GHDL package installed (Windows or Linux).
You may also need to change the paths in the Makefile for your system.

Here are the steps the Makefile performs:

	$ make
	mkdir -p ghdlwork
	/cygdrive/c/Users/GitHub/Downloads/ghdl-0.35-mcode-windows/bin/ghdl -i --ieee=standard --std=08 --workdir=ghdlwork ../VHDL/cpu.vhd ../VHDL/ram.vhd ../VHDL/tx_uart.vhd ../VHDL/cpu_trace.vhd ../VHDL/system.vhd ../VHDL-testbench/system_tb.vhd
	/cygdrive/c/Users/GitHub/Downloads/ghdl-0.35-mcode-windows/bin/ghdl -m --ieee=standard --std=08 --workdir=ghdlwork system_tb
	/cygdrive/c/Users/GitHub/Downloads/ghdl-0.35-mcode-windows/bin/ghdl -r --ieee=standard --std=08 --workdir=ghdlwork system_tb --stop-time=1ms --vcd=system_tb.vcdgz | grep -v VHDL
	numeric_std-body.v08:3034:7:@0ms:(assertion warning): NUMERIC_STD.TO_INTEGER: metavalue detected, returning 0

Here is an example of the VHDL "report" printed by GHDL when simulating:

	T0: pc=0011 mar=0110 ir=01100011 --- a=11111111 b=00000001 o=11111111 cy=0 zr=0
		cO           => 00000011 => mI            |
	T1: pc=0011 mar=0011 ir=01100011 --- a=11111111 b=00000001 o=11111111 cy=0 zr=0
		rO         => 00101101 =>   iI          | ce
	T2: pc=0100 mar=0011 ir=00101101 ADD a=11111111 b=00000001 o=11111111 cy=0 zr=0
			iO       => 00001101 => mI            |
	T3: pc=0100 mar=1101 ir=00101101 ADD a=11111111 b=00000001 o=11111111 cy=0 zr=0
		rO         => 00000001 =>       bI      |
	T4: pc=0100 mar=1101 ir=00101101 ADD a=11111111 b=00000001 o=11111111 cy=0 zr=0
				eO => 00000000 =>     aI        |                id
	T0: pc=0100 mar=1101 ir=00101101 --- a=00000000 b=00000001 o=11111111 cy=1 zr=1
		cO           => 00000100 => mI            |
	T1: pc=0100 mar=0100 ir=00101101 --- a=00000000 b=00000001 o=11111111 cy=1 zr=1
		rO         => 11100000 =>   iI          | ce
	T2: pc=0101 mar=0100 ir=11100000 OUT a=00000000 b=00000001 o=11111111 cy=1 zr=1
			aO     => 00000000 =>           oI  |                id
	>>> OUTPUT: 00000000 (0)
	T0: pc=0101 mar=0100 ir=11100000 --- a=00000000 b=00000001 o=00000000 cy=1 zr=1
		cO           => 00000101 => mI            |
	T1: pc=0101 mar=0101 ir=11100000 --- a=00000000 b=00000001 o=00000000 cy=1 zr=1
				eO => 00000000 =>     aI        |    su          id
	T0: pc=1001 mar=1101 ir=00111101 --- a=00000000 b=00000001 o=00000000 cy=0 zr=1
		cO           => 00001001 => mI            |
	T1: pc=1001 mar=1001 ir=00111101 --- a=00000000 b=00000001 o=00000000 cy=0 zr=1
		rO         => 01111001 =>   iI          | ce
	T2: pc=1010 mar=1001 ir=01111001 JC  a=00000000 b=00000001 o=00000000 cy=0 zr=1
			iO       => 00001001 =>               |          jc    id
	T0: pc=1010 mar=1001 ir=01111001 --- a=00000000 b=00000001 o=00000000 cy=0 zr=1
		cO           => 00001010 => mI            |
	T1: pc=1010 mar=1010 ir=01111001 --- a=00000000 b=00000001 o=00000000 cy=0 zr=1
		rO         => 11110000 =>   iI          | ce
	T2: pc=1011 mar=1010 ir=11110000 HLT a=00000000 b=00000001 o=00000000 cy=0 zr=1
					=> 00000000 =>               |                   hlt
	*** CPU HAS HALTED, 276 CYCLES ***

GHDL also produces a "waveform" file that can be viewed with GTKWave (and other viewers).
Here is a screenshot of the end of a CPU trace (showing the CPU halting, roughly coresponding
to the trace above).

![Alt text](GHDL_trace_halting.png?raw=true "GTKWave screenshot (showing CPU halting)")
