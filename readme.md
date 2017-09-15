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

This is a simple educational 8-bit CPU with a 4-bit address bus (so 16 memory locations for program and data).  It is controlled by "microcode" that asserts the proper control signals to make the CPU function and define the instructions.

Here are the instructions currently implemented:

    0000 xxxx   NOP             no-operation                    3 cycles
    0001 mmmm   LDA M           A = RAM[M]                      4 cycles
    0010 mmmm   ADD M           A = A+RAM[M] (updates carry)    5 cycles
    0011 mmmm   SUB M           A = A-RAM[M] (updates carry)    5 cycles
    0100 mmmm   STA M           RAM[M] = A                      4 cycles
    0101 nnnn   LDI N           A = N (4-LSB)                   3 cycles
    0110 mmmm   JMP M           PC = M                          3 cycles
    0111 mmmm   JCS M           if (carry) then PC = M          3 cycles
    1000 xxxx   ??? (unused, acts like NOP)
    1001 xxxx   ??? (unused, acts like NOP)
    1010 xxxx   ??? (unused, acts like NOP)
    1011 xxxx   ??? (unused, acts like NOP)
    1100 xxxx   ??? (unused, acts like NOP)
    1101 xxxx   ??? (unused, acts like NOP)
    1110 xxxx   OUT             output A register               3 cycles
    1111 xxxx   HLT             halt CPU clock                  3 cycles    

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
    T2: => 00000000 => | H
        C=0100 M=0011 I=11110000 (HLT) A=00101010 B=00010010 CY=0 O=00101010
    *HALTED*
	
NOTE: The TinyFPGA-A2 board does not have a clock source other than the internal oscillator.  This oscillator can vary by +/-5% (per datasheet).  If you get "unlucky" it is possible that the oscillator will be off too much for reliable 9600 baud communication.  Of the three XO2 parts I tried, two worked fine, but one printed garbage.  I hooked up a logic analyzer and found that its 9600 baud was closer to 10525 baud.  When I entered this into my terminal program (Tera Term), the "garbage" decoded fine.  If you have trouble, you may be able to "guess" a few hundred baud faster or slower and get it working.

UPDATE: Due to the above issue (and to allow baud rates other than 9600), there is now simple optional "auto-baud" functionality enabled (but still defaults to 9600 baud).  To use this hook "pin10_sda" for TinyFPGA-A2 or "scl" for MicrowavemontFPGA to the TX of the serial adapter (i.e., TX from PC is RX into FPGA).  Then type "U" (ideally) a few times into the terminal program after reset and the FPGA should switch to match the incoming baud rate.  This will compensate for TinyFPGA internal oscillator speed as well as allow other baud rates (e.g., 115,200).

This design uses a fairly small amount of FPGA resources and should be very easily be moved to other FPGAs.

On the MachXO2-1200 here is the resource use (on TinyFPGA-A2 board):

    Number of registers:    152 out of  1346 (11%)
      PFU registers:          151 out of  1280 (12%)
      PIO registers:            1 out of    66 (2%)
    Number of SLICEs:       141 out of   640 (22%)
      SLICEs as Logic/ROM:    141 out of   640 (22%)
      SLICEs as RAM:            0 out of   480 (0%)
      SLICEs as Carry:         27 out of   640 (4%)
    Number of LUT4s:        278 out of  1280 (22%)
      Number used as logic LUTs:        224
      Number used as distributed RAM:     0
      Number used as ripple logic:       54
      Number used as shift registers:     0
    Number of PIO sites used: 16 + 4(JTAG) out of 22 (91%)
    Number of block RAMs:  2 out of 7 (29%)

                                 LUT4              PFU Registers     IO Registers      EBR               Carry Cells       SLICE             
    TinyFPGA_top(TinyFPGA_top)   224(28)           151(31)           1(1)              2(0)              27(10)            141(24.83)        
        system(sys)              196(1)            120(0)            0(0)              2(0)              17(0)             116.17(0.330002)  
            cpu(CPU)             122(111)          71(39)            0(0)              0(0)              5(0)              66.67(52.75)      
                reg8_0(a_reg)    1(1)              8(8)              0(0)              0(0)              0(0)              2.75(2.75)        
                alu(alu_unit)    0(0)              0(0)              0(0)              0(0)              5(5)              2.5(2.5)          
                reg8_1(b_reg)    1(1)              8(8)              0(0)              0(0)              0(0)              2.25(2.25)        
                reg8(i_reg)      1(1)              8(8)              0(0)              0(0)              0(0)              2.25(2.25)        
                reg4(mar_reg)    1(1)              4(4)              0(0)              0(0)              0(0)              1.42(1.42)        
                counter4(pc_reg) 7(7)              4(4)              0(0)              0(0)              0(0)              2.75(2.75)        
            cpu_trace(TRACE)     54(54)            27(27)            0(0)              1(1)              6(6)              34.17(34.17)      
            tx_uart(UART)        19(19)            22(22)            0(0)              0(0)              6(6)              15(15)            
            RAM(bram)            0(0)              0(0)              0(0)              1(1)              0(0)              0(0)              
   
-Xark (https://hackaday.io/Xark)

