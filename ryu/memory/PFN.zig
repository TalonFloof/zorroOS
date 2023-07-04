const HAL = @import("hal");
const Memory = @import("root").Memory;
const Spinlock = @import("root").Spinlock;
const std = @import("std");

pub var pfnDatabase: []PFNEntry = undefined;
pub var pfnFreeHead: ?*PFNEntry = null;
pub var pfnZeroedHead: ?*PFNEntry = null;
pub var pfnSpinlock: Spinlock = .unaquired;

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
    pfnDatabase = @as([*]PFNEntry, @ptrFromInt(begin))[0..entryCount];
    for (0..pfnDatabase.len) |i| {
        pfnDatabase[i].next = null;
        pfnDatabase[i].refs = 0;
        pfnDatabase[i].state = .Reserved;
        pfnDatabase[i].pte = 0;
    }
    for (ranges) |r| {
        var i = r.start;
        while (i < r.end) : (i += 4096) {
            pfnDatabase[i >> 12].next = pfnFreeHead;
            pfnDatabase[i >> 12].refs = 0;
            pfnDatabase[i >> 12].state = .Free;
            pfnFreeHead = &pfnDatabase[i >> 12];
        }
    }
}

pub fn AllocatePage(tag: PFNType, swappable: bool, pte: usize) ?[]u8 {
    const old = HAL.Arch.IRQEnableDisable(false);
    pfnSpinlock.acquire();
    if (pfnZeroedHead) |entry| {
        const phys: usize = ((@intFromPtr(entry) - @intFromPtr(pfnDatabase.ptr)) / @sizeOf(PFNEntry)) << 12;
        if (entry.state != .Zeroed) {
            HAL.Crash.Crash(.RyuPFNCorruption, .{ phys, @intFromEnum(@as(PFNType, entry.state)), @intFromEnum(PFNType.Zeroed), 0 });
        }
        pfnZeroedHead = entry.next;
        entry.next = null;
        entry.refs = if (tag == .PageTable) 0 else 1;
        entry.state = tag;
        entry.swappable = if (swappable) 1 else 0;
        entry.pte = pte;
        var ret = @as([*]u8, @ptrFromInt(phys + 0xFFFF800000000000))[0..4096];
        pfnSpinlock.release();
        _ = HAL.Arch.IRQEnableDisable(old);
        return ret;
    } else if (pfnFreeHead) |entry| {
        const phys: usize = ((@intFromPtr(entry) - @intFromPtr(pfnDatabase.ptr)) / @sizeOf(PFNEntry)) << 12;
        if (entry.state != .Free) {
            HAL.Crash.Crash(.RyuPFNCorruption, .{ phys, @intFromEnum(@as(PFNType, entry.state)), @intFromEnum(PFNType.Free), 0 });
        }
        pfnFreeHead = entry.next;
        entry.next = null;
        entry.refs = if (tag == .PageTable) 0 else 1;
        entry.state = tag;
        entry.swappable = if (swappable) 1 else 0;
        entry.pte = pte;
        var ret = @as([*]u8, @ptrFromInt(phys + 0xFFFF800000000000))[0..4096];
        @memset(ret, 0); // Freed Pages haven't been zeroed yet so we'll manually do it.
        pfnSpinlock.release();
        _ = HAL.Arch.IRQEnableDisable(old);
        return ret;
    }
    pfnSpinlock.release();
    _ = HAL.Arch.IRQEnableDisable(old);
    return null;
}

pub fn GetPage(page: usize) *PFNEntry {
    return &pfnDatabase[(page >> 12)];
}

pub fn ReferencePage(page: usize) void {
    const index: usize = (page >> 12);
    const old = HAL.Arch.IRQEnableDisable(false);
    pfnSpinlock.acquire();
    pfnDatabase[index].refs += 1;
    pfnSpinlock.release();
    _ = HAL.Arch.IRQEnableDisable(old);
}

pub fn DereferencePage(page: usize) void {
    const index: usize = (page >> 12);
    const old = HAL.Arch.IRQEnableDisable(false);
    pfnSpinlock.acquire();
    if (pfnDatabase[index].state != .Reserved) {
        pfnDatabase[index].refs -= 1;
        if (pfnDatabase[index].refs == 0) {
            const oldState = pfnDatabase[index].state;
            pfnDatabase[index].state = .Free;
            pfnDatabase[index].next = pfnFreeHead;
            pfnDatabase[index].swappable = 0;
            if (pfnDatabase[index].pte != 0 and oldState == .PageTable) {
                const entry: usize = pfnDatabase[index].pte;
                const pt = entry & (~@as(usize, @intCast(0xFFF))) - 0xffff800000000000;
                if (pfnDatabase[pt >> 12].state != .PageTable) {
                    HAL.Crash.Crash(.RyuPFNCorruption, .{ pt, @intFromEnum(pfnDatabase[pt >> 12].state), @intFromEnum(PFNType.PageTable), 0 });
                }
                @as(*usize, @ptrFromInt(entry)).* = 0;
                pfnFreeHead = &pfnDatabase[index];
                pfnSpinlock.release();
                DereferencePage(pt);
                _ = HAL.Arch.IRQEnableDisable(old);
                return;
            } else {
                pfnFreeHead = &pfnDatabase[index];
            }
        }
    }
    pfnSpinlock.release();
    _ = HAL.Arch.IRQEnableDisable(old);
}

pub fn ForceFreePage(page: usize) void {
    const index: usize = (page >> 12);
    const old = HAL.Arch.IRQEnableDisable(false);
    pfnSpinlock.acquire();
    pfnDatabase[index].state = .Free;
    pfnDatabase[index].next = pfnFreeHead;
    pfnDatabase[index].swappable = 0;
    pfnDatabase[index].refs = 0;
    pfnFreeHead = &pfnDatabase[index];
    pfnSpinlock.release();
    _ = HAL.Arch.IRQEnableDisable(old);
}

pub fn ChangePTEEntry(page: usize, pte: usize) void {
    const index: usize = (page >> 12);
    const old = HAL.Arch.IRQEnableDisable(false);
    pfnSpinlock.acquire();
    pfnDatabase[index].pte = pte;
    pfnSpinlock.release();
    _ = HAL.Arch.IRQEnableDisable(old);
}
