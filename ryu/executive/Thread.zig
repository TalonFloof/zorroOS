const Team = @import("root").Executive.Team;
const HAL = @import("root").HAL;

pub const ThreadState = enum {
    Birth,
    Stopped,
    Debugging,
    Runnable,
    Running,
    Locked,
};

pub const Thread = extern struct {
    threadID: i64,
    nextThread: ?*Thread = null,
    team: *Team.Team,
    name: [32]u8 = [_]u8{0} ** 32,
    state: ThreadState = .Birth,
    context: HAL.Arch.Context = HAL.Arch.Context{},
    fcontext: HAL.Arch.FloatContext = HAL.Arch.FloatContext{},
    kstack: [16384]u8 = [_]u8{0} ** 16384,
};
