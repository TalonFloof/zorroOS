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
        const entries: usize = (size / 16) + (if ((size % 16) != 0) 1 else 0);
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
                return @intToPtr([*]u8, addr)[0..size];
            }
        }
        return null;
    }

    pub fn Free(self: *Bucket, mem: []u8) void {
        const size = mem.len;
        const entries: usize = (size / 16) + (if ((size % 16) != 0) 1 else 0);
        self.usedEntries -= entries;
        const start = (@ptrToInt(mem.ptr) - @ptrToInt(self)) / 16;
        var i = start;
        while (i < start + entries) : (i += 1) {
            self.SetBit(i, false);
        }
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

    pub fn Alloc(self: *Pool, size: usize) ?[]u8 {
        if (size > 65024) {
            return self.AllocAnonPages(size);
        }
        var index = self.partialBucketHead;
        while (index != null) : (index = index.?.next) {
            const oldEntryCount = index.?.usedEntries;
            var ret = index.?.Alloc(size);
            if (ret != null) {
                if (index.?.usedEntries == 32512) {
                    // Relocate to Full Bucket List
                    if (index.?.prev) |prev| {
                        prev.next = index.?.next;
                    }
                    if (index.?.next) |next| {
                        next.prev = index.?.prev;
                    }
                    if (self.partialBucketHead == index) {
                        self.partialBucketHead = index.?.next;
                    }
                    self.fullBucketHead.?.prev = index;
                    index.?.next = self.fullBucketHead;
                    self.fullBucketHead = index;
                }
                self.usedBlocks += ((index.?.usedEntries) - oldEntryCount);
                return ret;
            }
        }
        // Allocate a new bucket
        var newBucket = self.AllocAnonPages(512 * 1024);
        var bucketHeader = @ptrCast(*Bucket, newBucket.?.ptr);
        self.anonymousPages -= (512 * 1024) / 4096;
        self.buckets += 1;
        self.totalBlocks += 32512;
        bucketHeader.next = self.partialBucketHead;
        var ret = bucketHeader.Alloc(size);
        self.usedBlocks += index.?.usedEntries;
        return ret;
    }

    pub fn AllocAnonPages(self: *Pool, size: usize) ?[]u8 {
        _ = size;
        _ = self;
        return null;
    }

    pub fn Free(self: *Pool, data: []u8) void {
        if (data.len > 65024) {
            self.FreeAnonPages(data);
            return;
        }
        var index = self.partialBucketHead;
        var bucket: ?*Bucket = null;
        while (index != null) : (index = index.?.next) {
            if (@ptrToInt(index) >= @ptrToInt(data.ptr) and @ptrToInt(index) + data.len <= (@ptrToInt(data.ptr) + (512 * 1024))) {
                bucket = index;
                break;
            }
        }
        if (bucket == null) {
            index = self.fullBucketHead;
            while (index != null) : (index = index.?.next) {
                if (@ptrToInt(index) >= @ptrToInt(data.ptr) and @ptrToInt(index) + data.len <= (@ptrToInt(data.ptr) + (512 * 1024))) {
                    bucket = index;
                    break;
                }
            }
        }
        if (bucket) |b| {
            var oldSize: u64 = b.usedEntries;
            b.Free(data);
            self.usedBlocks -= (oldSize - b.usedEntries);
            if (oldSize == 32512) {
                // Relocate to Partial Bucket List
                if (b.prev) |prev| {
                    prev.next = b.next;
                }
                if (b.next) |next| {
                    next.prev = b.prev;
                }
                if (self.fullBucketHead == b) {
                    self.fullBucketHead = b.next;
                }
                self.partialBucketHead.?.prev = b;
                b.prev = null;
                b.next = self.partialBucketHead;
                self.partialBucketHead = b;
            } else if (b.usedEntries == 0) {
                // Free the Bucket from memory
                if (b.prev) |prev| {
                    prev.next = b.next;
                }
                if (b.next) |next| {
                    next.prev = b.prev;
                }
                if (self.partialBucketHead == b) {
                    self.partialBucketHead = b.next;
                }
                self.totalBlocks -= 32512;
                self.buckets -= 1;
                self.anonymousPages += (512 * 1024) / 4096;
                self.FreeAnonPages(@ptrCast([*]u8, bucket)[0..(512 * 1024)]);
            }
        }
    }

    pub fn FreeAnonPages(self: *Pool, data: []u8) void {
        _ = data;
        _ = self;
    }
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
