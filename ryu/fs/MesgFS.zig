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
    queue: Executive.EventQueue = Executive.EventQueue{},
};

const SessionTree = AATree(i64, *Session);

const MQData = struct {
    ownerID: i64,
    ctsBuf: []u8,
    ctsRead: usize = 0, // Server
    ctsWrite: usize = 0, // Client
    tree: SessionTree,
    queue: Executive.EventQueue = Executive.EventQueue{},
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
        return 0;
    }
    if (session.stcRead > session.stcWrite) {
        return (4096 - session.stcRead) + session.stcWrite;
    } else {
        return session.stcWrite - session.stcRead;
    }
}

fn ServerSpaceLeft(mq: *MQData) usize {
    if (mq.ctsRead == mq.ctsWrite) {
        return 0;
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
        session.stcBuf[session.stcRead] = buf[i];
        session.stcRead = (session.stcRead + 1) % 4096;
    }
}

fn ReadServerQueue(mq: *MQData, buf: []u8) void {
    var i: usize = 0;
    while (i < buf.len) : (i += 1) {
        mq.ctsBuf[mq.ctsRead] = buf[i];
        mq.ctsRead = (mq.ctsRead + 1) % 4096;
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
            _ = mqData.queue.Wait();
            @as(*Spinlock, @ptrCast(&inode.lock)).acquire();
        }
        ReadServerQueue(mqData, buf[0..@sizeOf(CTSPacket)]);
        const header = @as(*CTSPacket, @alignCast(@ptrCast(buf.ptr)));
        ReadServerQueue(mqData, buf[@sizeOf(CTSPacket)..(@sizeOf(CTSPacket) + header.size)]);
        return @as(isize, @intCast(@sizeOf(CTSPacket) + header.size));
    } else {
        const session: *Session = mqData.tree.search(team.teamID).?;
        while (session.stcRead == session.stcWrite) {
            @as(*Spinlock, @ptrCast(&inode.lock)).release();
            _ = session.queue.Wait();
            @as(*Spinlock, @ptrCast(&inode.lock)).acquire();
        }
        ReadClientQueue(session, buf[0..@sizeOf(u64)]);
        const header = @as(*u64, @alignCast(@ptrCast(buf.ptr)));
        ReadClientQueue(session, buf[@sizeOf(u64)..(@sizeOf(u64) + @as(usize, @intCast(header.*)))]);
        return @as(isize, @intCast(@sizeOf(u64) + @as(usize, @intCast(header.*))));
    }
}

fn Write(inode: *FS.Inode, offset: isize, bufBegin: *void, bufSize: isize) callconv(.C) isize {
    _ = bufSize;
    _ = bufBegin;
    _ = offset;
    const mqData: *MQData = @alignCast(@ptrCast(inode.private));
    _ = mqData;
    return 0;
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
    in.mountOwner = inode.mountOwner;
    in.parent = inode;
    in.lock = 0;
    in.open = &Open;
    in.close = &Close;
    in.read = &Read;
    in.write = &Write;
    var mq: *MQData = @as(*MQData, @ptrCast(@alignCast(Memory.Pool.PagedPool.Alloc(@sizeOf(MQData)).?.ptr)));
    mq.ctsBuf = Memory.Pool.PagedPool.AllocAnonPages(4096).?;
    in.private = @as(*allowzero void, @ptrCast(mq));
    FS.AddInodeToParent(in);
    return 0;
}

pub fn Init() void {
    FS.DevFS.RegisterDevice("mqueue", &mesgFSRoot);
}
