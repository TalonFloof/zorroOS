const std = @import("std");
const FS = @import("root").FS;
const AATree = @import("root").AATree;
const Spinlock = @import("root").Spinlock;
const Memory = @import("root").Memory;
const HAL = @import("root").HAL;
const Executive = @import("root").Executive;

const Session = struct {
    stcBuf: []u8,
    stcRead: usize = 0, // Client
    stcWrite: usize = 0, // Server
    queueWrite: Executive.EventQueue = Executive.EventQueue{},
    queueRead: Executive.EventQueue = Executive.EventQueue{},
};

const SessionTree = AATree(i64, *Session);

const MQData = struct {
    ownerID: i64,
    ctsBuf: []u8,
    ctsRead: usize = 0, // Server
    ctsWrite: usize = 0, // Client
    tree: SessionTree,
    queueWrite: Executive.EventQueue = Executive.EventQueue{},
    queueRead: Executive.EventQueue = Executive.EventQueue{},
    serverPoll: bool = false,
};

const CTSPacket = extern struct {
    source: i64,
    size: u64,
};

var mesgFSRoot: FS.Inode = FS.Inode{
    .stat = FS.Metadata{
        .mode = 0o0040777,
    },
    .create = &Create,
};

var nextInodeID: i64 = 1;

fn ClientSpaceLeft(session: *Session) usize {
    if (session.stcRead == session.stcWrite) {
        return 4096;
    }
    if (session.stcRead > session.stcWrite) {
        return 4096 - ((4096 - session.stcRead) + session.stcWrite);
    } else {
        return 4096 - (session.stcWrite - session.stcRead);
    }
}

fn ServerSpaceLeft(mq: *MQData) usize {
    if (mq.ctsRead == mq.ctsWrite) {
        return 4096;
    }
    if (mq.ctsRead > mq.ctsWrite) {
        return (4096 - mq.ctsRead) + mq.ctsWrite;
    } else {
        return mq.ctsWrite - mq.ctsRead;
    }
}

fn ReadClientQueue(session: *Session, buf: []u8) void {
    var i: usize = 0;
    while (i < buf.len) : (i += 1) {
        buf[i] = session.stcBuf[session.stcRead];
        session.stcRead = (session.stcRead + 1) % 4096;
    }
}

fn ReadServerQueue(mq: *MQData, buf: []u8) void {
    var i: usize = 0;
    while (i < buf.len) : (i += 1) {
        buf[i] = mq.ctsBuf[mq.ctsRead];
        mq.ctsRead = (mq.ctsRead + 1) % 4096;
    }
}

fn WriteClientQueue(mq: *Session, buf: []u8) void {
    var i: usize = 0;
    while (i < buf.len) : (i += 1) {
        mq.stcBuf[mq.stcWrite] = buf[i];
        mq.stcWrite = (mq.stcWrite + 1) % 4096;
    }
}

fn WriteServerQueue(mq: *MQData, buf: []u8) void {
    var i: usize = 0;
    while (i < buf.len) : (i += 1) {
        mq.ctsBuf[mq.ctsWrite] = buf[i];
        mq.ctsWrite = (mq.ctsWrite + 1) % 4096;
    }
}

fn Open(inode: *FS.Inode, mode: usize) callconv(.C) isize {
    _ = mode;
    const mqData: *MQData = @alignCast(@ptrCast(inode.private));
    const team: *Executive.Team.Team = HAL.Arch.GetHCB().activeThread.?.team;
    if (team.teamID != mqData.ownerID) {
        var session: *Session = @as(*Session, @ptrCast(@alignCast(Memory.Pool.PagedPool.Alloc(@sizeOf(Session)).?.ptr)));
        session.stcBuf = Memory.Pool.PagedPool.AllocAnonPages(4096).?;
        mqData.tree.insert(team.teamID, session);
    }
    return 0;
}

