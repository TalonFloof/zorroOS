const std = @import("std");
const HAL = @import("root").HAL;
const Spinlock = @import("root").Spinlock;
const Thread = @import("root").Executive.Thread;

pub const EventQueue = extern struct {
    listLock: Spinlock = .unaquired,
    threadHead: ?*Thread.Thread = null,

    pub fn Wait(self: *EventQueue) usize {
        const old = HAL.Arch.IRQEnableDisable(false);
        self.listLock.acquire();
        const hcb = HAL.Arch.GetHCB();
        hcb.activeThread.?.nextEventThread = self.threadHead;
        self.threadHead = hcb.activeThread.?;
        hcb.activeThread.?.state = .WaitingForEvent;
        self.listLock.release();
        const retVal: usize = HAL.Arch.ThreadYield();
        _ = HAL.Arch.IRQEnableDisable(old);
        return retVal;
    }

    pub fn Wakeup(self: *EventQueue, val: usize) void {
        const old = HAL.Arch.IRQEnableDisable(false);
        self.listLock.acquire();
        var entry: ?*Thread.Thread = self.threadHead;
        while (entry) |thread| {
            if (thread.priority < 15) {
                thread.priority += 1;
            }
            thread.context.SetReg(0, @intCast(u64, val));
            thread.state = .Runnable;
            Thread.queues[thread.priority].lock.acquire();
            Thread.queues[thread.priority].Add(thread);
            const next = thread.nextEventThread;
            thread.nextEventThread = null;
            Thread.queues[thread.priority].lock.release();
            entry = next;
        }
        self.threadHead = null;
        self.listLock.release();
        _ = HAL.Arch.IRQEnableDisable(old);
    }
};
