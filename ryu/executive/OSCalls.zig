const HAL = @import("root").HAL;
const FS = @import("root").FS;
const Executive = @import("root").Executive;
const Memory = @import("root").Memory;
const Spinlock = @import("root").Spinlock;
const std = @import("std");

const CallCategory = enum(u16) {
    Null = 0,
    Filesystem = 1,
    Process = 2,
    Ryu = 3,
};

const FilesystemFuncs = enum(u16) { // All of these are just normal UNIX calls, kinda boring tbh...
    Open = 1,
    Close = 2,
    Read = 3,
    ReadDir = 4,
    Write = 5,
    LSeek = 6,
    Trunc = 7,
    Create = 8,
    Unlink = 9,
    Stat = 10,
    FStat = 11,
    ChOwn = 12,
    FChOwn = 13,
    ChMod = 14,
    FChMod = 15,
    IOCtl = 16,
    MMap = 17,
    MUnMap = 18,
    ChDir = 19,
    FChDir = 20,
    Dup = 21, // functions like dup2
    Mount = 22,
    UMount = 23,
};

const ProcessFuncs = enum(u16) {
    Yield = 1,
    Exit = 2,
    NewTeam = 3,
    GiveFD = 4,
    LoadExecImage = 5, // Basically exec except better since you can trigger it on either yourself or one of your child teams (if the child team isn't already running an image)
    CloneImage = 6, // Basically like fork but you also have to create a team first
    NewThread = 7,
    RenameThread = 8,
    KillThread = 9,
    KillTeam = 10,
    WaitForThread = 11,
    FindThreadID = 12,
    GetTeamInfo = 13,
    GetNextTeamInfo = 14,
    GetThreadInfo = 15,
    GetNextThreadInfo = 16,
    Eep = 17,
};

const RyuFuncs = enum(u16) {
    KernelLog = 1,
    GetUNIXTime = 2,
    GetSchedulerTicks = 3,
};

const DirEntry = extern struct {
    inodeID: i64,
    nameLen: u8,
    name: [1]u8,
};

