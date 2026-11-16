# zzz

`zzz` suspends to memory by default; invoking it as `ZZZ` hibernates. Run
`zzz --help` for the complete options and examples. Options can be combined,
and the last mode option selects the action. `-R` and `-H` also select the
hibernate disk mode, which remains selected if a later option changes the action.

Executable hooks in `/etc/zzz.d/suspend` and `/etc/zzz.d/resume` run before
and after the action. `-n` runs the hooks and waits five seconds without changing
the power state. Running a power action requires access to `/sys/power`.
