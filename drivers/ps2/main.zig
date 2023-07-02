const devlib = @import("devlib");
const std = @import("std");

pub export var DriverInfo = devlib.RyuDriverInfo{
    .apiMinor = 1,
    .apiMajor = 0,
    .drvName = "PS2Driver",
    .exportedDispatch = null,
    .loadFn = &LoadDriver,
    .unloadFn = &UnloadDriver,
};

var packetID: usize = 0;
var packetData: [3]u8 = .{ 0, 0, 0 };

var kbdBuffer: [64]u8 = [_]u8{0} ** 64;
var kbdRead: usize = 0;
var kbdWrite: usize = 0;
var kbdEventQueue: devlib.EventQueue = devlib.EventQueue{};

var mouseBuffer: [64]u8 = [_]u8{0} ** 64;
var mouseRead: usize = 0;
var mouseWrite: usize = 0;
var mouseEventQueue: devlib.EventQueue = devlib.EventQueue{};

fn PS2MouseWait(typ: usize) void {
    if (typ == 0) {
        while (true) {
            if (devlib.io.inb(0x64) & 0x1 != 0) return;
            std.atomic.spinLoopHint();
        }
    } else if (typ == 1) {
        while (true) {
            if (devlib.io.inb(0x64) & 2 == 0) return;
            std.atomic.spinLoopHint();
        }
    } else if (typ == 2) {
        while (true) {
            if (devlib.io.inb(0x64) & 0x21 == 0x20) return;
            std.atomic.spinLoopHint();
        }
    }
}

fn PS2Read(isMouse: bool) u8 {
    PS2MouseWait(if (isMouse) 2 else 0);
    return devlib.io.inb(0x60);
}

fn PS2KbdWrite(write: u8) u8 {
    PS2MouseWait(1);
    devlib.io.outb(0x60, write);
    PS2MouseWait(0);
    return devlib.io.inb(0x60);
}

fn PS2MouseWrite(write: u8, specialRead: bool) u8 {
    var r: u8 = 0xfe;
    var tries: usize = 3;
    while (r == 0xfe and tries > 0) {
        tries -= 1;
        PS2MouseWait(1);
        devlib.io.outb(0x64, 0xd4);
        PS2MouseWait(1);
        devlib.io.outb(0x60, write);
        PS2MouseWait(if (specialRead) 2 else 0);
        r = devlib.io.inb(0x60);
    }
    if (tries == 0) {
        DriverInfo.krnlDispatch.?.put("WARNING: PS/2 Mouse Command Failed due to too many retries!\n");
        return 0;
    }
    return r;
}

pub fn PS2KbdIRQ() callconv(.C) void {
    while (devlib.io.inb(0x64) & 1 == 0)
        return;
    const data = devlib.io.inb(0x60);
    kbdBuffer[kbdWrite] = data;
    kbdWrite = (kbdWrite + 1) % 64;
    if (kbdEventQueue.threadHead != null) {
        DriverInfo.krnlDispatch.?.wakeupEvent(&kbdEventQueue, 0);
    }
}

pub fn PS2MouseIRQ() callconv(.C) void {
    packetData[packetID] = devlib.io.inb(0x60);
    if (packetID == 2) {
        mouseBuffer[mouseWrite] = packetData[0];
        mouseBuffer[(mouseWrite + 1) % 64] = packetData[1];
        mouseBuffer[(mouseWrite + 2) % 64] = packetData[2];
        mouseWrite = (mouseWrite + 3) % 64;
        if (mouseEventQueue.threadHead != null) {
            DriverInfo.krnlDispatch.?.wakeupEvent(&mouseEventQueue, 0);
        }
    }
    if (packetID == 0 and (packetData[packetID] & 0x8) == 0) {
        packetID = 0;
    } else {
        packetID = (packetID + 1) % 3;
    }
}

var PS2KbdInode: devlib.fs.Inode = devlib.fs.Inode{
    .stat = devlib.fs.Metadata{ .ID = 0, .mode = 0o0020660 },
    .read = &PS2DevRead,
};

var PS2MouseInode: devlib.fs.Inode = devlib.fs.Inode{
    .stat = devlib.fs.Metadata{ .ID = 0, .mode = 0o0020660 },
    .read = &PS2DevRead,
};

