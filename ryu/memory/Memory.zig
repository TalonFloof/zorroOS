pub const PFN = @import("PFN.zig");
pub const Pool = @import("Pool.zig");
pub const Paging = @import("Paging.zig");
const HAL = @import("hal");
const std = @import("std");

pub const PhysicalRange = struct {
    start: usize = 0,
    end: usize = 0,
};

pub fn Initialize(ranges: *[64]PhysicalRange, initialPD: ?Paging.PageDirectory) void {
    Paging.initialPageDir = initialPD;
    var highestAddress: usize = 0x100000000;
    for (ranges) |r| {
        if (r.end > highestAddress) {
            highestAddress = r.end;
        }
    }
    const entries = highestAddress / 4096;
    const neededSize: usize = ((entries * @sizeOf(PFN.PFNEntry)) & (~@as(usize, @intCast(0xFFF)))) + (if (((entries * @sizeOf(PFN.PFNEntry)) % 4096) > 0) 4096 - ((entries * @sizeOf(PFN.PFNEntry)) % 4096) else 0);
    var startAddr: usize = 0;
    for (ranges, 0..) |r, i| {
        if ((r.end - r.start) > neededSize) {
            startAddr = r.start + 0xffff800000000000;
            ranges[i].start += neededSize;
            break;
        } else if ((r.end - r.start) == neededSize) {
            startAddr = r.start + 0xffff800000000000;
            ranges[i].start = 0;
            ranges[i].end = 0;
            break;
        }
    }
    if (startAddr == 0) {
        HAL.Crash.Crash(.RyuPFNCorruption, .{ 0xdeaddeaddeaddead, 0, 0, 0 }, null);
    }
    HAL.Console.Put("Preparing PFN Database [{d} entries, {d} KiB, 0x{x:0>16}]...\n", .{ entries, neededSize / 1024, startAddr });
    PFN.Initialize(startAddr, entries, ranges);
    HAL.Debug.NewDebugCommand("poolInfo", "Print information relating to the kernel allocation pools", &poolInfoCommand);
    HAL.Debug.NewDebugCommand("pfnInfo", "Prints general information relating to the PFN database", &pfnInfoCommand);
    HAL.Debug.NewDebugCommand("pfn", "Get info about a page within the PFN database", &pfnCommand);
}

fn poolInfoCommand(cmd: []const u8, iter: *std.mem.SplitIterator(u8, .sequence)) void {
    _ = iter;
    _ = cmd;
    HAL.Console.Put("StaticPool | Buckets: {} UsedBlocks: {} FreeBlocks: {} TotalBlocks: {}\n", .{ Pool.StaticPool.buckets, Pool.StaticPool.usedBlocks, Pool.StaticPool.totalBlocks - Pool.StaticPool.usedBlocks, Pool.StaticPool.totalBlocks });
    HAL.Console.Put("           | Anonymous: {} KiB Committed: {} KiB Active: {} bytes\n", .{ Pool.StaticPool.anonymousPages * 4, (Pool.StaticPool.buckets * 512) + (Pool.StaticPool.anonymousPages * 4), (Pool.StaticPool.usedBlocks * 16) + (Pool.StaticPool.anonymousPages * 4096) });
    HAL.Console.Put("PagedPool  | Buckets: {} UsedBlocks: {} FreeBlocks: {} TotalBlocks: {}\n", .{ Pool.PagedPool.buckets, Pool.PagedPool.usedBlocks, Pool.PagedPool.totalBlocks - Pool.PagedPool.usedBlocks, Pool.PagedPool.totalBlocks });
    HAL.Console.Put("           | Anonymous: {} KiB Committed: {} KiB Active: {} bytes\n", .{ Pool.PagedPool.anonymousPages * 4, (Pool.PagedPool.buckets * 512) + (Pool.PagedPool.anonymousPages * 4), (Pool.PagedPool.usedBlocks * 16) + (Pool.PagedPool.anonymousPages * 4096) });
}

fn pfnInfoCommand(cmd: []const u8, iter: *std.mem.SplitIterator(u8, .sequence)) void {
    _ = iter;
    _ = cmd;
    HAL.Console.Put("{: >24} KiB Used\n{: >24} KiB Free\n{: >24} KiB Total\n", .{ PFN.pfnUsedPages * 4, (PFN.pfnTotalPages - PFN.pfnUsedPages) * 4, PFN.pfnTotalPages * 4 });
}

fn pfnCommand(cmd: []const u8, iter: *std.mem.SplitIterator(u8, .sequence)) void {
    _ = cmd;
    if (iter.next()) |addrStr| {
        const addr: usize = std.fmt.parseInt(usize, addrStr, 0) catch {
            HAL.Console.Put("Specified address was not a number!\n", .{});
            return;
        };
        if ((addr >> 12) > PFN.pfnDatabase.len) {
            HAL.Console.Put("Address is beyond PFN Database!\n", .{});
        } else {
            const entry = PFN.pfnDatabase[(addr >> 12)];
            HAL.Console.Put("Page 0x{x}\n", .{addr});
            HAL.Console.Put("       State {s: <18}  References {}\n", .{ @tagName(entry.state), entry.refs });
            HAL.Console.Put(" IsSwappable {: <18}         PTE 0x{x}\n", .{ entry.swappable != 0, entry.pte });
            if (entry.next != null) {
                HAL.Console.Put("        Next 0x{x: <16} (Page 0x{x})\n", .{ @intFromPtr(entry.next), ((@intFromPtr(entry.next) - @intFromPtr(PFN.pfnDatabase.ptr)) / @sizeOf(PFN.PFNEntry)) << 12 });
            } else {
                HAL.Console.Put("        Next 0x{x}\n", .{@intFromPtr(entry.next)});
            }
        }
    } else {
        HAL.Console.Put("Usage: pfn [addr]\n", .{});
    }
}
