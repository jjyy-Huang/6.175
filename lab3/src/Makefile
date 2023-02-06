testbenches=Dumb.tb FoldedMultiplier.tb SignedVsUnsigned.tb Ex3.tb Ex5.tb Ex7a.tb Ex7b.tb Ex9a.tb Ex9b.tb

compile:
	bsc -u -sim -bdir ../work -info-dir ../work -simdir ../work -vdir ../work -aggressive-conditions -keep-fires TestBench.bsv

%.tb: compile
	bsc -sim -e mkTb$(patsubst %.tb,%,$@) -bdir ../work -info-dir ../work -simdir ../work -aggressive-conditions -keep-fires -o ../work/sim$(patsubst %.tb,%,$@) ../work/*.ba

all: $(testbenches)

clean:
	rm -rf ../work/ sim*

.PHONY: clean all add compile %.tb
.DEFAULT_GOAL := all
