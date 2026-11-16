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

.PHONY: test-help

test-help:
	mkdir -p .work/tmp
	zig test zzz.zig -femit-bin=.work/tmp/zzz-test
	zig build-exe zzz.zig -femit-bin=.work/tmp/zzz-help
	.work/tmp/zzz-help -h > .work/tmp/help-short 2> .work/tmp/help-stderr
	test ! -s .work/tmp/help-stderr
	.work/tmp/zzz-help --help > .work/tmp/help-long 2> .work/tmp/help-stderr
	test ! -s .work/tmp/help-stderr
	cmp .work/tmp/help-short .work/tmp/help-long
	ln -sf zzz-help .work/tmp/ZZZ
	.work/tmp/ZZZ -h > .work/tmp/help-alias
	cmp .work/tmp/help-short .work/tmp/help-alias
	.work/tmp/zzz-help -n --help > .work/tmp/help-after-option
	cmp .work/tmp/help-short .work/tmp/help-after-option
	.work/tmp/zzz-help --bad --help > .work/tmp/help-before-validation
	cmp .work/tmp/help-short .work/tmp/help-before-validation
	awk '/^Maintained by Joshua Li: https:\/\/github.com\/laputa-systems\/zzz$$/ { n++ } END { exit n != 1 }' .work/tmp/help-short
	test "$$(tail -n 1 .work/tmp/help-short)" = 'Procedure: https://github.com/joshuarli/usr/blob/main/dotfiles/base/.agents/instructions/owned-tools.md'
