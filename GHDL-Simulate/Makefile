GHDL=/cygdrive/c/Users/kenj/Downloads/ghdl-0.35-mcode-windows/bin/ghdl
#GHDL=../../bin/ghdl
GHDLFLAGS=--ieee=standard --std=08 --workdir=ghdlwork
VHDLFILES=$(wildcard ../VHDL/*.vhd)
TBFILES=$(wildcard ../VHDL-testbench/*.vhd)
TBTOP=system_tb
OFILES=$(VHDLFILES:.vhd=.o) $(TBFILES:.vhd=.o)

system_tb: $(VHDLFILES) $(TBFILES)
	mkdir -p ghdlwork
	$(GHDL) -i $(GHDLFLAGS) $^
	$(GHDL) -m $(GHDLFLAGS) $(TBTOP)
	$(GHDL) -r $(GHDLFLAGS) $(TBTOP) --stop-time=1ms --vcd=system_tb.vcdgz | grep -v VHDL

clean:
	echo "Cleaning up..."
	rm -rf *.o ghdlwork
