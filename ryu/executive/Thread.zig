const Team = @import("root").Executive.Team;
const HAL = @import("root").HAL;
const AATree = @import("root").AATree;

pub const ThreadState = enum {
    Birth,
    Stopped,
    Debugging,
    Runnable,
    Running,
    Locked,
};

pub const Thread = struct {
    threadID: i64,
    prevThread: ?*Thread = null,
    nextThread: ?*Thread = null,
    nextTeamThread: ?*Thread = null,
    team: *Team.Team,
    name: [32]u8 = [_]u8{0} ** 32,
    state: ThreadState = .Birth,
    shouldKill: bool = false,
    context: HAL.Arch.Context = HAL.Arch.Context{},
    fcontext: HAL.Arch.FloatContext = HAL.Arch.FloatContext{},
    kstack: []u8,
};
