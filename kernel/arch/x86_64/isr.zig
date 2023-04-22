const std = @import("std");

export fn ExceptionHandler(entry: u8, context: *void, errcode: u32) void {
    _ = errcode;
    _ = context;
    _ = entry;
    std.log.err("Exception!", .{});
}
export fn IRQHandler(entry: u8, context: *void) void {
    _ = context;
    _ = entry;
    std.log.err("IRQ!", .{});
}
