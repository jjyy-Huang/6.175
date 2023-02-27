CONNECTALDIR ?= /workspace/connectal
S2H_INTERFACES = \
	ConnectalProcRequest:ConnectalWrapper.connectProc\
	ConnectalMemoryInitialization:ConnectalWrapper.initProc
H2S_INTERFACES = \
	ConnectalWrapper:ConnectalProcIndication
BSVFILES += \
	src/includes/Ifc.bsv
BSVPATH += / \
	src/ \
	src/includes \
	$(CONNECTALDIR)/bsv
CPPFILES += \
	main.cpp\
	Platform.cpp


SYNTHSCRIPT = yosys -s ./synth.tcl
BSCLIB ?= /opt/bsc/lib

#CONNECTALFLAGS += --mainclockperiod=20
#CONNECTALFLAGS += --verilog=ddr3_v2_0/
SOFTWARE_SOCKET_NAME=/tmp/connectal$(USER)
CONNECTALFLAGS += -D $(VPROC)
CONNECTALFLAGS += --bscflags " -D $(VPROC) -steps-max-intervals 50 +RTS -K256M -RTS"
CONNECTALFLAGS += --bscflags " -show-schedule"
#CONNECTALFLAGS += --cxxflags="-g -std=gnu++11"

include $(CONNECTALDIR)/Makefile.connectal

sim: clean
	$(MAKE) -j32 build.bluesim

.ONESHELL:
gen: clean
	mkdir tmp
	cp ./src/includes/* ./tmp
	cp ./src/$(PROC).bsv ./tmp
	cp $(BSCLIB)/Verilog/FIFOL1.v	./verilog
	cp $(BSCLIB)/Verilog/FIFO1.v	./verilog
	cp $(BSCLIB)/Verilog/FIFO2.v	./verilog
	cp $(BSCLIB)/Verilog/RevertReg.v	./verilog
	cp $(BSCLIB)/Verilog/RegFile.v	./verilog
	cp $(BSCLIB)/Verilog/SizedFIFO.v	./verilog
	cp $(BSCLIB)/Verilog/BRAM2.v	./verilog
	bsc -vdir ./verilog/ -bdir ./tmp/ -verilog -g mkProc -u ./tmp/$(PROC).bsv

VIVADO_CMD = vivado -nolog -nojournal -mode batch -source ./build_prj.tcl -tclargs

.PHONY: build
.ONESHELL:
build:
	@echo "Start building project."
	@$(VIVADO_CMD) $(DEVICE) $(SYNTH_TOP) ./build/${PROC} 2>&1 | tee ./run.log
	@echo "Finish building Vivado project, please check the run.log for details."

.PHONY: synth
.ONESHELL:
synth:
	mkdir ./build/${PROC}/
	export DEVICE=xc7vx485tffg1761-2
	export SYNTH_TOP=mkProc
	@make build

clean:
	rm -rf bluesim tmp ./verilog/*

