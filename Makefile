run: build
	G_DEBUG=fatal-criticals gdb -ex run --args build/pulse-flow

build: configure
	ninja -C build

configure:
	[ -f build/build.ninja ] || meson ./build

clean:
	ninja -C build clean

.PHONY: run build configure clean
