# Targets
.PHONY: all prep clean

all: prep bin/life
	@echo "Target all is up to date"

prep:
	@mkdir -p bin build

clean:
	rm -f bin/life build/life.{o,s,ll}

bin/life: build/life.o
	@echo "\033[0;31mLinking executable life\033[0m"
	@clang -O3 $^ -o $@

build/life.o: build/life.s
	@echo "\033[0;32mAssemble\033[0m $<"
	@clang -O3 -c $< -o $@

build/life.s: build/life.ll
	@echo "\033[0;32mAssemble\033[0m $<"
	@clang -O3 -S $< -o $@

build/life.ll: src/life.ll
	@echo "\033[0;32mOptimize\033[0m $<"
	@clang -O3 -S -emit-llvm $< -o $@