pub fn PS2DevRead(inode: *devlib.fs.Inode, offset: isize, addr: *void, len: isize) callconv(.C) isize {
    _ = offset;
    if (@intFromPtr(inode) == @intFromPtr(&PS2MouseInode)) {
        // PS/2 Mouse
        if (len != 3) {
            return -16;
        }
        while (mouseWrite == mouseRead) {
            DriverInfo.krnlDispatch.?.releaseSpinlock(&inode.lock);
            _ = DriverInfo.krnlDispatch.?.waitEvent(&mouseEventQueue);
            DriverInfo.krnlDispatch.?.acquireSpinlock(&inode.lock);
        }
        const buf = @as([*]u8, @ptrFromInt(@intFromPtr(addr)))[0..3];
        buf[0] = mouseBuffer[mouseRead];
        buf[1] = mouseBuffer[(mouseRead + 1) % 64];
        buf[2] = mouseBuffer[(mouseRead + 2) % 64];
        mouseRead = (mouseRead + 3) % 64;
        return 3;
    } else {
        // PS/2 Keyboard
        if (len != 1) {
            return -16;
        }
        while (kbdWrite == kbdRead) {
            DriverInfo.krnlDispatch.?.releaseSpinlock(&inode.lock);
            _ = DriverInfo.krnlDispatch.?.waitEvent(&kbdEventQueue);
            DriverInfo.krnlDispatch.?.acquireSpinlock(&inode.lock);
        }
        const buf = @as(*u8, @ptrFromInt(@intFromPtr(addr)));
        buf.* = kbdBuffer[kbdRead];
        kbdRead = (kbdRead + 1) % 64;
        return 1;
    }
}

pub fn LoadDriver() callconv(.C) devlib.Status {
    if (DriverInfo.krnlDispatch) |dispatch| {
        dispatch.put("PS/2 Driver for zorroOS (C) 2023 TalonFox\n");
        // Disable Ports 1 and 2
        PS2MouseWait(1);
        devlib.io.outb(0x64, 0xad);
        PS2MouseWait(1);
        devlib.io.outb(0x64, 0xa7);
        // Flush FIFO Queue
        while (devlib.io.inb(0x64) & 1 != 0)
            _ = devlib.io.inb(0x60);
        // Get and set the Status Byte
        PS2MouseWait(1);
        devlib.io.outb(0x64, 0x20);
        PS2MouseWait(0);
        const status: u8 = devlib.io.inb(0x60);

        PS2MouseWait(1);
        devlib.io.outb(0x64, 0x60);
        PS2MouseWait(1);
        devlib.io.outb(0x60, (status & 0x8F) | 3);

        // Reenable Ports 1 and 2
        PS2MouseWait(1);
        devlib.io.outb(0x64, 0xae);
        PS2MouseWait(1);
        devlib.io.outb(0x64, 0xa8);
        while (devlib.io.inb(0x64) & 1 != 0)
            _ = devlib.io.inb(0x60);

        _ = PS2KbdWrite(0xf0);
        _ = PS2KbdWrite(1);
        var val = PS2MouseWrite(0xf6, false);
        if (val != 0xfa) {
            dispatch.put("WARNING: Abnormal response from PS/2 Mouse command 0xf6!\n");
        }
        val = PS2MouseWrite(0xf4, false);
        if (val != 0xfa) {
            dispatch.put("WARNING: Abnormal response from PS/2 Mouse command 0xf4!\n");
        }

        _ = PS2MouseWrite(0xE6, false);
        _ = PS2MouseWrite(0xE8, false);
        _ = PS2MouseWrite(3, false);

        if (dispatch.attachDetatchIRQ(1, &PS2KbdIRQ) != 1) {
            dispatch.abort("Failed to attach IRQ1 for PS/2 Keyboard!");
        }
        if (dispatch.attachDetatchIRQ(12, &PS2MouseIRQ) != 12) {
            dispatch.abort("Failed to attach IRQ12 for PS/2 Mouse!");
        }
        dispatch.registerDevice("ps2kbd", &PS2KbdInode);
        dispatch.registerDevice("ps2mouse", &PS2MouseInode);
        return .Okay;
    }
    return .Failure;
}

pub fn UnloadDriver() callconv(.C) devlib.Status {
    return .Okay;
}

pub fn panic(msg: []const u8, stacktrace: ?*std.builtin.StackTrace, wat: ?usize) noreturn {
    _ = wat;
    _ = stacktrace;
    DriverInfo.krnlDispatch.?.abort(msg);
}
