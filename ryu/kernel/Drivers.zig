const devlib = @import("devlib");
const HAL = @import("root").HAL;
const ELF = @import("root").ELF;
const std = @import("std");

pub var drvrHead: ?*devlib.RyuDriverInfo = null;
pub var drvrTail: ?*devlib.RyuDriverInfo = null;

pub fn LoadDriver(name: []const u8, relocObj: *void) void {
    HAL.Console.Put("Loading Driver: {s}...\n", .{name});
    _ = ELF.LoadELF(relocObj, .Driver) catch |err| {
        HAL.Console.Put("Failed to Load Driver \"{s}\", Reason: {}\n", .{ name, err });
        return;
    };
    drvrTail.?.krnlDispatch = &KDriverDispatch;
    var ret = drvrTail.?.loadFn();
    if (ret == .Failure) {
        HAL.Console.Put("Warning: Driver \"{s}\" reported failure while loading!", .{name});
    }
}

pub export const KDriverDispatch = devlib.RyuDispatch{
    .put = &DriverPut,
    .abort = &DriverAbort,
};

fn DriverPut(s: [*:0]const u8) callconv(.C) void {
    HAL.Console.Put("{s}", .{s[0..std.mem.len(s)]});
}

fn DriverAbort(s: [*:0]const u8) callconv(.C) noreturn {
    HAL.Console.Put("DriverAbort: {s}\n", .{s[0..std.mem.len(s)]});
    HAL.Crash.Crash(.RyuDriverAbort, .{ 0, 0, 0, 0 });
}
