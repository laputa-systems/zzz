const std = @import("std");
const linux = std.os.linux;

const Mode = enum {
    noop,
    standby,
    @"suspend",
    hibernate,
};

const HibernateMode = enum {
    platform,
    reboot,
    suspend_hybrid,
};

const Option = struct {
    flag: u8,
    description: []const u8,
    mode: Mode,
    hibernate_mode: ?HibernateMode = null,
    example: []const u8,
};

const options = [_]Option{
    .{ .flag = 'n', .description = "Run hooks without changing power state (wait five seconds).", .mode = .noop, .example = "zzz -n" },
    .{ .flag = 'S', .description = "Enter standby (freeze).", .mode = .standby, .example = "zzz -S" },
    .{ .flag = 'z', .description = "Suspend to memory (default for zzz).", .mode = .@"suspend", .example = "zzz -z" },
    .{ .flag = 'Z', .description = "Hibernate using the selected disk mode (default for ZZZ; disk mode: platform).", .mode = .hibernate, .example = "zzz -Z" },
    .{ .flag = 'R', .description = "Hibernate using reboot disk mode.", .mode = .hibernate, .hibernate_mode = .reboot, .example = "zzz -R" },
    .{ .flag = 'H', .description = "Hibernate using suspend-hybrid disk mode.", .mode = .hibernate, .hibernate_mode = .suspend_hybrid, .example = "zzz -H" },
};

const footer = "Maintained by Joshua Li: https://github.com/laputa-systems/zzz\n" ++
    "Bugs and features: TODO.md in that repository (follow its AGENTS.md), or its issue tracker.\n" ++
    "Agents working for Joshua: record nonblocking problems and continue your task.\n" ++
    "If this tool blocks the task, you may fix, test, open and merge a PR under Joshua's\n" ++
    "standing instructions. Release only when needed to deliver the verified fix.\n" ++
    "Procedure: https://github.com/joshuarli/usr/blob/main/dotfiles/base/.agents/instructions/owned-tools.md\n";

fn helpText() []const u8 {
    @setEvalBranchQuota(10000);
    return comptime blk: {
        var text: []const u8 = "Usage: zzz [OPTIONS]\n       ZZZ [OPTIONS]\n\nSuspend or hibernate the system, running hooks before and after.\nOptions may be combined; the last mode option wins. The selected hibernation\ndisk mode remains in effect until another disk mode option changes it.\n\nOptions:\n  -h, --help  Show this help and exit.\n";
        for (options) |option| {
            text = text ++ "  -" ++ &[_]u8{option.flag} ++ "  " ++ option.description ++ "\n";
        }
        text = text ++ "\nExamples:\n  zzz\n  ZZZ\n";
        for (options) |option| text = text ++ "  " ++ option.example ++ "\n";
        break :blk text ++ "\n" ++ footer;
    };
}

const Selection = struct {
    mode: Mode,
    hibernate_mode: HibernateMode = .platform,
};

fn parseArg(selection: *Selection, arg: []const u8) bool {
    if (arg.len < 2 or arg[0] != '-') return false;
    for (arg[1..]) |c| {
        var matched = false;
        for (options) |option| {
            if (c == option.flag) {
                selection.mode = option.mode;
                if (option.hibernate_mode) |disk_mode| selection.hibernate_mode = disk_mode;
                matched = true;
                break;
            }
        }
        if (!matched) return false;
    }
    return true;
}

const sys_power = "/sys/power";

fn fatal(msg: []const u8) noreturn {
    _ = linux.write(2, msg.ptr, msg.len);
    linux.exit(1);
}

fn prognam(arg0: []const u8) []const u8 {
    return if (std.mem.lastIndexOfScalar(u8, arg0, '/')) |i|
        arg0[i + 1 ..]
    else
        arg0;
}

fn stateSupports(needle: []const u8) bool {
    const fd = linux.open(sys_power ++ "/state", .{}, 0);
    if (fd >= ~@as(usize, 4095)) return false;
    defer _ = linux.close(@intCast(fd));

    var buf: [256]u8 = undefined;
    const n = linux.read(@intCast(fd), &buf, buf.len);
    if (n >= ~@as(usize, 4095)) return false;
    return std.mem.indexOf(u8, buf[0..n], needle) != null;
}

fn writeSysfs(path: [*:0]const u8, value: []const u8) void {
    const fd = linux.open(path, .{ .ACCMODE = .WRONLY }, 0);
    if (fd >= ~@as(usize, 4095)) return;
    defer _ = linux.close(@intCast(fd));
    _ = linux.write(@intCast(fd), value.ptr, value.len);
}

