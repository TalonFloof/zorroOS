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

pub var startScheduler: bool = false;

var queueLock: Spinlock = .unaquired;
var queueHead: ?*Thread = null;
var queueTail: ?*Thread = null;

fn AddToQueue(t: *Thread) void {
    t.nextThread = null;
    t.prevThread = queueTail;
    if (queueTail != null) { // hehehe tail owo~
        queueTail.?.nextThread = t;
    }
    queueTail = t;
    if (queueHead == null) {
        queueHead = t;
    }
}

fn RemoveFromQueue(t: *Thread) void {
    if (t.nextThread) |nxt| {
        nxt.prevThread = t.prevThread;
    }
    if (t.prevThread) |prev| {
        prev.nextThread = t.nextThread;
    }
    if (@ptrToInt(queueHead) == @ptrToInt(t)) {
        queueHead = t.nextThread;
    }
    if (@ptrToInt(queueTail) == @ptrToInt(t)) {
        queueTail = t.prevThread;
    }
}

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
    queueLock.acquire();
    AddToQueue(&thread.value);
    queueLock.release();
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

pub fn GetNextThread() *Thread {
    const hcb = HAL.Arch.GetHCB();
    _ = hcb;
    queueLock.acquire();
    var t = queueHead.?;
    RemoveFromQueue(t);
    queueLock.release();
    return t;
}

pub fn Reschedule() noreturn {
    const hcb = HAL.Arch.GetHCB();
    if (hcb.activeThread == null) {
        if (queueHead == null) {
            @panic("Attempted to preform preemptive scheduling with no threads in the queue!");
        }
        hcb.activeThread = queueHead;
    } else {
        HAL.Arch.SwitchPT(@intToPtr(*void, @ptrToInt(Memory.Paging.initialPageDir.?.ptr) - 0xffff800000000000));
        hcb.activeThread.?.state = .Runnable;
        queueLock.acquire();
        AddToQueue(hcb.activeThread.?);
        queueLock.release();
    }
    var thr: *Thread = GetNextThread();
    while (true) {
        if (thr.shouldKill) {
            // TODO: Destroy the thread
        } else if (thr.state == .Runnable and (thr.hartID == -1 or thr.hartID == hcb.hartID)) {
            thr.state = .Running;
            break;
        } else {
            queueLock.acquire();
            AddToQueue(thr);
            queueLock.release();
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
                Memory.PFN.pfnFreeHead = page.next;
                if (page.next == null) {
                    HAL.Console.Put("Freed the last non-zeroed page!\n", .{});
                }
                page.next = Memory.PFN.pfnZeroedHead;
                page.state = .Zeroed;
                page.swappable = 0;
                page.refs = 0;
                var index: usize = (@ptrToInt(page) - @ptrToInt(Memory.PFN.pfnDatabase.ptr)) / @sizeOf(Memory.PFN.PFNEntry);
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
