const devlib = @import("devlib");
const std = @import("std");

pub export var DriverInfo = devlib.RyuDriverInfo{
    .apiMinor = 1,
    .apiMajor = 0,
    .drvName = "PS2Driver",
    .loadFn = &LoadDriver,
    .unloadFn = &UnloadDriver,
};

var packetID: usize = 0;
var packetData: [3]u8 = .{ 0, 0, 0 };

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
    _ = devlib.io.inb(0x60);
}

pub fn PS2MouseIRQ() callconv(.C) void {
    packetData[packetID] = devlib.io.inb(0x60);
    if (packetID == 2) {
        var flags: u8 = packetData[0];
        var relX: isize = @intCast(isize, packetData[1]) - @intCast(isize, (@intCast(u16, flags) << 4) & 0x100);
        var relY: isize = 0 - (@intCast(isize, packetData[2]) - @intCast(isize, (@intCast(u16, flags) << 3) & 0x100));
        DriverInfo.krnlDispatch.?.updateMouse(relX, relY, 0, flags & 7);
    }
    if (packetID == 0 and (packetData[packetID] & 0x8) == 0) {
        packetID = 0;
    } else {
        packetID = (packetID + 1) % 3;
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
