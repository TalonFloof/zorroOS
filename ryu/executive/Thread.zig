const Team = @import("root").Executive.Team;
const HAL = @import("root").HAL;
const AATree = @import("root").AATree;
const Spinlock = @import("root").Spinlock;
const Memory = @import("root").Memory;
const EventQueue = @import("root").Executive.EventQueue;
const std = @import("std");

pub const ThreadState = enum {
    Stopped,
    Debugging,
    Runnable,
    Running,
    Eeping, // :3
    WaitingForEvent,
};

pub const Thread = struct {
    threadID: i64,
    prevThread: ?*Thread = null,
    nextThread: ?*Thread = null,
    prevTeamThread: ?*Thread = null,
    nextTeamThread: ?*Thread = null,
    nextEventThread: ?*Thread = null,
    team: *Team.Team,
    name: [32]u8 = [_]u8{0} ** 32,
    state: ThreadState = .Stopped,
    waitType: i64 = -2, // >0 is waiting for specific child thread, 0 is waiting for any thread within our team, -1 is any thread within our team or our child teams
    eventQueue: EventQueue = EventQueue{},
    exitReason: usize = 0,
    shouldKill: bool = false,
    priority: usize = 10,
    eepTimeout: u64 = 0,
    context: HAL.Arch.Context = HAL.Arch.Context{},
    fcontext: HAL.Arch.FloatContext = HAL.Arch.FloatContext{},
    activeUstack: usize = 0,
    kstack: []u8,
    hartID: i32 = -1,
};

const ThreadTreeType = AATree(i64, *Thread);

pub var threads: ThreadTreeType = ThreadTreeType{};
var threadLock: Spinlock = .unaquired;
pub var nextThreadID: i64 = 1;
pub var debugThread: usize = 0;
pub var debugQueue: EventQueue = EventQueue{};

pub var startScheduler: bool = false;

pub var ticks: u64 = 0;

pub const Queue = struct {
    lock: Spinlock = .unaquired,
    head: ?*Thread = null,
    tail: ?*Thread = null,

    pub fn Add(self: *Queue, t: *Thread) void {
        t.nextThread = null;
        t.prevThread = self.tail;
        if (self.tail != null) { // hehehe tail owo~
            self.tail.?.nextThread = t;
        }
        self.tail = t;
        if (self.head == null) {
            self.head = t;
        }
    }

    pub fn Remove(self: *Queue, t: *Thread) void {
        if (t.nextThread) |nxt| {
            nxt.prevThread = t.prevThread;
        }
        if (t.prevThread) |prev| {
            prev.nextThread = t.nextThread;
        }
        if (@intFromPtr(self.head) == @intFromPtr(t)) {
            self.head = t.nextThread;
        }
        if (@intFromPtr(self.tail) == @intFromPtr(t)) {
            self.tail = t.prevThread;
        }
        t.nextThread = null;
        t.prevThread = null;
    }
};

pub var queues: [16]Queue = [_]Queue{Queue{}} ** 16;

pub fn NewThread(
    team: *Team.Team,
    name: []u8,
    ip: usize,
    sp: ?usize,
    prior: usize,
) *Thread { // If SP is null then this is a kernel thread
    const old = HAL.Arch.IRQEnableDisable(false);
    threadLock.acquire();
    var thread = @as(*Thread, @ptrCast(@alignCast(Memory.Pool.PagedPool.Alloc(@sizeOf(Thread)).?.ptr)));
    @memset(@as([*]u8, @ptrFromInt(@intFromPtr(&thread.name)))[0..32], 0);
    @memcpy(@as([*]u8, @ptrFromInt(@intFromPtr(&thread.name))), name);
    thread.team = team;
    thread.hartID = -1;
    thread.threadID = nextThreadID;
    thread.exitReason = ~@as(usize, @intCast(0));
    thread.waitType = -2;
    nextThreadID += 1;
    thread.state = .Runnable;
    thread.priority = prior;
    var stack = Memory.Pool.PagedPool.AllocAnonPages(32768).?;
    thread.kstack = stack;
    if (sp == null) {
        thread.context.SetMode(true);
        thread.context.SetReg(129, @intFromPtr(stack.ptr) + stack.len);
    } else {
        thread.context.SetMode(false);
        thread.context.SetReg(129, sp.?);
    }
    @memset(@as([*]u8, @ptrFromInt(@intFromPtr(&thread.fcontext.data)))[0..512], 0);
    thread.context.SetReg(128, ip);
    if (@intFromPtr(team.mainThread) == 0) {
        team.mainThread = thread;
    } else {
        thread.prevTeamThread = team.mainThread;
        thread.nextTeamThread = team.mainThread.nextTeamThread;
        if (team.mainThread.nextTeamThread) |next| {
            next.prevTeamThread = thread;
        }
        team.mainThread.nextTeamThread = thread;
    }
    threads.insert(thread.threadID, thread);
    queues[prior].lock.acquire();
    queues[prior].Add(thread);
    queues[prior].lock.release();
    threadLock.release();
    _ = HAL.Arch.IRQEnableDisable(old);
    return thread;
}

