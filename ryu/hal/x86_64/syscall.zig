const HAL = @import("root").HAL;

extern const _RyuSyscallHandler: *void;

pub fn init() void {
    HAL.Arch.wrmsr(0xC0000080, HAL.Arch.rdmsr(0xC0000080) | 1);
    HAL.Arch.wrmsr(0xC0000081, (0x28 << 32) | (0x33 << 48));
    HAL.Arch.wrmsr(0xC0000082, @intFromPtr(&_RyuSyscallHandler));
    HAL.Arch.wrmsr(0xC0000084, 0xfffffffe);
}
