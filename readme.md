## Ben Eater/SAP inspired computer designed in VHDL 

###### MIT licensed.

This is the full VHDL project to run a simple 8-bit computer very similar to the one built by Ben Eater (see https://eater.net).   My thinking was that since
a lot of people understand how Ben's computer works from his excellent videos, it might be useful to use as an example VHDL CPU FPGA project.  I have tried to stay pretty close
to Ben's terminology and design, but I couldn't resist changing a few minor things:

 * added JCS "jump on carry set" instruction (which I suspect Ben will add also)
 * added 1-bit "carry register" to support JCS
 * added ID "instruction done" signal to skip any wasted cycles at the end of instruction microcode
 * used FPGA logic instead of ROM for microcode (looks similar to Arduino code Ben uses to generate microcode ROM with)
 * clocked FPGA BRAM on negative clock edge to "simulate" async RAM (data available on next CPU cycle)
 * no decimal 7-segment decode for output (but I do have nifty terminal trace...)

It has been developed on a TinyFPGA-A2 (http://tinyfpga.com/) board with a Lattice MachXO2-1200 FPGA using the Lattice Diamond software (free version). It has also been converted for use on the Microwavemont "FPGA board for I2C, SPI device prototyping" (https://hackaday.io/project/26175-hdl-training-board-by-fpga-for-real-beginner or https://www.tindie.com/products/microwavemont/fpga-board-for-i2c-spi-device-prototyping/).

Here it is running on the Microwavemont FPGA board (with USB Serial hookup for output):
![Alt text](MicrowavemontFPGA_w_serial.jpg?raw=true "BenEaterVHDL running on Microwavemont FPGA board (with USB Serial hookup for output)")

The CPU has 8-bits of binary on GPIO pins 1-8 for the "OUT" opcode (also 2 digit hex on seven-segment display for Microwavemont FPGA board) and also has one button to halt the clock and one for reset.  There is also a transmit
only UART output TX on pin 9 (this can be used with a USB serial adapter at 9600 baud 8N1).  The UART will output real-time (with very slow clock) state
of the CPU (very much like the LEDs on the breadboard version).  Here is sample output running this simple program:

     0: 0001 1110   LDA  14     ; load data from memory address 14 into A register
     1: 0010 1111   ADD  15     ; add data from memory address 15 to A register and put result in A
     2: 1110 0000   OUT         ; output A register to OUT port
     3: 1111 0000   HLT         ; halt CPU
     ...
    14: 0001 1000   24          ; the number 24
    15: 0001 0010   18          ; the number 18

Prints this "CPU trace" on a serial terminal 
	
    BE-SAP-VHDL: *RESET*
    T0: => 00000000 => |
        C=0000 M=0000 I=00000000 (NOP) A=00000000 B=00000000 CY=0 O=00000000
    T0: CO => 00000000 => MI |
        C=0000 M=0000 I=00000000 (NOP) A=00000000 B=00000000 CY=0 O=00000000
    T1: RO => 00011110 => II | CE
        C=0001 M=0000 I=00011110 (LDA) A=00000000 B=00000000 CY=0 O=00000000
    T2: IO => 00001110 => MI |
        C=0001 M=1110 I=00011110 (LDA) A=00000000 B=00000000 CY=0 O=00000000
    T3: RO => 00011000 => AI | ID
        C=0001 M=1110 I=00011110 (LDA) A=00011000 B=00000000 CY=0 O=00000000
    T0: CO => 00000001 => MI |
        C=0001 M=0001 I=00011110 (LDA) A=00011000 B=00000000 CY=0 O=00000000
    T1: RO => 00101111 => II | CE
        C=0010 M=0001 I=00101111 (ADD) A=00011000 B=00000000 CY=0 O=00000000
    T2: IO => 00001111 => MI |
        C=0010 M=1111 I=00101111 (ADD) A=00011000 B=00000000 CY=0 O=00000000
    T3: RO => 00010010 => BI |
        C=0010 M=1111 I=00101111 (ADD) A=00011000 B=00010010 CY=0 O=00000000
    T4: EO => 00101010 => AI | ID
        C=0010 M=1111 I=00101111 (ADD) A=00101010 B=00010010 CY=0 O=00000000
    T0: CO => 00000010 => MI |
        C=0010 M=0010 I=00101111 (ADD) A=00101010 B=00010010 CY=0 O=00000000
    T1: RO => 11100000 => II | CE
        C=0011 M=0010 I=11100000 (OUT) A=00101010 B=00010010 CY=0 O=00000000
    T2: AO => 00101010 => OI | ID
        C=0011 M=0010 I=11100000 (OUT) A=00101010 B=00010010 CY=0 O=00101010
    T0: CO => 00000011 => MI |
        C=0011 M=0011 I=11100000 (OUT) A=00101010 B=00010010 CY=0 O=00101010
    T1: RO => 11110000 => II | CE
        C=0100 M=0011 I=11110000 (HLT) A=00101010 B=00010010 CY=0 O=00101010
    T2: => 11110000 => | H
        C=0100 M=0011 I=11110000 (HLT) A=00101010 B=00010010 CY=0 O=00101010
    *HALTED*

It only uses a small amount of FPGA resources and can likely very easily be moved to other FPGAs.

On the MachXO2-1200 here is the resource use:

     Number of registers:    149 out of  1346 (11%)
        PFU registers:          148 out of  1280 (12%)
        PIO registers:            1 out of    66 (2%)
     Number of SLICEs:       146 out of   640 (23%)
        SLICEs as Logic/ROM:    146 out of   640 (23%)
        SLICEs as RAM:            0 out of   480 (0%)
        SLICEs as Carry:         32 out of   640 (5%)
     Number of LUT4s:        288 out of  1280 (23%)
        Number used as logic LUTs:        224
        Number used as distributed RAM:     0
        Number used as ripple logic:       64
        Number used as shift registers:     0
     Number of PIO sites used: 16 + 4(JTAG) out of 22 (91%)
     Number of block RAMs:  2 out of 7 (29%)

-Xark (https://hackaday.io/Xark)

