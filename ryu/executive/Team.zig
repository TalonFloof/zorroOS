const Thread = @import("root").Executive.Thread;
const Area = @import("root").Executive.Area;
const Memory = @import("root").Memory;
const AATree = @import("root").AATree;
const ELF = @import("root").ELF;
const FS = @import("root").FS;
const HAL = @import("root").HAL;
const Spinlock = @import("root").Spinlock;
const std = @import("std");

pub const FileDescriptor = struct {
    inode: *FS.Inode,
    offset: i64,
};

pub const FDTree = AATree(i64, *FileDescriptor);

pub const Team = struct {
    teamID: i64,
    name: [32]u8 = [_]u8{0} ** 32,
    parent: ?*Team = null,
    children: ?*Team = null,
    siblingNext: ?*Team = null,
    fds: FDTree = FDTree{},
    nextFD: i64 = 1,
    cwd: ?*FS.Inode = null,
    fdLock: Spinlock = .unaquired,
    mainThread: *allowzero Thread.Thread,
    addrLock: Spinlock = .unaquired,
    addressSpace: Memory.Paging.PageDirectory,
};

const TeamTreeType = AATree(i64, *Team);

pub var teams: TeamTreeType = TeamTreeType{};
pub var kteam: ?*Team = null;
pub var teamLock: Spinlock = .unaquired;
pub var nextTeamID: i64 = 1;

pub fn NewTeam(parent: ?*Team, name: []const u8) *Team {
    const old = HAL.Arch.IRQEnableDisable(false);
    teamLock.acquire();
    var team = @as(*Team, @ptrCast(@alignCast(Memory.Pool.PagedPool.Alloc(@sizeOf(Team)).?.ptr)));
    team.addressSpace = Memory.Paging.NewPageDirectory();
    @memcpy(@as([*]u8, @ptrFromInt(@intFromPtr(&team.name))), name);
    team.parent = parent;
    team.nextFD = 1;
    team.fds = FDTree{};
    if (parent) |p| {
        team.cwd = p.cwd;
        team.siblingNext = p.children;
        p.children = team;
    }
    team.teamID = nextTeamID;
    nextTeamID += 1;
    teams.insert(team.teamID, team);
    teamLock.release();
    _ = HAL.Arch.IRQEnableDisable(old);
    return team;
}

pub fn GetTeamByID(id: i64) ?*Team {
    const old = HAL.Arch.IRQEnableDisable(false);
    teamLock.acquire();
    const val = teams.search(id);
    teamLock.release();
    _ = HAL.Arch.IRQEnableDisable(old);
    return val;
}

pub fn DestroyFileDescriptor(k: i64, v: **FileDescriptor) void {
    _ = k;
    FS.DerefInode(v.*.inode);
    Memory.Pool.PagedPool.Free(@as([*]u8, @ptrFromInt(@intFromPtr(v.*)))[0..@sizeOf(FileDescriptor)]);
}

pub fn AdoptTeam(team: *Team, dropTeam: bool) void { // Transfers a team's parent to the Kernel Team
    const old = HAL.Arch.IRQEnableDisable(false);
    teamLock.acquire();
    var index: ?*Team = team.parent.?.children;
    var prev: ?*Team = null;
    while (index) |t| {
        if (@intFromPtr(t) == @intFromPtr(team)) {
            if (prev) |p| {
                p.siblingNext = t.siblingNext;
            } else if (@intFromPtr(team.parent.?.children) == @intFromPtr(team)) {
                team.parent.?.children = team.siblingNext;
            }
            if (!dropTeam) {
                team.parent = kteam.?;
                team.siblingNext = kteam.?.children;
                kteam.?.children = team;
            }
            break;
        }
        prev = t;
        index = t.siblingNext;
    }
    teamLock.release();
    _ = HAL.Arch.IRQEnableDisable(old);
}

