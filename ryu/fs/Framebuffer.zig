const std = @import("std");
const FS = @import("root").FS;
const DevFS = @import("root").FS.DevFS;
const Spinlock = @import("root").Spinlock;
const HAL = @import("root").HAL;
const Memory = @import("root").Memory;

pub fn FBMap(inode: *FS.Inode, offset: isize, a: *allowzero void, size: usize) callconv(.C) isize {
    _ = offset;
    _ = inode;
    var addrSpace = HAL.Arch.GetHCB().activeThread.?.team.addressSpace;
    const old = HAL.Arch.IRQEnableDisable(false);
    var addr: usize = @intFromPtr(a);
    if (addr == 0) {
        const space = Memory.Paging.FindFreeSpace(addrSpace, 0x1000, size);
        if (space) |ad| {
            addr = ad;
        } else {
            _ = HAL.Arch.IRQEnableDisable(old);
            return -12;
        }
    }
    const ret = addr;
    const addrEnd = addr + size;
    var fbAddr: usize = @intFromPtr(HAL.Console.info.ptr) - 0xffff800000000000;
    while (addr < addrEnd) : (addr += 4096) {
        _ = Memory.Paging.MapPage(
            addrSpace,
            addr,
            Memory.Paging.MapRead | Memory.Paging.MapWrite | Memory.Paging.MapWriteComb,
            fbAddr,
        );
        fbAddr += 4096;
    }
    _ = HAL.Arch.IRQEnableDisable(old);
    return @as(isize, @intCast(ret));
}

const UserFBInfo = extern struct {
    width: u32,
    height: u32,
    pitch: u32,
    bpp: u32,
};

pub fn FBIOCtl(inode: *FS.Inode, request: usize, data: *allowzero void) callconv(.C) isize {
    _ = inode;
    if (request == 0x100) { // RYU_FB_GETINFO
        if (@intFromPtr(data) != 0) {
            const info = @as(*UserFBInfo, @ptrCast(@alignCast(data)));
            info.width = @as(u32, @intCast(HAL.Console.info.width));
            info.height = @as(u32, @intCast(HAL.Console.info.height));
            info.pitch = @as(u32, @intCast(HAL.Console.info.pitch));
            info.bpp = @as(u32, @intCast(HAL.Console.info.bpp));
        }
    }
    return 0;
}

var fbFile = FS.Inode{
    .stat = FS.Metadata{
        .mode = 0o0020660,
    },
    .isVirtual = true,
    .map = FBMap,
    .ioctl = FBIOCtl,
};

pub fn Init() void {
    DevFS.RegisterDevice("fb0", &fbFile);
}
