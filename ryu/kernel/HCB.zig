const IRQL = @import("IRQL.zig");
const HAL = @import("hal");

pub const HCB = struct {
    hartID: i32 = 0,
    currentIRQL: IRQL.IRQLs = .IRQL_LOW,
    archData: HAL.Arch.ArchHCBData = HAL.Arch.ArchHCBData{},
};
