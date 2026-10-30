# zzz

zzz suspends or hibernates a Linux machine by writing to `/sys/power`. It is a
single-file Zig program built as a static musl binary and installed setuid root.

## Usage

```
zzz [-nSzZRH]
```

- `-z` suspend to RAM (default).
- `-S` standby (`freeze`).
- `-Z` hibernate with the platform disk mode.
- `-R` hibernate and reboot.
- `-H` hibernate with hybrid suspend.
- `-n` do nothing except run the hooks and sleep five seconds.

When invoked as `ZZZ`, the default mode is hibernate.

zzz refuses to run when the kernel does not support the requested state, when
`/sys/power/state` is not writable, or when another instance holds the lock on
`/sys/power`.

## Hooks

Executable files in `/etc/zzz.d/suspend` run before the machine sleeps and
files in `/etc/zzz.d/resume` run after it wakes. Hooks run one at a time in
directory order; their exit status is ignored.

## Build

```
make
make TARGET=aarch64-linux-musl CPU=cortex_a53
make install PREFIX=/usr/local
```

`make install` installs the binary with mode 4755. `make lint` runs
`zig ast-check` on the source.

## Release

The `build` workflow is dispatched manually on the default branch. It builds
the `x86_64` and `aarch64` musl binaries, rejects dynamically linked ELF
files, and publishes a `release-<sha>` prerelease with one zip per target and a
`SHA256SUMS` file.
