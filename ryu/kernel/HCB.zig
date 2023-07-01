const HAL = @import("hal");
const Thread = @import("root").Executive.Thread.Thread;
const Memory = @import("root").Memory;

pub const HCB = struct {
    activeUstack: u64 = 0,
    activeKstack: u64 = 0,
    activeIStack: u64 = 0,
    activeThread: ?*Thread = null,
    quantumsLeft: u32 = 0,
    hartID: i32 = 0,
    archData: HAL.Arch.ArchHCBData = HAL.Arch.ArchHCBData{},
};
