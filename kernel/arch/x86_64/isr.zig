const std = @import("std");
const context = @import("context.zig");

pub fn stub() void {} // To ensure that the compiler will not optimize this module out.

pub export fn ExceptionHandler(entry: u8, con: *context.ArchContext, errcode: u32) callconv(.C) void {
    std.log.err("Unhandled Exception 0x{x:0>2} (error code: 0x{x}) was triggered!", .{ entry, errcode });
    con.dump();
    @panic("Unexpected Exception!");
}
pub export fn IRQHandler(entry: u8, con: *context.ArchContext) callconv(.C) void {
    _ = con;
    _ = entry;
    std.log.err("IRQ!", .{});
}
