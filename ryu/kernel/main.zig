pub const HAL = @import("hal");
pub const Memory = @import("memory");
pub const Spinlock = @import("Spinlock.zig").Spinlock;
pub const HCB = @import("HCB.zig").HCB;
const std = @import("std");

pub fn panic(msg: []const u8, stacktrace: ?*std.builtin.StackTrace, wat: ?usize) noreturn {
    _ = wat;
    _ = stacktrace;
    HAL.Console.Put("Fatal Zig Error: {s}\n", .{msg});
    HAL.Crash.Crash(.RyuZigPanic, .{ 0, 0, 0, 0 });
}

pub export fn RyuInit() noreturn {
    // Well It's the momment we've been waiting for
    _ = Memory.Pool.StaticPool.Alloc(65024);
    _ = Memory.Pool.StaticPool.Alloc(65024);
    _ = Memory.Pool.StaticPool.Alloc(65024);
    _ = Memory.Pool.StaticPool.Alloc(65024);
    _ = Memory.Pool.StaticPool.Alloc(65024);
    _ = Memory.Pool.StaticPool.Alloc(65024);
    _ = Memory.Pool.StaticPool.Alloc(65024);
    _ = Memory.Pool.StaticPool.Alloc(65024 - 16);
    HAL.Console.Put("StaticPool | Buckets: {} UsedBlocks: {} TotalBlocks: {} FreeBlocks: {}\n", .{ Memory.Pool.StaticPool.buckets, Memory.Pool.StaticPool.usedBlocks, Memory.Pool.StaticPool.totalBlocks, Memory.Pool.StaticPool.totalBlocks - Memory.Pool.StaticPool.usedBlocks });
    HAL.Console.Put("           | Anonymous: {} KiB Committed: {} KiB Active: {} bytes\n", .{ Memory.Pool.StaticPool.anonymousPages * 4, (Memory.Pool.StaticPool.buckets * 512) + (Memory.Pool.StaticPool.anonymousPages * 4), (Memory.Pool.StaticPool.usedBlocks * 16) + (Memory.Pool.StaticPool.anonymousPages * 4096) });
    var dat = Memory.Pool.StaticPool.Alloc(32).?;
    HAL.Console.Put("StaticPool | Buckets: {} UsedBlocks: {} TotalBlocks: {} FreeBlocks: {}\n", .{ Memory.Pool.StaticPool.buckets, Memory.Pool.StaticPool.usedBlocks, Memory.Pool.StaticPool.totalBlocks, Memory.Pool.StaticPool.totalBlocks - Memory.Pool.StaticPool.usedBlocks });
    HAL.Console.Put("           | Anonymous: {} KiB Committed: {} KiB Active: {} bytes\n", .{ Memory.Pool.StaticPool.anonymousPages * 4, (Memory.Pool.StaticPool.buckets * 512) + (Memory.Pool.StaticPool.anonymousPages * 4), (Memory.Pool.StaticPool.usedBlocks * 16) + (Memory.Pool.StaticPool.anonymousPages * 4096) });
    Memory.Pool.StaticPool.Free(dat);
    HAL.Console.Put("StaticPool | Buckets: {} UsedBlocks: {} TotalBlocks: {} FreeBlocks: {}\n", .{ Memory.Pool.StaticPool.buckets, Memory.Pool.StaticPool.usedBlocks, Memory.Pool.StaticPool.totalBlocks, Memory.Pool.StaticPool.totalBlocks - Memory.Pool.StaticPool.usedBlocks });
    HAL.Console.Put("           | Anonymous: {} KiB Committed: {} KiB Active: {} bytes\n", .{ Memory.Pool.StaticPool.anonymousPages * 4, (Memory.Pool.StaticPool.buckets * 512) + (Memory.Pool.StaticPool.anonymousPages * 4), (Memory.Pool.StaticPool.usedBlocks * 16) + (Memory.Pool.StaticPool.anonymousPages * 4096) });
    HAL.Console.Put("Boot Complete!\n", .{});
    while (true) {}
}
