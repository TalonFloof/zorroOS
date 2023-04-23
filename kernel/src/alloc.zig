const std = @import("std");
const Spinlock = @import("spinlock.zig").Spinlock;

var blocks: ?*Block = undefined;
var allocLock = Spinlock.unaquired;

const Block = struct {
    prev: ?*Block,
    next: ?*Block,
    size: usize,

    pub fn new(size: usize) Block {
        return Block{
            .prev = null,
            .next = null,
            .size = size,
        };
    }

    pub fn data(self: *Block) []u8 {
        return @intToPtr([*]u8, @ptrToInt(self))[0..self.size];
    }
};

fn insert_before(blk: *Block) void {
    _ = blk;
    //std.debug.assert(blk.size - size > @sizeOf(Block));
    //var right = @intToPtr(*Block, @ptrToInt(blk) + size);
    //right.* = Block{};
}

fn alloc(self: *std.mem.Allocator, n: usize, alignment: u64) ![]u8 {
    _ = self;
    allocLock.aquire("ZigAllocationLock");
    const size = n + alignment;
    if (blocks == null) {
        allocLock.release();
        return error.OutOfMemory;
    }
    var i: ?*Block = blocks;
    while (i != null) {
        if (i) |blk| {
            const s = blk.size - @sizeOf(Block);
            if (s > size) {
                if (alignment > 0) {
                    var new_blk: *Block = @intToPtr(*Block, (@ptrToInt(blk) + (alignment - 1)) & ~(alignment - 1));
                    _ = new_blk;
                }
            }
            i = blk.next;
        } else {
            @panic("Allocator stuck in unusual state");
        }
    }
    allocLock.release();
    return error.OutOfMemory;
}