pub fn KillThread(threadID: i64) void {
    const old = HAL.Arch.IRQEnableDisable(false);
    threadLock.acquire();
    if (threads.search(threadID)) |thread| {
        if (thread.state == .Runnable) {
            const oldPriority = thread.priority;
            queues[oldPriority].lock.acquire();
            queues[15].lock.acquire();
            thread.priority = 15;
            thread.shouldKill = true;
            queues[oldPriority].Remove(thread);
            queues[oldPriority].lock.release();
            queues[15].Add(thread);
            queues[15].lock.release();
        } else if (thread.state == .Stopped or thread.state == .Debugging) {
            queues[15].lock.acquire();
            thread.priority = 15;
            thread.shouldKill = true;
            queues[15].Add(thread);
            queues[15].lock.release();
        } else {
            thread.shouldKill = true;
            thread.priority = 15;
        }
        if (@intFromPtr(thread.team.mainThread) == @intFromPtr(thread)) {
            // Set our team's threads to be killed
            var t: ?*Thread = thread.nextTeamThread;
            threadLock.release();
            while (t) |teamThr| {
                KillThread(teamThr.threadID);
                t = teamThr.nextTeamThread;
            }
            // Set our child teams to be adopted by the kernel team
            while (thread.team.children != null) {
                Team.AdoptTeam(thread.team.children.?, false);
            }
        }
    }
    threadLock.release();
    _ = HAL.Arch.IRQEnableDisable(old);
}

pub fn DestroyThread(thread: *Thread) bool {
    const old = HAL.Arch.IRQEnableDisable(false);
    threadLock.acquire();
    if (@intFromPtr(thread.team.mainThread) == @intFromPtr(thread) and thread.nextTeamThread != null) {
        threadLock.release();
        _ = HAL.Arch.IRQEnableDisable(old);
        return false;
    }
    // Destroy the thread
    if (thread.prevTeamThread) |prev| {
        prev.nextTeamThread = thread.nextTeamThread;
    }
    if (thread.nextTeamThread) |next| {
        next.prevTeamThread = thread.prevTeamThread;
    }
    const team = thread.team;
    threads.delete(thread.threadID);
    thread.eventQueue.Wakeup(thread.exitReason);
    Memory.Pool.PagedPool.FreeAnonPages(thread.kstack);
    Memory.Pool.PagedPool.Free(@as([*]u8, @ptrFromInt(@intFromPtr(thread)))[0..@sizeOf(Thread)]);
    if (@intFromPtr(team.mainThread) == @intFromPtr(thread)) {
        // Destroy the Team as well
        threadLock.release();
        Team.AdoptTeam(team, true);
        Team.teamLock.acquire();
        Memory.Paging.DestroyPageDirectory(team.addressSpace);
        team.fds.destroy(&Team.DestroyFileDescriptor);
        Team.teams.delete(team.teamID);
        Memory.Pool.PagedPool.Free(@as([*]u8, @ptrCast(@alignCast(team)))[0..@sizeOf(Team.Team)]);
        Team.teamLock.release();
    } else {
        threadLock.release();
    }
    _ = HAL.Arch.IRQEnableDisable(old);
    return true;
}

