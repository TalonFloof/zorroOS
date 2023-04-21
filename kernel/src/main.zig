const std = @import("std");
const native = @import("native");

pub const std_options = struct {
    pub const logFn = native.doLog;
};

export fn ZorroKernelMain() callconv(.C) noreturn {
    native.earlyInitialize();
    std.log.info("zorroOS Kernel", .{});
    std.log.info("Copyright (C) 2020-2023 TalonFox, Licensed under the MIT License", .{});
    while (true) {}
}
