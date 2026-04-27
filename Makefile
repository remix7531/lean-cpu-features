.PHONY: all build probe test clean

all: build

build:
	lake build

probe: build
	lake exe probe

test: build
	tests/run.sh

clean:
	lake clean
