all: compile conflict pipeline bypass cf
# all: compile Functional.tb Scheduling.tb

compile:
	bsc -u -sim -bdir ../work -info-dir ../work -simdir ../work -vdir ../work -aggressive-conditions -keep-fires TestBench.bsv

conflict: compile
	bsc -sim -e mkTbConflictFunctional -bdir ../work -info-dir ../work -simdir ../work -aggressive-conditions -keep-fires -o ../work/simConflictFunctional

pipeline: compile
	bsc -sim -e mkTbPipelineFunctional -bdir ../work -info-dir ../work -simdir ../work -aggressive-conditions -keep-fires -o ../work/simPipelineFunctional
	bsc -sim -e mkTbPipelineScheduling -bdir ../work -info-dir ../work -simdir ../work -aggressive-conditions -keep-fires -o ../work/simPipelineScheduling

bypass: compile
	bsc -sim -e mkTbBypassFunctional -bdir ../work -info-dir ../work -simdir ../work -aggressive-conditions -keep-fires -o ../work/simBypassFunctional
	bsc -sim -e mkTbBypassScheduling -bdir ../work -info-dir ../work -simdir ../work -aggressive-conditions -keep-fires -o ../work/simBypassScheduling

cf: compile
	bsc -sim -e mkTbCFFunctional -bdir ../work -info-dir ../work -simdir ../work -aggressive-conditions -keep-fires -o ../work/simCFFunctional
	bsc -sim -e mkTbCFScheduling -bdir ../work -info-dir ../work -simdir ../work -aggressive-conditions -keep-fires -o ../work/simCFScheduling

%.tb: compile
	bsc -sim -e mkTb$(patsubst %.tb,%,$@) -bdir ../work -info-dir ../work -simdir ../work -o ../work/sim$(patsubst %.tb,%,$@)

clean:
	rm -rf ../work/* sim*

.PHONY: clean all compile %.tb
.DEFAULT_GOAL := all
