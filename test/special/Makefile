
.PHONY: all build clean run

HDL   = ../../packages/svfloat.sv \
		top.sv \
		$(shell find ../../hdl -name '*.sv')

all: run

build: test.c
	mkdir -p build
	gcc $^ -o build/test -lm
	verilator -Wall -Wno-fatal -Werror-PINNOCONNECT -Werror-IMPLICIT -Wno-DECLFILENAME -Wno-VARHIDDEN -Wno-WIDTH -Wno-UNUSED \
		--trace --trace-fst --trace-depth 20 --trace-max-array 256 --trace-max-width 128 \
		-sv --cc --exe --build \
		--top-module top \
		-j $(shell nproc) bench.cpp $(HDL) -o sim

clean:
	rm -rf build obj_dir

run: build
	./build/test
