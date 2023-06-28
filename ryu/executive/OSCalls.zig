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
    Dup = 20, // functions like dup2
};

const ProcessFuncs = enum(u16) {
    NewTeam = 1,
    LoadExecImage = 2, // Basically exec except better since you can trigger it on either yourself or one of your child teams
    CloneImage = 3, // Basically like fork but you also have to create a team first
    NewThread = 4,
    RenameThread = 5,
    KillThread = 6,
    KillTeam = 7,
    Exit = 8,
    WaitForThread = 9,
    FindThreadID = 10,
    GetTeamInfo = 11,
    GetNextTeamInfo = 12,
    GetThreadInfo = 13,
    GetNextThreadInfo = 14,
    Eep = 15,
};

const RyuFuncs = enum(u16) {
    KernelLog = 1,
};

const DirEntry = extern struct {
    inodeID: i64,
    nameLen: u8,
    name: [1]u8,
};

const TEAM_CREATE_INHERIT_FILES: usize = 1;

pub export fn RyuSyscallDispatch(regs: *HAL.Arch.Context) callconv(.C) void {
    const cat: CallCategory = @intToEnum(CallCategory, @intCast(u16, (regs.GetReg(0) & 0xFFFF0000) >> 16));
    const func: u16 = @intCast(u16, regs.GetReg(0) & 0xFFFF);
    //HAL.Console.Put("SystemCall | Cat: {x} Func: {x} ({x},{x},{x},{x},{x},{x})\n", .{ @enumToInt(cat), func, regs.GetReg(1), regs.GetReg(2), regs.GetReg(3), regs.GetReg(4), regs.GetReg(5), regs.GetReg(6) });
    switch (cat) {
        .Filesystem => {
            switch (@intToEnum(FilesystemFuncs, func)) {
                .Open => { // FileDesc_t Open(*const char name, int mode)
                    const path = @intToPtr([*]const u8, regs.GetReg(1))[0..std.mem.len(@intToPtr([*c]const u8, regs.GetReg(1)))];
                    if (FS.GetInode(path, FS.rootInode.?)) |inode| {
                        const team = HAL.Arch.GetHCB().activeThread.?.team;
                        const node = @ptrCast(*Executive.Team.FDTree.Node, @alignCast(@alignOf(*Executive.Team.FDTree.Node), Memory.Pool.PagedPool.Alloc(@sizeOf(Executive.Team.FDTree.Node)).?.ptr));
                        node.value.inode = inode;
                        node.value.offset = 0;
                        node.key = team.nextFD;
                        team.nextFD += 1;
                        const old = HAL.Arch.IRQEnableDisable(false);
                        team.fds.insert(node);
                        if (inode.open) |open| {
                            @ptrCast(*Spinlock, &inode.lock).acquire();
                            _ = open(inode, @intCast(usize, regs.GetReg(2)));
                            regs.SetReg(0, @intCast(u64, node.key));
                            @ptrCast(*Spinlock, &inode.lock).release();
                        } else {
                            regs.SetReg(0, @intCast(u64, node.key));
                        }
                        _ = HAL.Arch.IRQEnableDisable(old);
                    } else {
                        regs.SetReg(0, @bitCast(u64, @intCast(i64, -2)));
                    }
                },
                .Close => { // Status_t Close(FileDesc_t fd)
                    const team = HAL.Arch.GetHCB().activeThread.?.team;
                    if (team.fds.search(@bitCast(i64, regs.GetReg(1)))) |node| {
                        const old = HAL.Arch.IRQEnableDisable(false);
                        if (node.value.inode.close) |close| {
                            @ptrCast(*Spinlock, &node.value.inode.lock).acquire();
                            close(node.value.inode);
                            @ptrCast(*Spinlock, &node.value.inode.lock).release();
                        }
                        regs.SetReg(0, 0);
                        team.fds.delete(node);
                        Memory.Pool.PagedPool.Free(@intToPtr([*]u8, @ptrToInt(node))[0..@sizeOf(Executive.Team.FDTree.Node)]);
                        _ = HAL.Arch.IRQEnableDisable(old);
                    } else {
                        regs.SetReg(0, @bitCast(u64, @intCast(i64, -9)));
                    }
                },
                .Read => { // size_t Read(FileDesc_t fd, void *base, size_t size)
                    const team = HAL.Arch.GetHCB().activeThread.?.team;
                    if (team.fds.search(@bitCast(i64, regs.GetReg(1)))) |node| {
                        const inode: *FS.Inode = node.value.inode;
                        if ((inode.stat.mode & 0o0770000) != 0o0040000) {
                            if (inode.read) |read| {
                                const old = HAL.Arch.IRQEnableDisable(false);
                                @ptrCast(*Spinlock, &inode.lock).acquire();
                                const res = read(inode, @intCast(isize, node.value.offset), @intToPtr(*void, @intCast(usize, regs.GetReg(2))), @bitCast(isize, @intCast(usize, regs.GetReg(3))));
                                if (res >= 0) {
                                    node.value.offset += @intCast(i64, res);
                                }
                                regs.SetReg(0, @bitCast(u64, @intCast(i64, res)));
                                @ptrCast(*Spinlock, &inode.lock).release();
                                _ = HAL.Arch.IRQEnableDisable(old);
                            } else {
                                regs.SetReg(0, @bitCast(u64, @intCast(i64, -38)));
                            }
                        } else {
                            regs.SetReg(0, @bitCast(u64, @intCast(i64, -21)));
                        }
                    } else {
                        regs.SetReg(0, @bitCast(u64, @intCast(i64, -9)));
                    }
                },
                .ReadDir => { // size_t ReadDir(FileDesc_t fd, int offset, void* addr)
                    const team = HAL.Arch.GetHCB().activeThread.?.team;
                    if (team.fds.search(@bitCast(i64, regs.GetReg(1)))) |node| {
                        const inode: *FS.Inode = node.value.inode;
                        if ((inode.stat.mode & 0o0770000) == 0o0040000) {
                            if (FS.ReadDir(inode, @intCast(usize, regs.GetReg(2)))) |entry| {
                                const name = @ptrCast([*]const u8, &entry.name)[0..(std.mem.len(@ptrCast([*c]const u8, &entry.name)) + 1)];
                                const dirEnt = @intToPtr(*DirEntry, @intCast(usize, regs.GetReg(3)));
                                dirEnt.inodeID = entry.stat.ID;
                                dirEnt.nameLen = @intCast(u8, (name.len - 1) & 0xFF);
                                @memcpy(@intToPtr([*]u8, @ptrToInt(&dirEnt.name))[0..name.len], name);
                                regs.SetReg(0, @intCast(u64, (@sizeOf(DirEntry) - @sizeOf([1]u8)) + name.len));
                            } else {
                                regs.SetReg(0, 0);
                            }
                        } else {
                            regs.SetReg(0, @bitCast(u64, @intCast(i64, -20)));
                        }
                    }
                },
                .Write => { // size_t Write(FileDesc_t fd, void* base, size_t size)
                    const team = HAL.Arch.GetHCB().activeThread.?.team;
                    if (team.fds.search(@bitCast(i64, regs.GetReg(1)))) |node| {
                        const inode: *FS.Inode = node.value.inode;
                        if ((inode.stat.mode & 0o0770000) != 0o0040000) {
                            if (inode.write) |write| {
                                const old = HAL.Arch.IRQEnableDisable(false);
                                @ptrCast(*Spinlock, &inode.lock).acquire();
                                const res = write(inode, @intCast(isize, node.value.offset), @intToPtr(*void, @intCast(usize, regs.GetReg(2))), @bitCast(isize, @intCast(usize, regs.GetReg(3))));
                                if (res >= 0) {
                                    node.value.offset += @intCast(i64, res);
                                }
                                regs.SetReg(0, @bitCast(u64, @intCast(i64, res)));
                                @ptrCast(*Spinlock, &inode.lock).release();
                                _ = HAL.Arch.IRQEnableDisable(old);
                            } else {
                                regs.SetReg(0, @bitCast(u64, @intCast(i64, -38)));
                            }
                        } else {
                            regs.SetReg(0, @bitCast(u64, @intCast(i64, -21)));
                        }
                    } else {
                        regs.SetReg(0, @bitCast(u64, @intCast(i64, -9)));
                    }
                },
                .LSeek => { // off_t LSeek(FileDesc_t fd, off_t offset, int whence)
                    const team = HAL.Arch.GetHCB().activeThread.?.team;
                    if (team.fds.search(@bitCast(i64, regs.GetReg(1)))) |node| {
                        if ((node.value.inode.stat.mode & 0o0770000) != 0o0040000) {
                            const size: i64 = node.value.inode.stat.size;
                            switch (regs.GetReg(3)) {
                                1 => {
                                    node.value.offset += @bitCast(i64, regs.GetReg(2));
                                    if (node.value.offset > size) {
                                        node.value.offset = size;
                                    }
                                    regs.SetReg(0, @bitCast(u64, node.value.offset));
                                },
                                2 => {
                                    node.value.offset = size + @bitCast(i64, regs.GetReg(2));
                                    if (node.value.offset > size) {
                                        node.value.offset = size;
                                    }
                                    regs.SetReg(0, @bitCast(u64, node.value.offset));
                                },
                                3 => {
                                    node.value.offset = @bitCast(i64, regs.GetReg(2));
                                    if (node.value.offset > size) {
                                        node.value.offset = size;
                                    }
                                    regs.SetReg(0, @bitCast(u64, node.value.offset));
                                },
                                else => {
                                    regs.SetReg(0, @bitCast(u64, @intCast(i64, -21)));
                                },
                            }
                        } else {
                            regs.SetReg(0, @bitCast(u64, @intCast(i64, -21)));
                        }
                    }
                },
                .Trunc => {
                    const team = HAL.Arch.GetHCB().activeThread.?.team;
                    if (team.fds.search(@bitCast(i64, regs.GetReg(1)))) |node| {
                        const inode: *FS.Inode = node.value.inode;
                        if ((inode.stat.mode & 0o0770000) != 0o0040000) {
                            if (inode.trunc) |trunc| {
                                const old = HAL.Arch.IRQEnableDisable(false);
                                @ptrCast(*Spinlock, &inode.lock).acquire();
                                const res = trunc(inode, @bitCast(isize, @intCast(usize, regs.GetReg(2))));
                                regs.SetReg(0, @bitCast(u64, @intCast(i64, res)));
                                @ptrCast(*Spinlock, &inode.lock).release();
                                _ = HAL.Arch.IRQEnableDisable(old);
                            } else {
                                regs.SetReg(0, @bitCast(u64, @intCast(i64, -38)));
                            }
                        } else {
                            regs.SetReg(0, @bitCast(u64, @intCast(i64, -21)));
                        }
                    } else {
                        regs.SetReg(0, @bitCast(u64, @intCast(i64, -9)));
                    }
                },
                .Create => { // Status_t Create(const char* path, int mode)
                    const path = @intToPtr([*]const u8, regs.GetReg(1))[0..std.mem.len(@intToPtr([*c]const u8, regs.GetReg(1)))];
                    const lastSep: ?usize = std.mem.lastIndexOf(u8, path, "/");
                    const name = if (lastSep != null) path[(lastSep.? + 1)..path.len] else path[0..path.len];
                    var parent: ?*FS.Inode = FS.rootInode;
                    if (lastSep != null) {
                        parent = FS.GetInode(path[0..lastSep.?], parent.?);
                    }
                    if (parent == null) {
                        regs.SetReg(0, @bitCast(u64, @intCast(i64, -2)));
                        return;
                    }
                    if (parent.?.create) |create| {
                        const old = HAL.Arch.IRQEnableDisable(false);
                        @ptrCast(*Spinlock, &parent.?.lock).acquire();
                        regs.SetReg(0, @bitCast(u64, @intCast(i64, create(parent.?, @ptrCast([*c]const u8, name.ptr), @intCast(usize, regs.GetReg(3))))));
                        @ptrCast(*Spinlock, &parent.?.lock).release();
                        _ = HAL.Arch.IRQEnableDisable(old);
                    } else {
                        regs.SetReg(0, @bitCast(u64, @intCast(i64, -38)));
                    }
                },
                .Unlink => { // Status_t Unlink(const char* path)
                    const path = @intToPtr([*]const u8, regs.GetReg(1))[0..std.mem.len(@intToPtr([*c]const u8, regs.GetReg(1)))];
                    if (FS.GetInode(path, FS.rootInode.?)) |inode| {
                        if (inode.unlink) |unlink| {
                            const old = HAL.Arch.IRQEnableDisable(false);
                            @ptrCast(*Spinlock, &inode.lock).acquire();
                            const ret: isize = unlink(inode);
                            regs.SetReg(0, @bitCast(u64, @intCast(i64, ret)));
                            if (ret != 0) {
                                @ptrCast(*Spinlock, &inode.lock).release();
                            }
                            _ = HAL.Arch.IRQEnableDisable(old);
                        } else {
                            regs.SetReg(0, @bitCast(u64, @intCast(i64, -38)));
                        }
                    } else {
                        regs.SetReg(0, @bitCast(u64, @intCast(i64, -2)));
                    }
                },
                .Stat => { // Status_t Stat(const char* path, stat_t* ptr)
                    const path = @intToPtr([*]const u8, regs.GetReg(1))[0..std.mem.len(@intToPtr([*c]const u8, regs.GetReg(1)))];
                    if (FS.GetInode(path, FS.rootInode.?)) |inode| {
                        @intToPtr(*FS.Metadata, regs.GetReg(2)).* = inode.stat;
                        regs.SetReg(0, 0);
                    } else {
                        regs.SetReg(0, @bitCast(u64, @intCast(i64, -2)));
                    }
                },
                .FStat => { // Status_t FStat(FileDesc_t fd, stat_t* ptr)
                    const team = HAL.Arch.GetHCB().activeThread.?.team;
                    if (team.fds.search(@bitCast(i64, regs.GetReg(1)))) |node| {
                        const inode: *FS.Inode = node.value.inode;
                        @intToPtr(*FS.Metadata, regs.GetReg(2)).* = inode.stat;
                        regs.SetReg(0, 0);
                    } else {
                        regs.SetReg(0, @bitCast(u64, @intCast(i64, -9)));
                    }
                },
                .IOCtl => { // long IOCtl(FileDesc_t fd, unsigned int request, void* arg)
                    const team = HAL.Arch.GetHCB().activeThread.?.team;
                    if (team.fds.search(@bitCast(i64, regs.GetReg(1)))) |node| {
                        const inode: *FS.Inode = node.value.inode;
                        if (inode.ioctl) |ioctl| {
                            const old = HAL.Arch.IRQEnableDisable(false);
                            @ptrCast(*Spinlock, &inode.lock).acquire();
                            regs.SetReg(0, @bitCast(u64, @intCast(i64, ioctl(inode, @intCast(usize, regs.GetReg(2)), @intToPtr(*allowzero void, regs.GetReg(3))))));
                            @ptrCast(*Spinlock, &inode.lock).release();
                            _ = HAL.Arch.IRQEnableDisable(old);
                        } else {
                            regs.SetReg(0, @bitCast(u64, @intCast(i64, -38)));
                        }
                    } else {
                        regs.SetReg(0, @bitCast(u64, @intCast(i64, -9)));
                    }
                },
                .MMap => { // void* MMap(void* addr, size_t length, int prot, int flags, int fd, off_t offset)
                    const addr = @intToPtr(*allowzero void, regs.GetReg(1));
                    const length = @intCast(usize, regs.GetReg(2));
                    const prot = regs.GetReg(3);
                    _ = prot;
                    const flags = regs.GetReg(4);
                    const fd = @bitCast(i64, regs.GetReg(5));
                    const offset = @bitCast(isize, @intCast(usize, regs.GetReg(6)));
                    if (flags & 0x8 != 0) { // Anonymous Mapping
                        regs.SetReg(0, @bitCast(u64, @intCast(i64, -38)));
                    } else {
                        const team = HAL.Arch.GetHCB().activeThread.?.team;
                        if (team.fds.search(fd)) |node| {
                            const inode: *FS.Inode = node.value.inode;
                            if (inode.map) |mmap| {
                                const old = HAL.Arch.IRQEnableDisable(false);
                                @ptrCast(*Spinlock, &inode.lock).acquire();
                                regs.SetReg(0, @bitCast(u64, @intCast(i64, mmap(
                                    inode,
                                    offset,
                                    addr,
                                    length,
                                ))));
                                @ptrCast(*Spinlock, &inode.lock).release();
                                _ = HAL.Arch.IRQEnableDisable(old);
                            } else {
                                regs.SetReg(0, @bitCast(u64, @intCast(i64, -38)));
                            }
                        } else {
                            regs.SetReg(0, @bitCast(u64, @intCast(i64, -9)));
                        }
                    }
                },
                .MUnMap => {
                    const addrSpace = HAL.Arch.GetHCB().activeThread.?.team.addressSpace;
                    var addr = @intCast(usize, regs.GetReg(1));
                    const length = @intCast(usize, regs.GetReg(2));
                    const addrStart = @intCast(usize, regs.GetReg(1));
                    const old = HAL.Arch.IRQEnableDisable(false);
                    while (addr < addrStart + length) : (addr += 4096) {
                        const pte: HAL.PTEEntry = Memory.Paging.GetPage(addrSpace, addr);
                        if (pte.r == 1) {
                            _ = Memory.Paging.MapPage(addrSpace, addr, 0, 0);
                            Memory.PFN.DereferencePage(@intCast(usize, pte.phys) << 12);
                        }
                    }
                    _ = HAL.Arch.IRQEnableDisable(old);
                    regs.SetReg(0, 0);
                },
                else => {
                    regs.SetReg(0, @bitCast(u64, @intCast(i64, -4096)));
                },
            }
        },
        .Process => {
            switch (@intToEnum(ProcessFuncs, func)) {
                .NewTeam => { // TeamID_t NewTeam(*const char name, TeamCreateFlags flags)

                },
                .Exit => { // !!noreturn Exit(int code)

                },
                else => {
                    regs.SetReg(0, @bitCast(u64, @intCast(i64, -4096)));
                },
            }
        },
        .Ryu => {
            switch (@intToEnum(RyuFuncs, func)) {
                .KernelLog => { // void KernelLog(*const char text)
                    var s: [*c]const u8 = @intToPtr([*c]const u8, regs.GetReg(1));
                    HAL.Console.Put("{s}", .{@ptrCast([*]const u8, s)[0..std.mem.len(s)]});
                    regs.SetReg(0, 0);
                },
            }
        },
        else => {
            regs.SetReg(0, @bitCast(u64, @intCast(i64, -4096)));
        },
    }
}

pub fn stub() void { // Doesn't do anything but helps to keep Zig from optimizing this file out

}
