.PHONY: build test check format editor clean

build:
	Scripts/build.sh

test:
	Scripts/test.sh

check:
	Scripts/check.sh

format:
	swift format -i --recursive Sources Tests Tools

editor:
	Scripts/compile-commands.sh

clean:
	rm -rf build
