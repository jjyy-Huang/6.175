compile: clean
	bsc -u -sim -bdir ../work -info-dir ../work -simdir ../work -vdir ../work -aggressive-conditions TestBench.bsv

fifo: compile
	bsc -sim -e mkTestBenchFifo -bdir ../work -info-dir ../work -simdir ../work -o ../work/simFifo

inelastic: compile
	bsc -sim -e mkTbFftInelasticPipeline -bdir ../work -info-dir ../work -simdir ../work -o ../work/simInelastic

elastic: compile
	bsc -sim -e mkTbFftElasticPipeline -bdir ../work -info-dir ../work -simdir ../work -o ../work/simElastic

all: fifo inelastic elastic

clean:
	rm -rf ../work/* sim*

.PHONY: clean all inelastic elastic fifo compile
.DEFAULT_GOAL := all
