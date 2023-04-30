const native = @import("native");
const std = @import("std");
const root = @import("root");
const HardwareThread = root.hart.HardwareThread;
const Spinlock = root.Spinlock;

pub var treeRoot: ?*Thread = null;

pub const Thread = struct {
    kstack: [4096]u8 = [_]u8{0} ** 4096,
    context: native.context.Context,
    floatContext: native.context.FloatContext,
    queuePrev: ?*Thread = null,
    queueNext: ?*Thread = null,
    id: u64 = 0,
    hartID: u64 = 0,
    pagerID: u64 = 0,

    left: ?*Thread = null,
    right: ?*Thread = null,
    level: isize = 1,
};

fn treeSkew(n: ?*Thread) ?*Thread {
    if (n != null) |node| {
        if (node.left == null) {
            return node;
        } else if (node.left.?.level == node.level) {
            var l = node.left.?;
            node.left = l.right;
            l.right = node;
            return l;
        } else {
            return node;
        }
    } else {
        return null;
    }
}

fn treeSplit(n: ?*Thread) ?*Thread {
    if (n != null) |node| {
        if (node.right == null) {
            return node;
        } else if (node.right.?.right == null) {
            return node;
        } else if (node.level == node.right.?.right.?.level) {
            var r = node.right.?;
            node.right = r.left;
            r.left = node;
            r.level = r.level + 1;
            return r;
        } else {
            return node;
        }
    } else {
        return null;
    }
}

fn treeInsert(T: ?*Thread, x: *Thread) ?*Thread {
    var t = T;
    if (t == null) {
        return x;
    } else if (x.id < t.id) {
        t.?.left = treeInsert(t.?.left, x);
    } else if (x.id > t.id) {
        t.?.right = treeInsert(t.?.right, x);
    }
    t = treeSkew(t);
    t = treeSplit(t);
    return t;
}

pub fn scheduleNext() noreturn {
    var curHart = root.native.hart.getHart();
    curHart.threadLock.acquire("hart" ++ curHart.id ++ " Thread Scheduler");
}
