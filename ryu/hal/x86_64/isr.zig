const HAL = @import("root").HAL;
const apic = @import("apic.zig");

pub fn stub() void {} // To ensure that the compiler will not optimize this module out.

pub export fn ExceptionHandler(entry: u8, con: *HAL.Arch.Context, errcode: u32) callconv(.C) void {
    _ = errcode;
    if (entry == 0x8) {
        HAL.Crash.Crash(.RyuDoubleFault, .{ con.rip, con.rsp, 0, 0 });
    } else if (entry == 0x2) {
        @panic("Non-maskable Interrupt!");
    }
}
pub export fn IRQHandler(entry: u8, con: *HAL.Arch.Context) callconv(.C) void {
    _ = entry;
    _ = con;
    apic.write(0xb0, 0);
}
