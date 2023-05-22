const Memory = @import("root").Memory;
const Spinlock = @import("root").Spinlock;

// This implements a simple memory allocator for the Ryu Kernel.
// There's a chance this will probably be replaced with a more efficient allocator in the future, but for now, this is the best you'll get.
// NOTE: Allocations beyond 65024 bytes (1/8 of a bucket) will directly allocate pages instead of using buckets.
//       These sections of the memory pool are called Anonymous Pages.

pub const Bucket = struct {
    prev: ?*Bucket align(1),
    next: ?*Bucket align(1),
    usedEntries: u64 align(1),
    magic: u64 align(1),
    bitmap: [4064]u8 align(1), // 32512 entries = 520192 bytes = 508 KiB maximum

    comptime {
        if (@sizeOf(@This()) != 4096) {
            @panic("Bucket size is not 4 KiB!");
        }
    }

    fn GetBit(self: *Bucket, index: usize) bool {
        return ((self.bitmap[index / 8] >> (index % 8)) & 1) != 0;
    }

    fn SetBit(self: *Bucket, index: usize, value: bool) void {
        if (value) {
            self.bitmap[index / 8] |= 1 << (index % 8);
        } else {
            self.bitmap[index / 8] &= ~(1 << (index % 8));
        }
    }

    pub fn Alloc(self: *Bucket, size: usize) ?[]u8 {
        var i = 0;
        var entries: usize = (size / 16) + (if ((size % 16) != 0) 1 else 0);
        while (i < 32512 - (entries - 1)) : (i += 1) {
            var j = i;
            var canUse = true;
            while (j < i + entries) : (j += 1) {
                if (self.GetBit(j)) {
                    canUse = false;
                    break;
                }
            }
            if (canUse) {
                j = i;
                while (j < i + entries) : (j += 1) {
                    self.SetBit(j, true);
                }
                self.usedEntries += entries;
                var addr = (@ptrToInt(self) + 4096) + (i * 16);
                _ = addr;
            }
        }
        return null;
    }
};

pub const Pool = struct {
    poolName: []const u8,
    poolBase: usize,
    allowSwapping: bool,
    buckets: usize = 0,
    usedBlocks: usize = 0,
    totalBlocks: usize = 0,
    anonymousPages: usize = 0,
    partialBucketHead: ?*Bucket = null,
    fullBucketHead: ?*Bucket = null,
};

pub var StaticPool: Pool = Pool{
    .poolName = "StaticPool",
    .poolBase = 0xfffffe8000000000,
    .allowSwapping = false,
};

pub var PagedPool: Pool = Pool{
    .poolName = "PagedPool",
    .poolBase = 0xfffffe8000000000,
    .allowSwapping = true,
};
