const HAL = @import("root").HAL;

pub fn stub() void {} // To ensure that the compiler will not optimize this module out.

pub export fn ExceptionHandler(entry: u8, con: *HAL.Arch.Context, errcode: u32) callconv(.C) void {
    _ = errcode;
    _ = entry;
    if (con.cs == 0x28) {}
}
pub export fn IRQHandler(entry: u8, con: *HAL.Arch.Context) callconv(.C) void {
    _ = entry;
    _ = con;
}
