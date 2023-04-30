const std = @import("std");
pub const native = @import("native");
pub const alloc = @import("alloc.zig");
pub const Spinlock = @import("spinlock.zig").Spinlock;
pub const hart = @import("hart.zig");

const writer = native.Writer{ .context = .{} };
var writerLock: Spinlock = .unaquired;

pub fn doLog(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    writerLock.acquire("WriterSpinlock");
    _ = scope;
    switch (level) {
        .info => {
            _ = try writer.write("\x1b[36m");
        },
        .warn => {
            _ = try writer.write("\x1b[33m");
        },
        .err => {
            _ = try writer.write("\x1b[31m");
        },
        else => {},
    }
    if (level == .debug) {
        try writer.print(format, args);
    } else {
        try writer.print(level.asText() ++ "\x1b[0m: " ++ format ++ "\n", args);
    }
    writerLock.release();
}

pub const std_options = struct {
    pub const logFn = doLog;
};

pub fn panic(msg: []const u8, stacktrace: ?*std.builtin.StackTrace, wat: ?usize) noreturn {
    _ = wat;
    std.log.debug("\x1b[30;41mpanic\x1b[0m: {s}\n", .{msg});
    if (stacktrace) |trace| {
        std.log.debug("Stack Backtrace:\n", .{});
        for (trace.instruction_addresses) |addr| {
            std.log.debug("  0x{x:0>16}\n", .{addr});
        }
    }
    while (true) { // Infinite loop in case an NMI is triggered
        native.enableDisableInt(false);
        native.halt();
    }
}

export fn ZorroKernelMain() callconv(.C) noreturn {
    native.earlyInitialize();
    std.log.debug("Zorro Kernel \x1b[1;30;40m▀▀\x1b[31;41m▀▀\x1b[32;42m▀▀\x1b[33;43m▀▀\x1b[34;44m▀▀\x1b[35;45m▀▀\x1b[36;46m▀▀\x1b[37;47m▀▀\x1b[0m\n\n", .{});
    native.initialize();
    @panic("No Boot Image");
}
