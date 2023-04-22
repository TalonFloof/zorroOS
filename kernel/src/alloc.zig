const std = @import("std");

var blocks: ?*Block = undefined;

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

fn alloc(self: *std.mem.Allocator, size: usize, alignment: u64) ![]u8 {
    _ = alignment;
    _ = size;
    _ = self;
    return error.OutOfMemory;
}
