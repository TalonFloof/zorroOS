const HCB = @import("root").HCB;
const HAL = @import("root").HAL;

var zeroHCB: HCB = .{};

pub fn initialize(stack: usize) void {
    HAL.Arch.wrmsr(0xC0000102, @ptrToInt(&zeroHCB));
    zeroHCB.archData.tss.rsp[0] = stack;
    zeroHCB.archData.tss.ist[0] = stack;
    zeroHCB.archData.tss.ist[1] = stack;
}
