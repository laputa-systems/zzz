TARGET ?= x86_64-linux-musl
CPU    ?= baseline
FLAGS   = -OReleaseSmall -fstrip -fno-unwind-tables

zzz: zzz.zig
	zig build-exe $< -target $(TARGET) -mcpu=$(CPU) $(FLAGS) --name $@

PREFIX ?= /usr/local

install: zzz
	install -Dm 4755 $< $(DESTDIR)$(PREFIX)/bin/$<

clean:
	rm -f zzz

ZIG_VERSION ?= 0.16.0
ZIG_OS := $(if $(filter Darwin,$(shell uname -s)),macos,linux)
ZIG_ARCH := $(if $(filter arm64 aarch64,$(shell uname -m)),aarch64,x86_64)
ZIG_DIST := zig-$(ZIG_ARCH)-$(ZIG_OS)-$(ZIG_VERSION)
ZIG_CACHE_DIR ?= $(HOME)/.cache/zzz-zig
ZIG_BIN := $(ZIG_CACHE_DIR)/$(ZIG_DIST)/zig

.PHONY: lint

lint: $(ZIG_BIN)
	$(ZIG_BIN) fmt --check zzz.zig

$(ZIG_BIN):
	mkdir -p $(ZIG_CACHE_DIR)
	curl -fsSL https://ziglang.org/download/$(ZIG_VERSION)/$(ZIG_DIST).tar.xz | tar xJ -C $(ZIG_CACHE_DIR)
