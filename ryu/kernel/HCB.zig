const HAL = @import("hal");
const Thread = @import("root").Executive.Thread;

pub const HCB = struct {
    activeKstack: u64 = 0,
    activeUstack: u64 = 0,
    activeThread: ?*Thread = null,
    hartID: i32 = 0,
    archData: HAL.Arch.ArchHCBData = HAL.Arch.ArchHCBData{},
};
