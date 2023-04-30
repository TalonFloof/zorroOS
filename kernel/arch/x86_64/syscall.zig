const std = @import("std");
const native = @import("root").native;

export fn _ZorroSyscallDispatch() callconv(.C) void {}

extern const _ZorroSyscallHandler: *void;

pub fn initialize() void {
    native.wrmsr(0xC0000080, native.rdmsr(0xC0000080) | 1);
    native.wrmsr(0xC0000081, (0x28 << 32) | (0x33 << 48));
    native.wrmsr(0xC0000082, @ptrToInt(&_ZorroSyscallHandler));
    native.wrmsr(0xC0000084, 0xfffffffe);
}