pub export fn RyuSyscallDispatch(regs: *HAL.Arch.Context) callconv(.C) void {
    const cat: CallCategory = @as(CallCategory, @enumFromInt(@as(u16, @intCast((regs.GetReg(0) & 0xFFFF0000) >> 16))));
    const func: u16 = @as(u16, @intCast(regs.GetReg(0) & 0xFFFF));
    //HAL.Console.Put("SystemCall | Cat: {x} Func: {x} ({x},{x},{x},{x},{x},{x})\n", .{ @enumToInt(cat), func, regs.GetReg(1), regs.GetReg(2), regs.GetReg(3), regs.GetReg(4), regs.GetReg(5), regs.GetReg(6) });
    switch (cat) {
        .Filesystem => {
            switch (@as(FilesystemFuncs, @enumFromInt(func))) {
                .Open => { // FileDesc_t Open(*const char name, int mode)
                    const path = @as([*]const u8, @ptrFromInt(regs.GetReg(1)))[0..std.mem.len(@as([*c]const u8, @ptrFromInt(regs.GetReg(1))))];
                    const team = HAL.Arch.GetHCB().activeThread.?.team;
                    if (FS.GetInode(path, team.cwd.?)) |inode| {
                        const old = HAL.Arch.IRQEnableDisable(false);
                        const node = @as(*Executive.Team.FileDescriptor, @ptrFromInt(@intFromPtr(Memory.Pool.PagedPool.Alloc(@sizeOf(Executive.Team.FileDescriptor)).?.ptr)));
                        node.inode = inode;
                        node.offset = 0;
                        team.fdLock.acquire();
                        const id = team.nextFD;
                        team.nextFD += 1;
                        team.fds.insert(id, node);
                        team.fdLock.release();
                        if (inode.open) |open| {
                            @as(*Spinlock, @ptrCast(&inode.lock)).acquire();
                            _ = open(inode, @as(usize, @intCast(regs.GetReg(2))));
                            regs.SetReg(0, @as(u64, @intCast(id)));
                            @as(*Spinlock, @ptrCast(&inode.lock)).release();
                        } else {
                            regs.SetReg(0, @as(u64, @intCast(id)));
                        }
                        _ = HAL.Arch.IRQEnableDisable(old);
                    } else {
                        regs.SetReg(0, @as(u64, @bitCast(@as(i64, @intCast(-2)))));
                    }
                },
                .Close => { // Status_t Close(FileDesc_t fd)
                    const team = HAL.Arch.GetHCB().activeThread.?.team;
                    const old = HAL.Arch.IRQEnableDisable(false);
                    team.fdLock.acquire();
                    if (team.fds.search(@as(i64, @bitCast(regs.GetReg(1))))) |node| {
                        team.fdLock.release();
                        if (node.inode.close) |close| {
                            @as(*Spinlock, @ptrCast(&node.inode.lock)).acquire();
                            close(node.inode);
                            @as(*Spinlock, @ptrCast(&node.inode.lock)).release();
                        }
                        regs.SetReg(0, 0);
                        team.fdLock.acquire();
                        Memory.Pool.PagedPool.Free(@as([*]u8, @ptrFromInt(@intFromPtr(node)))[0..@sizeOf(Executive.Team.FileDescriptor)]);
                        team.fds.delete(@as(i64, @bitCast(regs.GetReg(1))));
                        team.fdLock.release();
                    } else {
                        team.fdLock.release();
                        regs.SetReg(0, @as(u64, @bitCast(@as(i64, @intCast(-9)))));
                    }
                    _ = HAL.Arch.IRQEnableDisable(old);
                },
                .Read => { // size_t Read(FileDesc_t fd, void *base, size_t size)
                    const team = HAL.Arch.GetHCB().activeThread.?.team;
                    const old = HAL.Arch.IRQEnableDisable(false);
                    team.fdLock.acquire();
                    if (team.fds.search(@as(i64, @bitCast(regs.GetReg(1))))) |node| {
                        team.fdLock.release();
                        const inode: *FS.Inode = node.inode;
                        if ((inode.stat.mode & 0o0770000) != 0o0040000) {
                            if (inode.read) |read| {
                                @as(*Spinlock, @ptrCast(&inode.lock)).acquire();
                                const res = read(inode, @as(isize, @intCast(node.offset)), @as(*void, @ptrFromInt(@as(usize, @intCast(regs.GetReg(2))))), @as(isize, @bitCast(@as(usize, @intCast(regs.GetReg(3))))));
                                if (res >= 0) {
                                    node.offset += @as(i64, @intCast(res));
                                }
                                regs.SetReg(0, @as(u64, @bitCast(@as(i64, @intCast(res)))));
                                @as(*Spinlock, @ptrCast(&inode.lock)).release();
                            } else {
                                regs.SetReg(0, @as(u64, @bitCast(@as(i64, @intCast(-38)))));
                            }
                        } else {
                            regs.SetReg(0, @as(u64, @bitCast(@as(i64, @intCast(-21)))));
                        }
                    } else {
                        team.fdLock.release();
                        regs.SetReg(0, @as(u64, @bitCast(@as(i64, @intCast(-9)))));
                    }
                    _ = HAL.Arch.IRQEnableDisable(old);
                },
                .ReadDir => { // size_t ReadDir(FileDesc_t fd, int offset, void* addr)
                    const team = HAL.Arch.GetHCB().activeThread.?.team;
                    const old = HAL.Arch.IRQEnableDisable(false);
                    team.fdLock.acquire();
                    if (team.fds.search(@as(i64, @bitCast(regs.GetReg(1))))) |node| {
                        team.fdLock.release();
                        const inode: *FS.Inode = node.inode;
                        if ((inode.stat.mode & 0o0770000) == 0o0040000) {
                            if (FS.ReadDir(inode, @as(usize, @intCast(regs.GetReg(2))))) |entry| {
                                const name = @as([*]const u8, @ptrCast(&entry.name))[0..(std.mem.len(@as([*c]const u8, @ptrCast(&entry.name))) + 1)];
                                const dirEnt = @as(*DirEntry, @ptrFromInt(@as(usize, @intCast(regs.GetReg(3)))));
                                dirEnt.inodeID = entry.stat.ID;
                                dirEnt.nameLen = @as(u8, @intCast((name.len - 1) & 0xFF));
                                @memcpy(@as([*]u8, @ptrFromInt(@intFromPtr(&dirEnt.name)))[0..name.len], name);
                                regs.SetReg(0, @as(u64, @intCast((@sizeOf(DirEntry) - @sizeOf([1]u8)) + name.len)));
                            } else {
                                regs.SetReg(0, 0);
                            }
                        } else {
                            regs.SetReg(0, @as(u64, @bitCast(@as(i64, @intCast(-20)))));
                        }
                    } else {
                        team.fdLock.release();
                        regs.SetReg(0, @as(u64, @bitCast(@as(i64, @intCast(-9)))));
                    }
                    _ = HAL.Arch.IRQEnableDisable(old);
                },
                .Write => { // size_t Write(FileDesc_t fd, void* base, size_t size)
                    const team = HAL.Arch.GetHCB().activeThread.?.team;
                    const old = HAL.Arch.IRQEnableDisable(false);
                    team.fdLock.acquire();
                    if (team.fds.search(@as(i64, @bitCast(regs.GetReg(1))))) |node| {
                        team.fdLock.release();
                        const inode: *FS.Inode = node.inode;
                        if ((inode.stat.mode & 0o0770000) != 0o0040000) {
                            if (inode.write) |write| {
                                @as(*Spinlock, @ptrCast(&inode.lock)).acquire();
                                const res = write(inode, @as(isize, @intCast(node.offset)), @as(*void, @ptrFromInt(@as(usize, @intCast(regs.GetReg(2))))), @as(isize, @bitCast(@as(usize, @intCast(regs.GetReg(3))))));
                                if (res >= 0) {
                                    node.offset += @as(i64, @intCast(res));
                                }
                                regs.SetReg(0, @as(u64, @bitCast(@as(i64, @intCast(res)))));
                                @as(*Spinlock, @ptrCast(&inode.lock)).release();
                            } else {
                                regs.SetReg(0, @as(u64, @bitCast(@as(i64, @intCast(-38)))));
                            }
                        } else {
                            regs.SetReg(0, @as(u64, @bitCast(@as(i64, @intCast(-21)))));
                        }
                    } else {
                        team.fdLock.release();
                        regs.SetReg(0, @as(u64, @bitCast(@as(i64, @intCast(-9)))));
                    }
                    _ = HAL.Arch.IRQEnableDisable(old);
                },
                .LSeek => { // off_t LSeek(FileDesc_t fd, off_t offset, int whence)
                    const team = HAL.Arch.GetHCB().activeThread.?.team;
                    const old = HAL.Arch.IRQEnableDisable(false);
                    team.fdLock.acquire();
                    if (team.fds.search(@as(i64, @bitCast(regs.GetReg(1))))) |node| {
                        team.fdLock.release();
                        const inode: *FS.Inode = node.inode;
                        if ((inode.stat.mode & 0o0770000) != 0o0040000) {
                            const size: i64 = inode.stat.size;
                            switch (regs.GetReg(3)) {
                                1 => {
                                    node.offset += @as(i64, @bitCast(regs.GetReg(2)));
                                    if (node.offset > size) {
                                        node.offset = size;
                                    }
                                    regs.SetReg(0, @as(u64, @bitCast(node.offset)));
                                },
                                2 => {
                                    node.offset = size + @as(i64, @bitCast(regs.GetReg(2)));
                                    if (node.offset > size) {
                                        node.offset = size;
                                    }
                                    regs.SetReg(0, @as(u64, @bitCast(node.offset)));
                                },
                                3 => {
                                    node.offset = @as(i64, @bitCast(regs.GetReg(2)));
                                    if (node.offset > size) {
                                        node.offset = size;
                                    }
                                    regs.SetReg(0, @as(u64, @bitCast(node.offset)));
                                },
                                else => {
                                    regs.SetReg(0, @as(u64, @bitCast(@as(i64, @intCast(-21)))));
                                },
                            }
                        } else {
                            regs.SetReg(0, @as(u64, @bitCast(@as(i64, @intCast(-21)))));
                        }
                    } else {
                        team.fdLock.release();
                        regs.SetReg(0, @as(u64, @bitCast(@as(i64, @intCast(-9)))));
                    }
                    _ = HAL.Arch.IRQEnableDisable(old);
                },
                .Trunc => {
                    const team = HAL.Arch.GetHCB().activeThread.?.team;
                    const old = HAL.Arch.IRQEnableDisable(false);
                    team.fdLock.acquire();
                    if (team.fds.search(@as(i64, @bitCast(regs.GetReg(1))))) |node| {
                        team.fdLock.release();
                        const inode: *FS.Inode = node.inode;
                        if ((inode.stat.mode & 0o0770000) != 0o0040000) {
                            if (inode.trunc) |trunc| {
                                @as(*Spinlock, @ptrCast(&inode.lock)).acquire();
                                const res = trunc(inode, @as(isize, @bitCast(@as(usize, @intCast(regs.GetReg(2))))));
                                regs.SetReg(0, @as(u64, @bitCast(@as(i64, @intCast(res)))));
                                @as(*Spinlock, @ptrCast(&inode.lock)).release();
                            } else {
                                regs.SetReg(0, @as(u64, @bitCast(@as(i64, @intCast(-38)))));
                            }
                        } else {
                            regs.SetReg(0, @as(u64, @bitCast(@as(i64, @intCast(-21)))));
                        }
                    } else {
                        team.fdLock.release();
                        regs.SetReg(0, @as(u64, @bitCast(@as(i64, @intCast(-9)))));
                    }
                    _ = HAL.Arch.IRQEnableDisable(old);
                },
                .Create => { // Status_t Create(const char* path, int mode)
                    const path = @as([*]const u8, @ptrFromInt(regs.GetReg(1)))[0..std.mem.len(@as([*c]const u8, @ptrFromInt(regs.GetReg(1))))];
                    const lastSep: ?usize = std.mem.lastIndexOf(u8, path, "/");
                    const name = if (lastSep != null) path[(lastSep.? + 1)..path.len] else path[0..path.len];
                    var parent: ?*FS.Inode = FS.rootInode;
                    if (lastSep != null) {
                        const old = HAL.Arch.IRQEnableDisable(false);
                        parent = FS.GetInode(path[0..lastSep.?], parent.?);
                        _ = HAL.Arch.IRQEnableDisable(old);
                    }
                    if (parent == null) {
                        regs.SetReg(0, @as(u64, @bitCast(@as(i64, @intCast(-2)))));
                        return;
                    }
                    if (parent.?.create) |create| {
                        const old = HAL.Arch.IRQEnableDisable(false);
                        @as(*Spinlock, @ptrCast(&parent.?.lock)).acquire();
                        regs.SetReg(0, @as(u64, @bitCast(@as(i64, @intCast(create(parent.?, @as([*c]const u8, @ptrCast(name.ptr)), @as(usize, @intCast(regs.GetReg(3)))))))));
                        @as(*Spinlock, @ptrCast(&parent.?.lock)).release();
                        _ = HAL.Arch.IRQEnableDisable(old);
                    } else {
                        regs.SetReg(0, @as(u64, @bitCast(@as(i64, @intCast(-38)))));
                    }
                },
                .Unlink => { // Status_t Unlink(const char* path)
                    const path = @as([*]const u8, @ptrFromInt(regs.GetReg(1)))[0..std.mem.len(@as([*c]const u8, @ptrFromInt(regs.GetReg(1))))];
                    const old = HAL.Arch.IRQEnableDisable(false);
                    if (FS.GetInode(path, FS.rootInode.?)) |inode| {
                        _ = HAL.Arch.IRQEnableDisable(old);
                        if (inode.unlink) |unlink| {
                            const o = HAL.Arch.IRQEnableDisable(false);
                            @as(*Spinlock, @ptrCast(&inode.lock)).acquire();
                            const ret: isize = unlink(inode);
                            regs.SetReg(0, @as(u64, @bitCast(@as(i64, @intCast(ret)))));
                            if (ret != 0) {
                                @as(*Spinlock, @ptrCast(&inode.lock)).release();
                            }
                            _ = HAL.Arch.IRQEnableDisable(o);
                        } else {
                            regs.SetReg(0, @as(u64, @bitCast(@as(i64, @intCast(-38)))));
                        }
                    } else {
                        _ = HAL.Arch.IRQEnableDisable(old);
                        regs.SetReg(0, @as(u64, @bitCast(@as(i64, @intCast(-2)))));
                    }
                },
                .Stat => { // Status_t Stat(const char* path, stat_t* ptr)
                    const path = @as([*]const u8, @ptrFromInt(regs.GetReg(1)))[0..std.mem.len(@as([*c]const u8, @ptrFromInt(regs.GetReg(1))))];
                    const old = HAL.Arch.IRQEnableDisable(false);
                    if (FS.GetInode(path, FS.rootInode.?)) |inode| {
                        @as(*FS.Metadata, @ptrFromInt(regs.GetReg(2))).* = inode.stat;
                        _ = HAL.Arch.IRQEnableDisable(old);
                        regs.SetReg(0, 0);
                    } else {
                        _ = HAL.Arch.IRQEnableDisable(old);
                        regs.SetReg(0, @as(u64, @bitCast(@as(i64, @intCast(-2)))));
                    }
                },
                .FStat => { // Status_t FStat(FileDesc_t fd, stat_t* ptr)
                    const team = HAL.Arch.GetHCB().activeThread.?.team;
                    const old = HAL.Arch.IRQEnableDisable(false);
                    team.fdLock.acquire();
                    if (team.fds.search(@as(i64, @bitCast(regs.GetReg(1))))) |node| {
                        const inode: *FS.Inode = node.inode;
                        team.fdLock.release();
                        @as(*FS.Metadata, @ptrFromInt(regs.GetReg(2))).* = inode.stat;
                        _ = HAL.Arch.IRQEnableDisable(old);
                        regs.SetReg(0, 0);
                    } else {
                        _ = HAL.Arch.IRQEnableDisable(old);
                        regs.SetReg(0, @as(u64, @bitCast(@as(i64, @intCast(-9)))));
                    }
                },
                .IOCtl => { // long IOCtl(FileDesc_t fd, unsigned int request, void* arg)
                    const team = HAL.Arch.GetHCB().activeThread.?.team;
                    const old = HAL.Arch.IRQEnableDisable(false);
                    team.fdLock.acquire();
                    if (team.fds.search(@as(i64, @bitCast(regs.GetReg(1))))) |node| {
                        const inode: *FS.Inode = node.inode;
                        team.fdLock.release();
                        _ = HAL.Arch.IRQEnableDisable(old);
                        if (inode.ioctl) |ioctl| {
                            const o = HAL.Arch.IRQEnableDisable(false);
                            @as(*Spinlock, @ptrCast(&inode.lock)).acquire();
                            regs.SetReg(0, @as(u64, @bitCast(@as(i64, @intCast(ioctl(inode, @as(usize, @intCast(regs.GetReg(2))), @as(*allowzero void, @ptrFromInt(regs.GetReg(3)))))))));
                            @as(*Spinlock, @ptrCast(&inode.lock)).release();
                            _ = HAL.Arch.IRQEnableDisable(o);
                        } else {
                            regs.SetReg(0, @as(u64, @bitCast(@as(i64, @intCast(-38)))));
                        }
                    } else {
                        team.fdLock.release();
                        _ = HAL.Arch.IRQEnableDisable(old);
                        regs.SetReg(0, @as(u64, @bitCast(@as(i64, @intCast(-9)))));
                    }
                },
                .MMap => { // void* MMap(void* addr, size_t length, int prot, int flags, int fd, off_t offset)
                    const addr = @as(*allowzero void, @ptrFromInt(regs.GetReg(1)));
                    const length = @as(usize, @intCast(regs.GetReg(2)));
                    const prot = regs.GetReg(3);
                    _ = prot;
                    const flags = regs.GetReg(4);
                    const fd = @as(i64, @bitCast(regs.GetReg(5)));
                    const offset = @as(isize, @bitCast(@as(usize, @intCast(regs.GetReg(6)))));
                    if (flags & 0x8 != 0) { // Anonymous Mapping
                        regs.SetReg(0, @as(u64, @bitCast(@as(i64, @intCast(-38)))));
                    } else {
                        const old = HAL.Arch.IRQEnableDisable(false);
                        const team = HAL.Arch.GetHCB().activeThread.?.team;
                        team.fdLock.acquire();
                        if (team.fds.search(fd)) |node| {
                            const inode: *FS.Inode = node.inode;
                            team.fdLock.release();
                            if (inode.map) |mmap| {
                                @as(*Spinlock, @ptrCast(&inode.lock)).acquire();
                                regs.SetReg(0, @as(u64, @bitCast(@as(i64, @intCast(mmap(
                                    inode,
                                    offset,
                                    addr,
                                    length,
                                ))))));
                                @as(*Spinlock, @ptrCast(&inode.lock)).release();
                            } else {
                                regs.SetReg(0, @as(u64, @bitCast(@as(i64, @intCast(-38)))));
                            }
                        } else {
                            team.fdLock.release();
                            regs.SetReg(0, @as(u64, @bitCast(@as(i64, @intCast(-9)))));
                        }
                        _ = HAL.Arch.IRQEnableDisable(old);
                    }
                },
                .MUnMap => {
                    const addrSpace = HAL.Arch.GetHCB().activeThread.?.team.addressSpace;
                    var addr = @as(usize, @intCast(regs.GetReg(1)));
                    const length = @as(usize, @intCast(regs.GetReg(2)));
                    const addrStart = @as(usize, @intCast(regs.GetReg(1)));
                    const old = HAL.Arch.IRQEnableDisable(false);
                    while (addr < addrStart + length) : (addr += 4096) {
                        const pte: HAL.PTEEntry = Memory.Paging.GetPage(addrSpace, addr);
                        if (pte.r == 1) {
                            _ = Memory.Paging.MapPage(addrSpace, addr, 0, 0);
                            Memory.PFN.DereferencePage(@as(usize, @intCast(pte.phys)) << 12);
                        }
                    }
                    _ = HAL.Arch.IRQEnableDisable(old);
                    regs.SetReg(0, 0);
                },
                .ChDir => { // Status_t ChDir(const char* path)
                    const team = HAL.Arch.GetHCB().activeThread.?.team;
                    const path = @as([*]const u8, @ptrFromInt(regs.GetReg(1)))[0..std.mem.len(@as([*c]const u8, @ptrFromInt(regs.GetReg(1))))];
                    const old = HAL.Arch.IRQEnableDisable(false);
                    if (FS.GetInode(path, FS.rootInode.?)) |inode| {
                        if ((inode.stat.mode & 0o0770000) == 0o0040000) {
                            team.cwd = inode;
                            regs.SetReg(0, 0);
                        } else {
                            regs.SetReg(0, @as(u64, @bitCast(@as(i64, @intCast(-20)))));
                        }
                    } else {
                        regs.SetReg(0, @as(u64, @bitCast(@as(i64, @intCast(-2)))));
                    }
                    _ = HAL.Arch.IRQEnableDisable(old);
                },
                else => {
                    regs.SetReg(0, @as(u64, @bitCast(@as(i64, @intCast(-4096)))));
                },
            }
        },
        .Process => {
            switch (@as(ProcessFuncs, @enumFromInt(func))) {
                .Yield => { // void Yield()
                    const old = HAL.Arch.IRQEnableDisable(false);
                    _ = HAL.Arch.ThreadYield();
                    _ = HAL.Arch.IRQEnableDisable(old);
                    regs.SetReg(0, 0);
                },
                .Exit => { // !!noreturn Exit(int code)
                    _ = HAL.Arch.IRQEnableDisable(false);
                    const thread: *Executive.Thread.Thread = HAL.Arch.GetHCB().activeThread.?;
                    thread.exitReason = regs.GetReg(1);
                    Executive.Thread.KillThread(thread.threadID);
                    _ = HAL.Arch.ThreadYield();
                },
                .NewTeam => { // TeamID_t NewTeam(*const char name)
                    const old = HAL.Arch.IRQEnableDisable(false);
                    const team = HAL.Arch.GetHCB().activeThread.?.team;
                    const name = @as([*]const u8, @ptrFromInt(regs.GetReg(1)))[0..std.mem.len(@as([*c]const u8, @ptrFromInt(regs.GetReg(1))))];
                    const newTeam = Executive.Team.NewTeam(team, name);
                    regs.SetReg(0, @as(u64, @intCast(newTeam.teamID)));
                    _ = HAL.Arch.IRQEnableDisable(old);
                },
                .LoadExecImage => { // Status_t LoadExecImage(TeamID_t teamID, const char** argv, const char** envp)
                    const old = HAL.Arch.IRQEnableDisable(false);
                    const team = HAL.Arch.GetHCB().activeThread.?.team;
                    const destTeamID = @as(i64, @bitCast(@as(u64, @intCast(regs.GetReg(1)))));
                    const cArgs = @as([*:null]?[*:0]const u8, @ptrFromInt(regs.GetReg(2)));
                    const args = cArgs[0..std.mem.len(cArgs)];
                    if (team.teamID == destTeamID) {
                        regs.SetReg(0, @as(u64, @bitCast(@as(i64, @intCast(-38)))));
                    } else {
                        if (Executive.Team.GetTeamByID(destTeamID)) |destTeam| {
                            if (@intFromPtr(destTeam.mainThread) == 0) {
                                if (Executive.Team.LoadELFImage(args[0].?[0..std.mem.len(args[0].?)], destTeam)) |entry| {
                                    _ = Executive.Thread.NewThread(destTeam, @as([*]u8, @ptrCast(@constCast("Main Thread")))[0..11], entry, 0x9ff8, 10);
                                    regs.SetReg(0, 0);
                                } else {
                                    regs.SetReg(0, @as(u64, @bitCast(@as(i64, @intCast(-2)))));
                                }
                            } else {
                                regs.SetReg(0, @as(u64, @bitCast(@as(i64, @intCast(-13)))));
                            }
                        } else {
                            regs.SetReg(0, @as(u64, @bitCast(@as(i64, @intCast(-3)))));
                        }
                    }
                    _ = HAL.Arch.IRQEnableDisable(old);
                },
                else => {
                    regs.SetReg(0, @as(u64, @bitCast(@as(i64, @intCast(-4096)))));
                },
            }
        },
        .Ryu => {
            switch (@as(RyuFuncs, @enumFromInt(func))) {
                .KernelLog => { // void KernelLog(*const char text)
                    var s: [*c]const u8 = @as([*c]const u8, @ptrFromInt(regs.GetReg(1)));
                    HAL.Console.Put("{s}", .{@as([*]const u8, @ptrCast(s))[0..std.mem.len(s)]});
                    regs.SetReg(0, 0);
                },
                else => {
                    regs.SetReg(0, @as(u64, @bitCast(@as(i64, @intCast(-4096)))));
                },
            }
        },
        else => {
            regs.SetReg(0, @as(u64, @bitCast(@as(i64, @intCast(-4096)))));
        },
    }
}

pub fn stub() void { // Doesn't do anything but helps to keep Zig from optimizing this file out

}
