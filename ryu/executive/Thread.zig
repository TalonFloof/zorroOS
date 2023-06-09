const Team = @import("root").Executive.Team;
const HAL = @import("root").HAL;
const AATree = @import("root").AATree;
const Spinlock = @import("root").Spinlock;
const Memory = @import("root").Memory;
const std = @import("std");

pub const ThreadState = enum {
    Stopped,
    Debugging,
    Runnable,
    Running,
    Waiting,
};

pub const Thread = struct {
    threadID: i64,
    prevThread: ?*Thread = null,
    nextThread: ?*Thread = null,
    nextTeamThread: ?*Thread = null,
    team: *Team.Team,
    name: [32]u8 = [_]u8{0} ** 32,
    state: ThreadState = .Stopped,
    shouldKill: bool = false,
    context: HAL.Arch.Context = HAL.Arch.Context{},
    fcontext: HAL.Arch.FloatContext = HAL.Arch.FloatContext{},
    kstack: []u8,
    hartID: i32 = -1,
};

const ThreadTreeType = AATree(i64, Thread);

pub var threads: ThreadTreeType = ThreadTreeType{};
var threadLock: Spinlock = .unaquired;
pub var nextThreadID: i64 = 1;

var queueHead: ?*Thread = null;
var queueTail: ?*Thread = null;

pub fn NewThread(
    team: *Team.Team,
    name: []u8,
    ip: usize,
    sp: ?usize,
) *Thread { // If SP is null then this is a kernel thread
    const old = HAL.Arch.IRQEnableDisable(false);
    threadLock.acquire();
    var thread = @ptrCast(*ThreadTreeType.Node, @alignCast(@alignOf(ThreadTreeType.Node), Memory.Pool.PagedPool.Alloc(@sizeOf(ThreadTreeType.Node)).?.ptr));
    @memcpy(@intToPtr([*]u8, @ptrToInt(&thread.value.name)), name);
    thread.value.team = team;
    thread.value.hartID = -1;
    thread.value.threadID = nextThreadID;
    thread.key = nextThreadID;
    nextThreadID += 1;
    thread.value.prevThread = queueTail;
    queueTail = &thread.value;
    thread.value.state = .Runnable;
    var stack = Memory.Pool.PagedPool.AllocAnonPages(16384).?;
    thread.value.kstack = stack;
    if (sp == null) {
        thread.value.context.SetMode(true);
        thread.value.context.SetReg(129, @ptrToInt(stack.ptr) + stack.len);
    } else {
        thread.value.context.SetMode(false);
        thread.value.context.SetReg(129, sp.?);
    }
    thread.value.context.SetReg(128, ip);
    threads.insert(thread);
    threadLock.release();
    _ = HAL.Arch.IRQEnableDisable(old);
    return &thread.value;
}

pub fn Init() void {
    var kteam = Team.GetTeamByID(1).?;
    var i: i32 = 0;
    var buf: [32]u8 = [_]u8{0} ** 32;
    while (i < HAL.hcbList.?.len) : (i += 1) {
        const name = std.fmt.bufPrint(buf[0..32], "Hart #{} Idle Thread", .{i}) catch {
            @panic("Unable to parse string!");
        };
        var thread = NewThread(kteam, name, @ptrToInt(&IdleThread), null);
        thread.hartID = i;
    }
}

pub fn Reschedule() void {
    threadLock.acquire();
    const hcb = HAL.Arch.GetHCB();
    if (hcb.activeThread == null) {
        if (queueHead == null) {
            @panic("Attempted to preform preemptive scheduling with no threads in the queue!");
        }
        hcb.activeThread = queueHead;
    }
    threadLock.release();
}

fn IdleThread() callconv(.C) void {
    while (true) {
        HAL.Arch.WaitForIRQ();
    }
}
