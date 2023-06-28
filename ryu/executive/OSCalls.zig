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
    Stat = 8,
    FStat = 9,
    ChOwn = 10,
    FChOwn = 11,
    ChMod = 12,
    FChMod = 13,
    IOCtl = 14,
    MMap = 15,
    MUnMap = 16,
    ChDir = 17,
    Dup = 18, // functions like dup2
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