fn Close(inode: *FS.Inode) callconv(.C) void {
    const mqData: *MQData = @alignCast(@ptrCast(inode.private));
    const team: *Executive.Team.Team = HAL.Arch.GetHCB().activeThread.?.team;
    if (team.teamID != mqData.ownerID) {
        var session: *Session = mqData.tree.search(team.teamID).?;
        Memory.Pool.PagedPool.FreeAnonPages(session.stcBuf);
        mqData.tree.delete(team.teamID);
        Memory.Pool.PagedPool.Free(@as([*]u8, @ptrCast(@alignCast(session)))[0..@sizeOf(Session)]);
    }
}

fn Read(inode: *FS.Inode, offset: isize, bufBegin: *void, bufSize: isize) callconv(.C) isize {
    _ = offset;
    const buf: []u8 = @as([*]u8, @alignCast(@ptrCast(bufBegin)))[0..@as(usize, @intCast(bufSize))];
    const mqData: *MQData = @alignCast(@ptrCast(inode.private));
    const team: *Executive.Team.Team = HAL.Arch.GetHCB().activeThread.?.team;
    if (team.teamID == mqData.ownerID) {
        while (mqData.ctsRead == mqData.ctsWrite) {
            @as(*Spinlock, @ptrCast(&inode.lock)).release();
            _ = mqData.queueRead.Wait();
            @as(*Spinlock, @ptrCast(&inode.lock)).acquire();
        }
        var temp: [16]u8 = [_]u8{0} ** 16;
        ReadServerQueue(mqData, temp[0..@sizeOf(CTSPacket)]);
        const header = @as(*CTSPacket, @alignCast(@ptrCast(&temp)));
        @as(*i64, @ptrCast(@alignCast(buf.ptr))).* = header.source;
        ReadServerQueue(mqData, buf[@sizeOf(i64)..(@sizeOf(i64) + header.size)]);
        mqData.queueWrite.Wakeup(0);
        return @as(isize, @intCast(@sizeOf(i64) + header.size));
    } else {
        const session: *Session = mqData.tree.search(team.teamID).?;
        while (session.stcRead == session.stcWrite) {
            @as(*Spinlock, @ptrCast(&inode.lock)).release();
            _ = session.queueRead.Wait();
            @as(*Spinlock, @ptrCast(&inode.lock)).acquire();
        }
        var temp: [8]u8 = [_]u8{0} ** 8;
        ReadClientQueue(session, temp[0..@sizeOf(u64)]);
        const header = @as(*u64, @alignCast(@ptrCast(&temp)));
        ReadClientQueue(session, buf[0..(@as(usize, @intCast(header.*)))]);
        session.queueWrite.Wakeup(0);
        return @as(isize, @intCast(@as(usize, @intCast(header.*))));
    }
}

fn Write(inode: *FS.Inode, offset: isize, bufBegin: *void, bufSize: isize) callconv(.C) isize {
    _ = offset;
    const buf: []u8 = @as([*]u8, @alignCast(@ptrCast(bufBegin)))[0..@as(usize, @intCast(bufSize))];
    const mqData: *MQData = @alignCast(@ptrCast(inode.private));
    const team: *Executive.Team.Team = HAL.Arch.GetHCB().activeThread.?.team;
    if (team.teamID == mqData.ownerID) {
        const session: *Session = mqData.tree.search(@as(*i64, @alignCast(@ptrCast(buf.ptr))).*).?;
        while (ClientSpaceLeft(session) < (@as(usize, @intCast(bufSize - 8)) + @sizeOf(u64))) {
            @as(*Spinlock, @ptrCast(&inode.lock)).release();
            _ = session.queueWrite.Wait();
            @as(*Spinlock, @ptrCast(&inode.lock)).acquire();
        }
        var header: u64 = @intCast(bufSize - 8);
        const shouldWakeup: bool = session.stcRead == session.stcWrite;
        WriteClientQueue(session, @as([*]u8, @alignCast(@ptrCast(&header)))[0..@sizeOf(u64)]);
        WriteClientQueue(session, buf[8..]);
        if (shouldWakeup) {
            session.queueRead.Wakeup(0);
        }
        return bufSize;
    } else {
        while (ServerSpaceLeft(mqData) < (@as(usize, @intCast(bufSize)) + @sizeOf(CTSPacket))) {
            @as(*Spinlock, @ptrCast(&inode.lock)).release();
            _ = mqData.queueWrite.Wait();
            @as(*Spinlock, @ptrCast(&inode.lock)).acquire();
        }
        var header = CTSPacket{
            .source = team.teamID,
            .size = @as(u64, @intCast(bufSize)),
        };
        const shouldWakeup: bool = mqData.ctsRead == mqData.ctsWrite;
        WriteServerQueue(mqData, @as([*]u8, @alignCast(@ptrCast(&header)))[0..@sizeOf(CTSPacket)]);
        WriteServerQueue(mqData, buf);
        if (shouldWakeup) {
            mqData.queueRead.Wakeup(0);
        }
        return bufSize;
    }
}

