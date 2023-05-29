const std = @import("std");
const HAL = @import("root").HAL;
const HCB = @import("root").HCB;

pub const IRQLs = enum(u32) {
    IRQL_LOW = 0,
    IRQL_USER_DISPATCH = 1,
    IRQL_KERNEL_DISPATCH = 2,
    IRQL_INTERACTIVE = 3, // IRQL_DEVICE0
    IRQL_BOARDS = 4, // IRQL_DEVICE1
    IRQL_SERIAL = 5, // IRQL_DEVICE2
    IRQL_DISK = 6, // IRQL_DEVICE3
    IRQL_DMA = 7, // IRQL_DEVICE4
    IRQL_DEVICE5 = 8,
    IRQL_DEVICE6 = 9,
    IRQL_DEVICE7 = 10,
    IRQL_DEVICE8 = 11,
    IRQL_DEVICE9 = 12,
    IRQL_PREMPTION_CLOCK = 13,
    IRQL_IPI = 14,
    IRQL_HIGH = 15,
};

pub fn IRQLRaise(newIRQL: IRQLs) IRQLs {
    var oldIRQL = HAL.Arch.GetHCB().currentIRQL;
    if (oldIRQL > newIRQL) {
        HAL.Crash.Crash(.RyuIRQLDemoteWhilePromoting, .{ oldIRQL, newIRQL, 0, 0 });
    }
    HAL.Arch.GetHCB().currentIRQL = newIRQL;
    return oldIRQL;
}

pub fn IRQLLower(oldIRQL: IRQLs) void {
    var curIRQL = HAL.Arch.GetHCB().currentIRQL;
    if (curIRQL < oldIRQL) {
        HAL.Crash.Crash(.RyuIRQLPromoteWhileDemoting, .{ curIRQL, oldIRQL, 0, 0 });
    }
}
