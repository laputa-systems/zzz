zzz is a single-file Zig program in `zzz.zig` that suspends or hibernates Linux through `/sys/power`.

## Commands

- `make` builds `zzz` for `TARGET` and `CPU`.
- `make lint` runs `zig ast-check zzz.zig`.

## Invariants

- Keep zzz a static musl binary with no libc and no allocation; use `std.os.linux` system calls.
- Keep release targets to `x86_64-linux-musl` and `aarch64-linux-musl`.
- Check sleep permission with `open` for writing, not `access`, so the setuid install works.
- Hold the `/sys/power` lock for the whole sleep cycle.
