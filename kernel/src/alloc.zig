const std = @import("std");
const Spinlock = @import("spinlock.zig").Spinlock;

pub var blocks: ?[]Block = null;
pub var headIndex: usize = ~0;
var allocLock = Spinlock.unaquired;

const Block = struct {
    prev: usize,
    next: usize,
    start: usize,
    end: usize,

    pub fn size(self: *Block) usize {
        return self.end - self.start;
    }
};

const Cursor = struct {
    current: usize,

    pub fn new() Cursor {
        return Cursor{
            .current = headIndex,
        };
    }
    pub fn next(self: *Cursor) ?*Block {
        if (self.current == ~0) {
            return null;
        }
        const current = self.current;
        self.current = blocks.?[self.current].next;
        return &(blocks.?[current]);
    }
    pub fn peekNext(self: *Cursor) ?*Block {
        return blocks.?[self.current].next;
    }
    pub fn peekPrev(self: *Cursor) ?*Block {
        return blocks.?[self.current].prev;
    }
    pub fn insertBefore(self: *Cursor, begin: usize, end: usize) void {
        var prev = blocks.?[self.current].prev;
        var nextEntry = findNextEntry();
        if (nextEntry == ~0) {
            @panic("FreeList Heap is Deprived!");
        }
        if (prev != ~0) {
            blocks.?[prev].next = nextEntry;
        }
        blocks.?[nextEntry].prev = prev;
        blocks.?[self.current].prev = nextEntry;
        blocks.?[nextEntry].next = self.current;
        blocks.?[nextEntry].start = begin;
        blocks.?[nextEntry].end = end;
        if (headIndex == self.current) {
            headIndex = nextEntry;
        }
    }
    pub fn removeCurrent(self: *Cursor) void {
        var prev = blocks.?[self.current].prev;
        var nxt = blocks.?[self.current].next;
        if (prev != ~0) {
            blocks.?[prev].next = nxt;
        }
        if (nxt != ~0) {
            blocks.?[nxt].prev = prev;
        }
        blocks.?[self.current].prev = ~0;
        blocks.?[self.current].next = ~0;
        blocks.?[self.current].start = 0;
        blocks.?[self.current].end = 0;
        if (headIndex == self.current) {
            if (nxt == ~0) {
                if (prev != ~0) {
                    @panic("FreeList Head Index is Tail Index");
                }
                headIndex = -1;
            } else {
                headIndex = nxt;
            }
        }
    }
};

pub fn initialize(heap: []Block) void {
    for (heap) |entry| {
        entry.prev = ~0;
        entry.next = ~0;
        entry.start = 0;
        entry.end = 0;
    }
    blocks = heap;
}

fn pushBack(begin: usize, end: usize) void {
    var i = if (headIndex == ~0) 0 else headIndex;
    while (true) {
        if (blocks.?[i].next == ~0) {
            const nextEntry = findNextEntry();
            if (headIndex == ~0) {
                headIndex = nextEntry;
            }
            blocks.?[i].next = nextEntry;
            blocks.?[nextEntry].prev = i;
            blocks.?[nextEntry].next = ~0;
            blocks.?[nextEntry].start = begin;
            blocks.?[nextEntry].end = end;
            return;
        }
        i = blocks.?[i].next;
    }
}

fn findNextEntry() ?usize {
    var i: usize = 0;
    while (i < blocks.?.len) : (i += 1) {
        if (blocks.?[i].start == 0 and blocks.?[i].end == 0) {
            return i;
        }
    }
    return null;
}

fn alloc(self: *std.mem.Allocator, n: usize, alignment: u64) ![]u8 {
    _ = self;
    allocLock.aquire("ZigAllocationLock");
    const size = n + alignment;
    var cursor = Cursor.new();
    var i = cursor.next();
    while (i != null) {
        if (i) |segment| {
            const segment_start = segment.start;
            const segment_size = segment.size();
            if (segment_size > size) {
                if (alignment > 0) {
                    const new_addr = (segment_start + (alignment - 1)) & ~(alignment - 1);
                    i.data.start += n + (new_addr - segment_start);
                    if (new_addr != segment_start) {
                        cursor.insertBefore(segment_start, new_addr);
                    }
                    allocLock.release();
                    return @intToPtr([*]u8, new_addr)[0..n];
                } else {
                    segment.start += n;
                    allocLock.release();
                    return @intToPtr([*]u8, segment_start)[0..n];
                }
            } else if (segment_size == size) {
                if (alignment > 0) {
                    const new_addr = (segment_start + (alignment - 1)) & ~(alignment - 1);
                    if (new_addr != segment_start) {
                        segment.end = new_addr;
                    }
                    allocLock.release();
                    return @intToPtr([*]u8, new_addr)[0..n];
                } else {
                    cursor.removeCurrent();
                    allocLock.release();
                    return @intToPtr([*]u8, segment_start)[0..n];
                }
            }
        }
        i = cursor.next();
    }
    allocLock.release();
    return error.OutOfMemory;
}
