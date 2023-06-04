const HAL = @import("root").HAL;

pub export fn RyuSyscallDispatch(regs: *HAL.Arch.Context) callconv(.C) void {
    _ = regs;
    //
}

pub fn stub() void { // Doesn't do anything but helps to keep Zig from optimizing this file out

}
