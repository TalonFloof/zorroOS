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
    Eeping, // :3
    Waiting, // When awoken, a threads priority will increase
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
    shouldKill: bool = false,
    priority: usize = 8,
    context: HAL.Arch.Context = HAL.Arch.Context{},
    fcontext: HAL.Arch.FloatContext = HAL.Arch.FloatContext{},
    kstack: []u8,
    hartID: i32 = -1,
};

const ThreadTreeType = AATree(i64, Thread);

pub var threads: ThreadTreeType = ThreadTreeType{};
var threadLock: Spinlock = .unaquired;
pub var nextThreadID: i64 = 1;

pub var startScheduler: bool = false;

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
        if (@ptrToInt(self.head) == @ptrToInt(t)) {
            self.head = t.nextThread;
        }
        if (@ptrToInt(self.tail) == @ptrToInt(t)) {
            self.tail = t.prevThread;
        }
        t.nextThread = null;
        t.prevThread = null;
    }
};

var queues: [16]Queue = [_]Queue{Queue{}} ** 16;

pub fn NewThread(
    team: *Team.Team,
    name: []u8,
    ip: usize,
    sp: ?usize,
    prior: usize,
) *Thread { // If SP is null then this is a kernel thread
    const old = HAL.Arch.IRQEnableDisable(false);
    threadLock.acquire();
    var thread = @ptrCast(*ThreadTreeType.Node, @alignCast(@alignOf(ThreadTreeType.Node), Memory.Pool.PagedPool.Alloc(@sizeOf(ThreadTreeType.Node)).?.ptr));
    @memset(@intToPtr([*]u8, @ptrToInt(&thread.value.name))[0..32], 0);
    @memcpy(@intToPtr([*]u8, @ptrToInt(&thread.value.name)), name);
    thread.value.team = team;
    thread.value.hartID = -1;
    thread.value.threadID = nextThreadID;
    thread.key = nextThreadID;
    nextThreadID += 1;
    thread.value.state = .Runnable;
    thread.value.priority = prior;
    var stack = Memory.Pool.PagedPool.AllocAnonPages(16384).?;
    thread.value.kstack = stack;
    if (sp == null) {
        thread.value.context.SetMode(true);
        thread.value.context.SetReg(129, @ptrToInt(stack.ptr) + stack.len);
    } else {
        thread.value.context.SetMode(false);
        thread.value.context.SetReg(129, sp.?);
    }
    @memset(@intToPtr([*]u8, @ptrToInt(&thread.value.fcontext.data))[0..512], 0);
    thread.value.context.SetReg(128, ip);
    threads.insert(thread);
    queues[prior].lock.acquire();
    queues[prior].Add(&thread.value);
    queues[prior].lock.release();
    threadLock.release();
    _ = HAL.Arch.IRQEnableDisable(old);
    return &thread.value;
}

pub fn KillThread(threadID: usize) void {
    _ = threadID;
}

pub fn Init() void {
    var kteam = Team.GetTeamByID(1).?;
    var i: i32 = 0;
    var buf: [32]u8 = [_]u8{0} ** 32;
    while (i < HAL.hcbList.?.len) : (i += 1) {
        const name = std.fmt.bufPrint(buf[0..32], "Hart #{} Idle Thread", .{i}) catch {
            @panic("Unable to parse string!");
        };
        var thread = NewThread(kteam, name, @ptrToInt(&IdleThread), null, 0);
        thread.hartID = i;
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

pub fn Reschedule(demote: bool) noreturn {
    const hcb = HAL.Arch.GetHCB();
    if (hcb.activeThread != null) {
        HAL.Arch.SwitchPT(@intToPtr(*void, @ptrToInt(Memory.Paging.initialPageDir.?.ptr) - 0xffff800000000000));
        hcb.activeThread.?.state = .Runnable;
        if (demote) {
            if (hcb.activeThread.?.priority > 1)
                hcb.activeThread.?.priority -= 1;
        }
        queues[hcb.activeThread.?.priority].lock.acquire();
        queues[hcb.activeThread.?.priority].Add(hcb.activeThread.?);
        queues[hcb.activeThread.?.priority].lock.release();
    }
    var thr: *Thread = GetNextThread();
    while (true) {
        if (thr.shouldKill) {
            // TODO: Destroy the thread
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
    hcb.activeKstack = @ptrToInt(thr.kstack.ptr) + thr.kstack.len;
    hcb.activeUstack = 0;
    hcb.quantumsLeft = 10; // 10 ms
    HAL.Arch.SwitchPT(@intToPtr(*void, @ptrToInt(thr.team.addressSpace.ptr) - 0xffff800000000000));
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
                var index: usize = (@ptrToInt(page) - @ptrToInt(Memory.PFN.pfnDatabase.ptr)) / @sizeOf(Memory.PFN.PFNEntry);
                if (page.state != .Free) {
                    HAL.Crash.Crash(.RyuPFNCorruption, .{
                        (index << 12) + 0xffff800000000000,
                        @enumToInt(@as(Memory.PFN.PFNType, page.state)),
                        @enumToInt(Memory.PFN.PFNType.Free),
                        0,
                    });
                }
                Memory.PFN.pfnFreeHead = page.next;
                page.next = Memory.PFN.pfnZeroedHead;
                page.state = .Zeroed;
                page.swappable = 0;
                page.refs = 0;
                @memset(@intToPtr([*]u8, (index << 12) + 0xffff800000000000)[0..4096], 0);
                Memory.PFN.pfnZeroedHead = page;
            }
            Memory.PFN.pfnSpinlock.release();
            _ = HAL.Arch.IRQEnableDisable(old);
        } else {
            HAL.Arch.WaitForIRQ();
        }
    }
}
