const std = @import("std");
const native = @import("native");

pub const std_options = struct {
    pub const logFn = native.doLog;
};

pub fn panic(msg: []const u8, stacktrace: ?*std.builtin.StackTrace, wat: ?usize) noreturn {
    _ = wat;
    std.log.err("panic: {s}", .{msg});
    if (stacktrace) |trace| {
        _ = trace;
    }
    while (true) { // Infinite loop in case an NMI is triggered
        native.enableDisableInt(false);
        native.halt();
    }
}

export fn ZorroKernelMain() callconv(.C) noreturn {
    native.earlyInitialize();
    std.log.info("zorroOS Kernel", .{});
    std.log.info("Copyright (C) 2020-2023 TalonFox, Licensed under the MIT License", .{});
    @panic("Kernel booted sucessfully");
}