fn IOCtl(inode: *FS.Inode, request: usize, data: *allowzero void) callconv(.C) isize {
    _ = data;
    const mqData: *MQData = @alignCast(@ptrCast(inode.private));
    const team: *Executive.Team.Team = HAL.Arch.GetHCB().activeThread.?.team;
    if (request == 1) {
        if (team.teamID == mqData.ownerID) {
            mqData.serverPoll = false;
            return 0;
        }
        return 1;
    } else if (request == 2) {
        if (team.teamID == mqData.ownerID) {
            mqData.serverPoll = true;
            return 0;
        }
        return 1;
    }
    return 2;
}

pub fn Create(inode: *FS.Inode, name: [*c]const u8, mode: usize) callconv(.C) isize {
    _ = mode;
    const id = @atomicRmw(i64, &nextInodeID, .Add, 1, .Monotonic);
    const len: usize = std.mem.len(name);
    var in: *FS.Inode = @as(*FS.Inode, @ptrCast(@alignCast(Memory.Pool.PagedPool.Alloc(@sizeOf(FS.Inode)).?.ptr)));
    @memset(@as([*]u8, @ptrCast(&in.name))[0..256], 0);
    @memcpy(@as([*]u8, @ptrCast(&in.name))[0..len], name[0..len]);
    in.hasReadEntries = true;
    in.stat.ID = id;
    in.stat.nlinks = 1;
    in.stat.uid = 1;
    in.stat.gid = 1;
    in.stat.mode = 0o0020666;
    in.stat.size = 0;
    const time: [2]i64 = HAL.Arch.GetCurrentTimestamp();
    in.stat.ctime = time[0];
    in.stat.reserved1 = @bitCast(time[1]);
    in.stat.mtime = time[0];
    in.stat.reserved2 = @bitCast(time[1]);
    in.stat.atime = time[0];
    in.stat.reserved3 = @bitCast(time[1]);
    in.mountOwner = inode.mountOwner;
    in.parent = inode;
    in.lock = 0;
    in.open = &Open;
    in.close = &Close;
    in.read = &Read;
    in.write = &Write;
    in.ioctl = &IOCtl;
    var mq: *MQData = @as(*MQData, @ptrCast(@alignCast(Memory.Pool.PagedPool.Alloc(@sizeOf(MQData)).?.ptr)));
    mq.ctsBuf = Memory.Pool.PagedPool.AllocAnonPages(4096).?;
    mq.ownerID = HAL.Arch.GetHCB().activeThread.?.team.teamID;
    in.private = @as(*allowzero void, @ptrCast(mq));
    FS.AddInodeToParent(in);
    return 0;
}

pub fn Init() void {
    FS.DevFS.RegisterDevice("mqueue", &mesgFSRoot);
}