pub fn LoadELFImage(path: []const u8, team: *Team) ?usize {
    const old = HAL.Arch.IRQEnableDisable(false);
    if (FS.GetInode(path, FS.rootInode.?)) |inode| {
        FS.RefInode(inode);
        @as(*Spinlock, @ptrCast(&inode.lock)).acquire();
        const buf: []u8 = Memory.Pool.PagedPool.Alloc(@as(usize, @intCast(inode.stat.size))).?;
        _ = inode.read.?(inode, 0, @as(*void, @ptrFromInt(@intFromPtr(buf.ptr))), @as(isize, @intCast(buf.len)));
        @as(*Spinlock, @ptrCast(&inode.lock)).release();
        FS.DerefInode(inode);
        const entry: ?usize = ELF.LoadELF(@as(*void, @ptrCast(buf.ptr)), .Normal, team.addressSpace) catch {
            @panic("Failed to load ELF Image!");
        };
        Memory.Pool.PagedPool.Free(buf);
        var i: usize = 0x1000;
        while (i < 0x10000) : (i += 4096) {
            const page = Memory.PFN.AllocatePage(.Active, true, 0).?;
            _ = Memory.Paging.MapPage(
                team.addressSpace,
                i,
                Memory.Paging.MapRead | Memory.Paging.MapWrite,
                @intFromPtr(page.ptr) - 0xffff800000000000,
            );
        }
        _ = HAL.Arch.IRQEnableDisable(old);
        return entry;
    }
    _ = HAL.Arch.IRQEnableDisable(old);
    return null;
}

pub fn Init() void {
    HAL.Debug.NewDebugCommand("teams", "Lists all of the avaiable teams", &teamsCommand);
    HAL.Debug.NewDebugCommand("team", "Prints out information relating to a team", &teamCommand);
    kteam = NewTeam(null, "Kernel Team");
    _ = NewTeam(kteam, "zorroOS Init Service");
}

fn teamCommand(cmd: []const u8, iter: *std.mem.SplitIterator(u8, .sequence)) void {
    _ = cmd;
    if (iter.next()) |id| {
        const teamID: i64 = std.fmt.parseInt(i64, id, 0) catch {
            HAL.Console.Put("Specified Team ID wasn't a number!\n", .{});
            return;
        };
        if (teams.search(teamID)) |team| {
            const t = @as(*Team, team);
            _ = t;
            HAL.Console.Put("Team #{}: {s}\n", .{ team.teamID, team.name });
            if (team.parent != null) {
                HAL.Console.Put("      Parent 0x{x: <16} (Team #{})\n", .{ @intFromPtr(team.parent), team.parent.?.teamID });
            } else {
                HAL.Console.Put("      Parent 0x{x: <16}\n", .{@intFromPtr(team.parent)});
            }
            if (team.children != null) {
                HAL.Console.Put("    Children 0x{x: <16} (Team #{})\n", .{ @intFromPtr(team.children), team.children.?.teamID });
            } else {
                HAL.Console.Put("    Children 0x{x: <16}\n", .{@intFromPtr(team.children)});
            }
            if (team.siblingNext != null) {
                HAL.Console.Put(" NextSibling 0x{x: <16} (Team #{})\n", .{ @intFromPtr(team.siblingNext), team.siblingNext.?.teamID });
            } else {
                HAL.Console.Put(" NextSibling 0x{x: <16}\n", .{@intFromPtr(team.siblingNext)});
            }
            HAL.Console.Put("  NextFileID 0x{x: <16}  MainThread 0x{x: <16} (Thread #{})\n", .{ @as(u64, @bitCast(team.nextFD)), @intFromPtr(team.mainThread), team.mainThread.threadID });
        } else {
            HAL.Console.Put("Team #{} doesn't exist!\n", .{teamID});
        }
    } else {
        HAL.Console.Put("Usage: team [teamID]\n", .{});
    }
}

fn teamsCommand(cmd: []const u8, iter: *std.mem.SplitIterator(u8, .sequence)) void {
    _ = iter;
    _ = cmd;
    var ind: i64 = 1;
    while (ind < nextTeamID) : (ind += 1) {
        if (teams.search(ind)) |team| {
            HAL.Console.Put("{}: {x:0>16} {s} Parent #{} Main Thread #{}\n", .{
                ind,
                @intFromPtr(team),
                team.name,
                if (team.teamID == 1) 0 else team.parent.?.teamID,
                if (@intFromPtr(team.mainThread) != 0) team.mainThread.threadID else 0,
            });
        }
    }
}