pub fn GetThreadByID(id: i64) ?*Thread {
    const old = HAL.Arch.IRQEnableDisable(false);
    threadLock.acquire();
    const val = threads.search(id);
    threadLock.release();
    _ = HAL.Arch.IRQEnableDisable(old);
    return val;
}

pub fn Init() void {
    HAL.Debug.NewDebugCommand("threads", "Lists all of the avaiable threads", &threadsCommand);
    HAL.Debug.NewDebugCommand("thread", "Shows info about a specific thread", &threadCommand);
    var kteam = Team.GetTeamByID(1).?;
    var i: i32 = 0;
    var buf: [32]u8 = [_]u8{0} ** 32;
    while (i < HAL.hcbList.?.len) : (i += 1) {
        const name = std.fmt.bufPrint(buf[0..32], "Hart #{} Idle Thread", .{i}) catch {
            @panic("Unable to parse string!");
        };
        var thread = NewThread(kteam, name, @intFromPtr(&IdleThread), null, 0);
        thread.hartID = i;
    }
}

fn threadCommand(cmd: []const u8, iter: *std.mem.SplitIterator(u8, .sequence)) void {
    _ = cmd;
    if (iter.next()) |id| {
        const threadID: i64 = std.fmt.parseInt(i64, id, 0) catch {
            HAL.Console.Put("Specified Thread ID wasn't a number!\n", .{});
            return;
        };
        if (threads.search(threadID)) |thread| {
            const t = @as(*Thread, thread);
            _ = t;
            HAL.Console.Put("Thread #{}: {s}\n", .{ thread.threadID, thread.name });
            HAL.Console.Put("  PrevQueueThread 0x{x: <16} NextQueueThread 0x{x: <16}\n", .{ @intFromPtr(thread.prevThread), @intFromPtr(thread.nextThread) });
            HAL.Console.Put("   PrevTeamThread 0x{x: <16}  NextTeamThread 0x{x: <16}\n", .{ @intFromPtr(thread.prevTeamThread), @intFromPtr(thread.nextTeamThread) });
            HAL.Console.Put("  NextEventThread 0x{x: <16}            Team 0x{x: <16} (Team #{})\n", .{ @intFromPtr(thread.nextEventThread), @intFromPtr(thread.team), thread.team.teamID });
            HAL.Console.Put("            State {s: <18}        WaitType {: <18}\n", .{ @tagName(thread.state), thread.waitType });
            HAL.Console.Put("       ExitReason 0x{x: <16}      ShouldKill {}\n", .{ thread.exitReason, thread.shouldKill });
            HAL.Console.Put("         Priority {: <18}          UStack 0x{x: <16}\n", .{ thread.priority, thread.activeUstack });
            HAL.Console.Put("           HartID {}\n", .{thread.hartID});
        } else {
            HAL.Console.Put("Thread #{} doesn't exist!\n", .{threadID});
        }
    } else {
        HAL.Console.Put("Usage: thread [threadID]\n", .{});
    }
}

fn threadsCommand(cmd: []const u8, iter: *std.mem.SplitIterator(u8, .sequence)) void {
    _ = iter;
    _ = cmd;
    var ind: i64 = 1;
    while (ind < nextThreadID) : (ind += 1) {
        if (threads.search(ind)) |thread| {
            HAL.Console.Put("{}: 0x{x: <16} {s} {s} IP: 0x{x: <16} SP: 0x{x: <16} Team #{} Priority: {} Quantum: ~{} ms\n", .{
                ind,
                @intFromPtr(thread),
                thread.name,
                @tagName(thread.state),
                thread.context.GetReg(128),
                thread.context.GetReg(129),
                thread.team.teamID,
                thread.priority,
                (20 * (16 - thread.priority) + 5 * thread.priority) >> 4,
            });
        }
    }
}

pub fn GetNextThread() *Thread {
    var i: usize = 15;
    while (true) : (i -= 1) {
        if (queues[i].head != null) {
            queues[i].lock.acquire();
            if (queues[i].head != null) {
                var t = queues[i].head.?;
                queues[i].Remove(t);
                queues[i].lock.release();
                return t;
            } else {
                queues[i].lock.release();
                continue;
            }
        }
        if (i == 0) {
            @panic("No Available Threads in any of the Run Queues!");
        }
    }
}

