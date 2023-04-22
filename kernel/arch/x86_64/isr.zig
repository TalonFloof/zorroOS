const std = @import("std");

pub fn stub() void {} // To ensure that the compiler will not optimize this module out.

pub export fn ExceptionHandler(entry: u8, context: *allowzero void, errcode: u32) callconv(.C) void {
    _ = errcode;
    _ = context;
    _ = entry;
    std.log.err("Exception!", .{});
}
pub export fn IRQHandler(entry: u8, context: *allowzero void) callconv(.C) void {
    _ = context;
    _ = entry;
    std.log.err("IRQ!", .{});
}