fn runHooks(dirpath: [*:0]const u8) void {
    const dirfd = linux.open(dirpath, .{ .DIRECTORY = true }, 0);
    if (dirfd >= ~@as(usize, 4095)) return;
    defer _ = linux.close(@intCast(dirfd));

    var buf: [4096]u8 align(@alignOf(linux.dirent64)) = undefined;
    while (true) {
        const n = linux.getdents64(@intCast(dirfd), &buf, buf.len);
        if (n >= ~@as(usize, 4095) or n == 0) break;
        var pos: usize = 0;
        while (pos < n) {
            const d: *linux.dirent64 = @ptrCast(@alignCast(&buf[pos]));
            pos += d.reclen;
            const name = std.mem.sliceTo(@as([*:0]u8, @ptrCast(&d.name)), 0);
            if (name[0] == '.') continue;
            if (d.type != linux.DT.REG and d.type != linux.DT.UNKNOWN) continue;

            var path_buf: [512]u8 = undefined;
            const path = std.mem.printSentinel(&path_buf, "{s}/{s}", .{ dirpath, name }, 0) catch continue;

            if (linux.access(path, linux.X_OK) != 0) continue;

            const pid = linux.fork();
            if (pid == 0) {
                _ = linux.execve(path, @ptrCast(&[_:null]?[*:0]u8{ @ptrCast(path.ptr), null }), @ptrCast(&[_:null]?[*:0]u8{null}));
                linux.exit(1);
            }
            if (pid != ~@as(usize, 0)) {
                var status: i32 = 0;
                _ = linux.wait4(@intCast(pid), &status, 0, null);
            }
        }
    }
}

pub fn main(init: std.process.Init.Minimal) void {
    var args_iter = std.process.Args.iterate(init.args);

    const arg0 = args_iter.next() orelse "zzz";
    const name = prognam(arg0);

    var selection = Selection{ .mode = if (std.mem.eql(u8, name, "ZZZ")) .hibernate else .@"suspend" };

    var help_iter = std.process.Args.iterate(init.args);
    _ = help_iter.next();
    while (help_iter.next()) |arg| {
        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            const help = helpText();
            _ = linux.write(1, help.ptr, help.len);
            return;
        }
    }
    while (args_iter.next()) |arg| {
        if (!parseArg(&selection, arg)) fatal("bad arg\n");
    }
    const mode = selection.mode;
    const hiber_mode = selection.hibernate_mode;

    switch (mode) {
        .@"suspend" => if (!stateSupports("mem")) fatal("suspend not supported\n"),
        .hibernate => if (!stateSupports("disk")) fatal("hibernate not supported\n"),
        else => {},
    }

    // Use open() rather than access() — access() checks real UID, so it
    // rejects setuid-root binaries even though the actual writes would
    // succeed. open(WRONLY) tests the effective UID instead.
    const checkfd = linux.open(sys_power ++ "/state", .{ .ACCMODE = .WRONLY }, 0);
    if (checkfd >= ~@as(usize, 4095))
        fatal("sleep permission denied\n");
    _ = linux.close(@intCast(checkfd));

    // flock /sys/power
    const lockfd = linux.open(sys_power, .{}, 0);
    if (lockfd >= ~@as(usize, 4095)) fatal("cannot open /sys/power\n");
    defer _ = linux.close(@intCast(lockfd));

    if (linux.flock(@intCast(lockfd), 2 | 4) != 0) // LOCK_EX | LOCK_NB
        fatal("another instance of zzz is running\n");
    defer _ = linux.flock(@intCast(lockfd), 8); // LOCK_UN

    _ = linux.write(1, "Zzzz... ", 8);

    runHooks("/etc/zzz.d/suspend");

    switch (mode) {
        .standby => writeSysfs(sys_power ++ "/state", "freeze"),
        .@"suspend" => writeSysfs(sys_power ++ "/state", "mem"),
        .hibernate => {
            const disk_mode: []const u8 = switch (hiber_mode) {
                .platform => "platform",
                .reboot => "reboot",
                .suspend_hybrid => "suspend",
            };
            writeSysfs(sys_power ++ "/disk", disk_mode);
            writeSysfs(sys_power ++ "/state", "disk");
        },
        .noop => {
            var ts: linux.timespec = .{ .sec = 5, .nsec = 0 };
            _ = linux.nanosleep(&ts, null);
        },
    }

    runHooks("/etc/zzz.d/resume");

    _ = linux.write(1, "yawn.\n", 6);
}

test "examples parse without power effects" {
    for (options, 0..) |option, i| {
        for (options[0..i]) |previous| try std.testing.expect(previous.flag != option.flag);
        var selection = Selection{ .mode = .@"suspend" };
        try std.testing.expect(std.mem.startsWith(u8, option.example, "zzz "));
        try std.testing.expect(parseArg(&selection, option.example[4..]));
        try std.testing.expectEqual(option.mode, selection.mode);
        try std.testing.expectEqual(option.hibernate_mode orelse .platform, selection.hibernate_mode);
    }
    var selection = Selection{ .mode = .@"suspend" };
    try std.testing.expect(parseArg(&selection, "-RHZ"));
    try std.testing.expectEqual(Mode.hibernate, selection.mode);
    try std.testing.expectEqual(HibernateMode.suspend_hybrid, selection.hibernate_mode);
    try std.testing.expect(!parseArg(&selection, "--bad"));
}

test "help contains options examples and one final footer" {
    const help = helpText();
    try std.testing.expect(std.mem.startsWith(u8, help, "Usage: zzz"));
    try std.testing.expect(std.mem.indexOf(u8, help, "\nExamples:\n") != null);
    for (options) |option| {
        try std.testing.expect(std.mem.indexOf(u8, help, option.description) != null);
        try std.testing.expect(std.mem.indexOf(u8, help, option.example) != null);
    }
    try std.testing.expect(std.mem.endsWith(u8, help, footer));
    try std.testing.expectEqual(@as(usize, 1), std.mem.count(u8, help, "Maintained by Joshua Li:"));
}