pub fn TriggerDebug() void {
    const hcb = HAL.Arch.GetHCB();
    _ = hcb;
    //hcb.activeThread.?.
}

pub fn Tick(con: *HAL.Arch.Context, tickType: u8) void {
    if (tickType == 0) {
        const hcb = HAL.Arch.GetHCB();
        if (hcb.hartID == 0) {
            ticks += 1;
        }
        if (hcb.quantumsLeft > 1) {
            hcb.quantumsLeft -= 1;
            return;
        }
    }
    const hcb = HAL.Arch.GetHCB();
    hcb.activeThread.?.activeUstack = hcb.activeUstack;
    hcb.activeThread.?.context = con.*;
    hcb.activeThread.?.fcontext.Save();
    Reschedule(tickType == 0);
}

pub fn Reschedule(demote: bool) noreturn {
    const hcb = HAL.Arch.GetHCB();
    if (hcb.activeThread != null) {
        HAL.Arch.SwitchPT(@as(*void, @ptrFromInt(@intFromPtr(Memory.Paging.initialPageDir.?.ptr) - 0xffff800000000000)));
        if (hcb.activeThread.?.state == .Running) {
            hcb.activeThread.?.state = .Runnable;
            if (demote) {
                if (hcb.activeThread.?.priority > 1)
                    hcb.activeThread.?.priority -= 1;
            }
            queues[hcb.activeThread.?.priority].lock.acquire();
            queues[hcb.activeThread.?.priority].Add(hcb.activeThread.?);
            queues[hcb.activeThread.?.priority].lock.release();
        }
    }
    var thr: *Thread = GetNextThread();
    while (true) {
        if (thr.shouldKill) {
            if (!DestroyThread(thr)) {
                queues[thr.priority].lock.acquire();
                queues[thr.priority].Add(thr);
                queues[thr.priority].lock.release();
            }
        } else if (thr.state == .Runnable and (thr.hartID == -1 or thr.hartID == hcb.hartID)) {
            thr.state = .Running;
            break;
        } else {
            queues[thr.priority].lock.acquire();
            queues[thr.priority].Add(thr);
            queues[thr.priority].lock.release();
        }
        thr = GetNextThread();
    }
    hcb.activeThread = thr;
    hcb.activeKstack = @intFromPtr(thr.kstack.ptr) + (thr.kstack.len - 8);
    hcb.activeUstack = thr.activeUstack;
    hcb.quantumsLeft = @as(u32, @intCast((20 * (16 - thr.priority) + 5 * thr.priority) >> 4));
    HAL.Arch.SwitchPT(@as(*void, @ptrFromInt(@intFromPtr(thr.team.addressSpace.ptr) - 0xffff800000000000)));
    thr.fcontext.Load();
    thr.context.Enter();
}

fn IdleThread() callconv(.C) void {
    while (true) {
        if (Memory.PFN.pfnFreeHead != null) {
            const old = HAL.Arch.IRQEnableDisable(false);
            Memory.PFN.pfnSpinlock.acquire();
            if (Memory.PFN.pfnFreeHead != null) {
                var page = Memory.PFN.pfnFreeHead.?;
                var index: usize = (@intFromPtr(page) - @intFromPtr(Memory.PFN.pfnDatabase.ptr)) / @sizeOf(Memory.PFN.PFNEntry);
                if (page.state != .Free) {
                    HAL.Crash.Crash(.RyuPFNCorruption, .{
                        (index << 12) + 0xffff800000000000,
                        @intFromEnum(@as(Memory.PFN.PFNType, page.state)),
                        @intFromEnum(Memory.PFN.PFNType.Free),
                        0,
                    }, null);
                }
                Memory.PFN.pfnFreeHead = page.next;
                page.next = Memory.PFN.pfnZeroedHead;
                page.state = .Zeroed;
                page.swappable = 0;
                page.refs = 0;
                @memset(@as([*]u8, @ptrFromInt((index << 12) + 0xffff800000000000))[0..4096], 0);
                Memory.PFN.pfnZeroedHead = page;
            }
            Memory.PFN.pfnSpinlock.release();
            _ = HAL.Arch.IRQEnableDisable(old);
        } else {
            HAL.Arch.WaitForIRQ();
        }
    }
}
