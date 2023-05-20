const Console = @import("HALConsole.zig");
const std = @import("std");

pub const CrashCode = enum {
    RyuUnknownCrash,
};

pub fn Crash(code: CrashCode) noreturn {
    Console.EnableDisable(true);
    Console.Put("System Failure: hart={}; code={} {s}\n", .{ 0, @enumToInt(code), @tagName(code) });
    // Begin Debugger Dump
    Console.Put("Kernel version:\nRyu Kernel Version 0.0.1\n\nSystem halted\n", .{});
    while (true) {}
}
