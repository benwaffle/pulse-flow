run: build
	G_DEBUG=fatal-criticals gdb -ex run --args build/pulse-flow

build: configure
	ninja -C build

configure:
	[ -f build/build.ninja ] || meson ./build

.PHONY: run build configure
