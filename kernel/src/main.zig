const std = @import("std");
const native = @import("native");
pub const alloc = @import("alloc.zig");
pub const Spinlock = @import("spinlock.zig").Spinlock;
pub const hart = @import("hart.zig");

pub const std_options = struct {
    pub const logFn = native.doLog;
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
    std.log.debug("Zorro Kernel\n\n", .{});
    native.initialize();
    @panic("Successfully Booted");
}
