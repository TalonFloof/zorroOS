const HAL = @import("hal");
const Memory = @import("root").Memory;
const Spinlock = @import("root").Spinlock;
const std = @import("std");

pub var pfnDatabase: []PFNEntry = undefined;
pub var pfnFreeHead: ?*PFNEntry = null;
pub var pfnZeroedHead: ?*PFNEntry = null;
var pfnSpinlock: Spinlock = .unaquired;

pub const PFNType = enum(u3) {
    Free = 0,
    Zeroed = 1,
    Reserved = 2,
    Active = 3,
    PageTable = 4,
};

// PFN Database
pub const PFNEntry = struct {
    next: ?*PFNEntry = null,
    refs: u28 = 0,
    state: PFNType = .Free,
    swappable: u1 = 0,
    pte: usize,
};

pub fn Initialize(begin: usize, entryCount: usize, ranges: *[32]Memory.PhysicalRange) void {
    pfnDatabase = @intToPtr([*]PFNEntry, begin)[0..entryCount];
    for (0..pfnDatabase.len) |i| {
        pfnDatabase[i].next = null;
        pfnDatabase[i].refs = 0;
        pfnDatabase[i].state = .Reserved; // Reserved
        pfnDatabase[i].pte = 0;
    }
    for (ranges) |r| {
        var i = r.start;
        while (i < r.end) : (i += 4096) {
            pfnDatabase[i >> 12].next = pfnFreeHead;
            pfnDatabase[i >> 12].refs = 0;
            pfnDatabase[i >> 12].state = .Free; // Free
            pfnFreeHead = &pfnDatabase[i >> 12];
        }
    }
}

pub fn AllocatePage(tag: PFNType, swappable: bool, pte: usize) ?[]u8 {
    pfnSpinlock.acquire();
    if (pfnZeroedHead != null) |entry| {
        const phys: usize = ((@ptrToInt(entry) - @ptrToInt(pfnDatabase)) / @sizeOf(PFNEntry)) << 12;
        if (entry.state != .Zeroed) {
            HAL.Crash.Crash(.RyuPFNCorruption, .{ phys, @enumToInt(entry.state), @enumToInt(.Zeroed), 0 });
        }
        pfnZeroedHead = entry.next;
        entry.next = null;
        entry.refs = if (tag == .PageTable) 0 else 1;
        entry.state = tag;
        entry.swappable = if (swappable) 1 else 0;
        entry.pte = pte;
        entry.pte.phys = @intCast(u52, phys >> 12);
        var ret = @intToPtr([*]u8, phys + 0xFFFF800000000000)[0..4096];
        pfnSpinlock.release();
        return ret;
    } else if (pfnFreeHead != null) |entry| {
        const phys: usize = ((@ptrToInt(entry) - @ptrToInt(pfnDatabase)) / @sizeOf(PFNEntry)) << 12;
        if (entry.state != .Free) {
            HAL.Crash.Crash(.RyuPFNCorruption, .{ phys, @enumToInt(entry.state), @enumToInt(.Free), 0 });
        }
        pfnFreeHead = entry.next;
        entry.next = null;
        entry.refs = if (tag == .PageTable) 0 else 1;
        entry.state = tag;
        entry.swappable = if (swappable) 1 else 0;
        entry.pte = pte;
        entry.pte.phys = @intCast(u52, phys >> 12);
        var ret = @intToPtr([*]u8, phys + 0xFFFF800000000000)[0..4096];
        @memset(ret, 0); // Freed Pages haven't been zeroed yet so we'll manually do it.
        pfnSpinlock.release();
        return ret;
    }
    pfnSpinlock.release();
    return null;
}

pub fn ReferencePage(page: usize) void {
    const index: usize = (page >> 12);
    pfnSpinlock.acquire();
    pfnDatabase[index].refs += 1;
    pfnSpinlock.release();
}

pub fn DereferencePage(page: usize) void {
    const index: usize = (page >> 12);
    pfnSpinlock.acquire();
    pfnDatabase[index].refs -= 1;
    if (pfnDatabase[index].refs == 0) {
        const oldState = pfnDatabase[index].state;
        pfnDatabase[index].state = .Free;
        pfnDatabase[index].next = pfnFreeHead;
        pfnDatabase[index].swappable = 0;
        if (pfnDatabase[index].pte != 0 and oldState == .PageTable) {
            const entry: usize = pfnDatabase[index].pte;
            const pt = entry & (~@intCast(usize, 0xFFF));
            if (pfnDatabase[pt >> 12].state != .PageTable) {
                HAL.Crash.Crash(.RyuPFNCorruption, .{ pt, @enumToInt(entry.state), @enumToInt(.PageTable), 0 });
            }
            @intToPtr(*usize, entry).* = 0;
            pfnFreeHead = &pfnDatabase[index];
            pfnSpinlock.release();
            DereferencePage(pt);
            return;
        } else {
            pfnFreeHead = &pfnDatabase[index];
        }
    }
    pfnSpinlock.release();
}

pub fn ChangePTEEntry(page: usize, pte: usize) void {
    const index: usize = (page >> 12);
    pfnSpinlock.acquire();
    pfnDatabase[index].pte = pte;
    pfnSpinlock.release();
}
