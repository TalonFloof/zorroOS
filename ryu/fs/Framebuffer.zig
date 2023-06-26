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
    var addr: usize = @ptrToInt(a);
    if (addr == 0) {
        const space = Memory.Paging.FindFreeSpace(addrSpace, 0x1000, size);
        if (space) |ad| {
            addr = ad;
        } else {
            _ = HAL.Arch.IRQEnableDisable(old);
            return -12;
        }
    }
    const addrEnd = addr + size;
    var fbAddr: usize = @ptrToInt(HAL.Console.info.ptr) - 0xffff800000000000;
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
    return @intCast(isize, addrEnd - size);
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
        if (@ptrToInt(data) != 0) {
            const info = @ptrCast(*UserFBInfo, @alignCast(@alignOf(*UserFBInfo), data));
            info.width = @intCast(u32, HAL.Console.info.width);
            info.height = @intCast(u32, HAL.Console.info.height);
            info.pitch = @intCast(u32, HAL.Console.info.pitch);
            info.bpp = @intCast(u32, HAL.Console.info.bpp);
        }
    }
    return 0;
}

var fbFile = FS.Inode{
    .stat = FS.Metadata{
        .mode = 0o0020660,
    },
    .map = FBMap,
    .ioctl = FBIOCtl,
};

pub fn Init() void {
    DevFS.RegisterDevice("fb0", &fbFile);
}
