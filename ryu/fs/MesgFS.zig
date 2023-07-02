const std = @import("std");
const FS = @import("root").FS;
const AATree = @import("root").AATree;
const Spinlock = @import("root").Spinlock;
const Memory = @import("root").Memory;

const MessageQueue = struct {
    owner: i64,
};

const ClientTree = AATree(
    i64,
);

const MQData = struct {};

var mesgFSRoot: FS.Inode = FS.Inode{
    .stat = FS.Metadata{
        .mode = 0o0040775,
    },
    .create = &Create,
};

var nextInodeID: i64 = 1;

pub fn Create(inode: *FS.Inode, name: [*c]const u8, mode: usize) callconv(.C) isize {
    const id = nextInodeID;
    const len: usize = std.mem.len(name);
    var in: *FS.Inode = @as(*FS.Inode, @ptrCast(@alignCast(Memory.Pool.PagedPool.Alloc(@sizeOf(FS.Inode)).?.ptr)));
    @memset(@as([*]u8, @ptrFromInt(@intFromPtr(&in.name)))[0..256], 0);
    @memcpy(@as([*]u8, @ptrFromInt(@intFromPtr(&in.name)))[0..len], name[0..len]);
    in.hasReadEntries = true;
    in.stat.ID = id;
    in.stat.nlinks = 1;
    in.stat.uid = 1;
    in.stat.gid = 1;
    in.stat.mode = @as(i32, @intCast(mode));
    in.stat.reserved3 = 0; // reserved3 is used to store the capacity of the file's data (not the size!)
    in.stat.size = 0;
    in.mountOwner = inode.mountOwner;
    in.parent = inode;
    in.lock = 0;
    nextInodeID += 1;
    FS.AddInodeToParent(in);
    return 0;
}

pub fn Init() void {
    FS.DevFS.RegisterDevice("mqueue", &mesgFSRoot);
}
