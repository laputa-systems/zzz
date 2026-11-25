TARGET ?= x86_64-linux-musl
CPU    ?= baseline
FLAGS   = -OReleaseSmall -fstrip -fno-unwind-tables

zzz: zzz.zig
	zig build-exe $< -target $(TARGET) -mcpu=$(CPU) $(FLAGS) --name $@

PREFIX ?= /usr/local

install: zzz
	mkdir -p $(DESTDIR)$(PREFIX)/bin
	install -m 4755 $< $(DESTDIR)$(PREFIX)/bin/$<

clean:
	rm -f zzz

.PHONY: lint test

lint:
	zig build-exe zzz.zig -target $(TARGET) -mcpu=$(CPU) -fno-emit-bin

test:
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
	test "$$(grep -Fxc 'Maintained by Joshua Li: https://github.com/laputa-systems/zzz' .work/tmp/help-short)" = 1
	test "$$(tail -n 1 .work/tmp/help-short)" = 'Procedure: https://github.com/joshuarli/usr/blob/main/dotfiles/base/.agents/instructions/owned-tools.md'
