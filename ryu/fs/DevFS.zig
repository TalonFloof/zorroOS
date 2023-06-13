const std = @import("std");
const FS = @import("root").FS;
const Spinlock = @import("root").Spinlock;

var devRootInfo: FS.Metadata = FS.Metadata{
    .ID = 1,
    .mode = 0x041ed, // drwxr-xr-x
    .uid = 0,
    .gid = 0,
    .size = 0,
};

var nextID: i64 = 2;
var devLock: *Spinlock = .unaquired;

var mountpoint: FS.Mountpoint = FS.Mountpoint{
    .path = "/dev",
    .device = null,
    .data = null,
};

pub fn Init() void {
    FS.Mount(&mountpoint);
}
