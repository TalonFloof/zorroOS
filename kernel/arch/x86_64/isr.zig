pub export fn ExceptionHandler(entry: u8, context: *void, errcode: u32) callconv(.C) void {
    _ = errcode;
    _ = context;
    _ = entry;
}
pub export fn IRQHandler(entry: u8, context: *void) callconv(.C) void {
    _ = context;
    _ = entry;
}
