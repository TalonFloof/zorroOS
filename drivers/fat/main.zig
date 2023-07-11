const devlib = @import("devlib");
const std = @import("std");

pub export var DriverInfo = devlib.RyuDriverInfo{
    .apiMinor = 1,
    .apiMajor = 0,
    .drvName = "FATFilesystem",
    .exportedDispatch = null,
    .loadFn = &LoadDriver,
    .unloadFn = &UnloadDriver,
};

pub fn LoadDriver() callconv(.C) devlib.Status {}

pub fn UnloadDriver() callconv(.C) devlib.Status {}

pub fn panic(msg: []const u8, stacktrace: ?*std.builtin.StackTrace, wat: ?usize) noreturn {
    _ = wat;
    _ = stacktrace;
    while (true) {
        DriverInfo.krnlDispatch.?.abort(@ptrCast(msg.ptr));
    }
}
