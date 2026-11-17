.PHONY: build test clean

build:
	Scripts/build.sh

test:
	Scripts/test.sh

clean:
	rm -rf build
