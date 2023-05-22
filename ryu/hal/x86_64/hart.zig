const HCB = @import("root").HCB;
const HAL = @import("root").HAL;
const limine = @import("limine");

export var smp_request: limine.SmpRequest = .{ .flags = 0 };
pub var hartData: usize = 0;

var zeroHCB: HCB = .{};

pub fn initialize(stack: usize) void {
    HAL.Arch.wrmsr(0xC0000102, @ptrToInt(&zeroHCB));
    zeroHCB.archData.tss.rsp[0] = stack;
    zeroHCB.archData.tss.ist[0] = stack;
    zeroHCB.archData.tss.ist[1] = stack;
}

pub fn startSMP() void {
    if (smp_request.response) |smp_response| {
        _ = smp_response;
    }
}
