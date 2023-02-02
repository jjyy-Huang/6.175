compile:
	bsc -u -sim -bdir ../work -info-dir ../work -simdir ../work -vdir ../work -aggressive-conditions TestBench.bsv

mux: compile
	bsc -sim -e mkTbMux -bdir ../work -info-dir ../work -simdir ../work -o ../work/simMux ../work/*.ba

muxsimple: compile
	bsc -sim -e mkTbMuxSimple -bdir ../work -info-dir ../work -simdir ../work -o ../work/simMuxSimple ../work/*.ba

rca: compile
	bsc -sim -e mkTbRCA -bdir ../work -info-dir ../work -simdir ../work -o ../work/simRca ../work/*.ba

rcasimple: compile
	bsc -sim -e mkTbRCASimple -bdir ../work -info-dir ../work -simdir ../work -o ../work/simRcaSimple ../work/*.ba

csa: compile
	bsc -sim -e mkTbCSA -bdir ../work -info-dir ../work -simdir ../work -o ../work/simCsa ../work/*.ba

csasimple: compile
	bsc -sim -e mkTbCSASimple -bdir ../work -info-dir ../work -simdir ../work -o ../work/simCsaSimple ../work/*.ba

all: mux muxsimple rca rcasimple csa csasimple

clean:
	rm -rf ../work/* sim*

.PHONY: clean all add compile
.DEFAULT_GOAL := all