const Thread = @import("root").Executive.Thread;
const Area = @import("root").Executive.Area;
const Memory = @import("root").Memory;
const AATree = @import("root").AATree;
const HAL = @import("root").HAL;
const Spinlock = @import("root").Spinlock;

pub const Team = struct {
    teamID: i64,
    name: [32]u8 = [_]u8{0} ** 32,
    parent: ?*Team = null,
    children: ?*Team = null,
    siblingNext: ?*Team = null,
    mainThread: *allowzero Thread.Thread,
    addressSpace: Memory.Paging.PageDirectory,
};

const TeamTreeType = AATree(i64, Team);

pub var teams: TeamTreeType = TeamTreeType{};
var teamLock: Spinlock = .unaquired;
pub var nextTeamID: i64 = 1;

pub fn NewTeam(parent: ?*Team, name: []const u8) *Team {
    const old = HAL.Arch.IRQEnableDisable(false);
    teamLock.acquire();
    var team = @ptrCast(*TeamTreeType.Node, @alignCast(@alignOf(TeamTreeType.Node), Memory.Pool.PagedPool.Alloc(@sizeOf(TeamTreeType.Node)).?.ptr));
    team.value.addressSpace = Memory.Paging.NewPageDirectory();
    @memcpy(@intToPtr([*]u8, @ptrToInt(&team.value.name)), name);
    team.value.parent = parent;
    if (parent) |p| {
        team.value.siblingNext = p;
        p.children = &team.value;
    }
    team.key = nextTeamID;
    team.value.teamID = nextTeamID;
    nextTeamID += 1;
    teams.insert(team);
    teamLock.release();
    _ = HAL.Arch.IRQEnableDisable(old);
    return &team.value;
}

pub fn GetTeamByID(id: i64) ?*Team {
    const old = HAL.Arch.IRQEnableDisable(false);
    teamLock.acquire();
    const val = teams.search(id);
    teamLock.release();
    _ = HAL.Arch.IRQEnableDisable(old);
    if (val) |v| {
        return &v.value;
    } else {
        return null;
    }
}

pub fn Init() void {
    _ = NewTeam(null, "Kernel Team");
}
