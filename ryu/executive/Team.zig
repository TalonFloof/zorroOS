const Thread = @import("root").Executive.Thread;
const Area = @import("root").Executive.Area;
const Memory = @import("root").Memory;
const AATree = @import("root").AATree;

pub const Team = extern struct {
    teamID: i64,
    name: [32]u8 = [_]u8{0} ** 32,
    parent: ?*Team = null,
    children: ?*Team = null,
    siblingNext: ?*Team = null,
    mainThread: *allowzero Thread.Thread,
    addressSpace: Memory.Paging.PageDirectory,
    firstFree: u64 = 0x1000, // Temporary, will be replaced with a better system later.
};
