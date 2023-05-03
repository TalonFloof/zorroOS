const std = @import("std");
const native = @import("main.zig");
const root = @import("root");
const context = @import("context.zig");
const apic = @import("apic.zig");
const hart = @import("hart.zig");

pub fn stub() void {} // To ensure that the compiler will not optimize this module out.

var cursorBlink: u16 = 0;

pub export fn ExceptionHandler(entry: u8, con: *context.Context, errcode: u32) callconv(.C) void {
    if (entry == 0x2) {
        std.log.warn("A legacy non-maskable interrupt was triggered. This may be an indication of a hardware failure.", .{});
    } else {
        std.log.err("Unhandled Exception 0x{x:0>2} (error code: 0x{x}) was triggered!", .{ entry, errcode });
        con.dump();
        @panic("Unexpected Exception!");
    }
}
pub export fn IRQHandler(entry: u8, con: *context.Context) callconv(.C) void {
    _ = con;
    if (entry == 0xf0) {
        std.log.warn("Local APIC on hart#{d} triggered a non-maskable interrupt. This may be an indication of a hardware failure.", .{hart.getHart().id});
        return;
    } else if (entry == 0x20) { // Local APIC Timer
        if (hart.getHart().id == 0) {
            cursorBlink = (cursorBlink + 1) % 1000;
            if ((cursorBlink % 500) == 250) {
                try root.writer.writeAll("\x1b[?25l");
            } else if ((cursorBlink % 500) == 0) {
                try root.writer.writeAll("\x1b[?25h");
            }
        }
    }
    apic.write(0xb0, 0);
}
