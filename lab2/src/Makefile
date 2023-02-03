compile:
	bsc -u -sim -bdir ../work -info-dir ../work -simdir ../work -vdir ../work -aggressive-conditions TestBench.bsv

fold: compile
	bsc -sim -e mkTbFftFolded -bdir ../work -info-dir ../work -simdir ../work -o ../work/simFold

inelastic: compile
	bsc -sim -e mkTbFftInelasticPipeline -bdir ../work -info-dir ../work -simdir ../work -o ../work/simInelastic

elastic: compile
	bsc -sim -e mkTbFftElasticPipeline -bdir ../work -info-dir ../work -simdir ../work -o ../work/simElastic

sfol: compile
	bsc -sim -e mkTbFftSuperFolded -bdir ../work -info-dir ../work -simdir ../work -o ../work/simSfol

all: fold inelastic elastic sfol

clean:
	rm -rf ../work/* sim*

.PHONY: clean all fold inelastic elastic sfol compile
.DEFAULT_GOAL := all
