const AATree = @import("root").AATree;
const Spinlock = @import("root").Spinlock;
const std = @import("std");
const Memory = @import("root").Memory;
const HAL = @import("root").HAL;

const SHMTreeType = AATree(i64, []u8);

pub var shm: SHMTreeType = SHMTreeType{};
pub var shmLock: Spinlock = .unaquired;
pub var nextShmID: i64 = 1;

pub fn CreateSHM(size: usize) i64 {
    const old = HAL.Arch.IRQEnableDisable(false);
    shmLock.acquire();
    const id = nextShmID;
    nextShmID += 1;
    const dat = Memory.Pool.StaticPool.AllocAnonPages(size).?;
    shm.insert(id, dat);
    shmLock.release();
    _ = HAL.Arch.IRQEnableDisable(old);
    return id;
}

pub fn MapSHM(id: i64) ?usize {
    const old = HAL.Arch.IRQEnableDisable(false);
    shmLock.acquire();
    if (shm.search(id)) |data| {
        var addrSpace = HAL.Arch.GetHCB().activeThread.?.team.addressSpace;
        const space: usize = Memory.Paging.FindFreeSpace(addrSpace, 0x1000, data.len).?;
        var addr: usize = space;
        const addrEnd = space + data.len;
        while (addr < addrEnd) : (addr += 4096) {
            var phys = @as(usize, @intCast(Memory.Paging.GetPage(addrSpace, (addr - space) + @intFromPtr(data.ptr)).phys)) << 12;
            _ = Memory.Paging.MapPage(
                addrSpace,
                addr,
                Memory.Paging.MapRead | Memory.Paging.MapWrite,
                phys,
            );
            Memory.PFN.ReferencePage(phys);
        }
        shmLock.release();
        _ = HAL.Arch.IRQEnableDisable(old);
        return space;
    }
    shmLock.release();
    _ = HAL.Arch.IRQEnableDisable(old);
    return null;
}

pub fn RemoveSHM(id: i64) bool {
    const old = HAL.Arch.IRQEnableDisable(false);
    shmLock.acquire();
    if (shm.search(id)) |data| {
        Memory.Pool.StaticPool.FreeAnonPages(data);
        shm.delete(id);
        shmLock.release();
        _ = HAL.Arch.IRQEnableDisable(old);
        return true;
    }
    shmLock.release();
    _ = HAL.Arch.IRQEnableDisable(old);
    return false;
}
