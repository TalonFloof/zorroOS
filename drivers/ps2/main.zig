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
            if (devlib.io.inb(0x64) & 1 != 0) return;
            std.atomic.spinLoopHint();
        }
    } else {
        while (true) {
            if (devlib.io.inb(0x64) & 2 == 0) return;
            std.atomic.spinLoopHint();
        }
    }
}

fn PS2MouseRead() u8 {
    PS2MouseWait(0);
    return devlib.io.inb(0x60);
}

fn PS2MouseWrite(write: u8) void {
    PS2MouseWait(1);
    devlib.io.outb(0x64, 0xd4);
    PS2MouseWait(1);
    devlib.io.outb(0x60, write);
}

pub fn PS2IRQ() callconv(.C) void {
    var status: u8 = 0;
    while (true) {
        status = devlib.io.inb(0x64);
        if (status & 1 == 0) {
            break;
        }
        if ((status & 0x20) != 0) {
            packetData[packetID] = devlib.io.inb(0x60);
            if (packetID == 2) {
                var flags: u8 = packetData[0];
                var relX: isize = @intCast(isize, packetData[1]) - @intCast(isize, (@intCast(u16, flags) << 4) & 0x100);
                var relY: isize = 0 - (@intCast(isize, packetData[2]) - @intCast(isize, (@intCast(u16, flags) << 3) & 0x100));
                DriverInfo.krnlDispatch.?.updateMouse(relX, relY, 0, 0);
            }
            if (packetID == 0 and (packetData[packetID] & 0x8) == 0) {
                packetID = 0;
            } else {
                packetID = (packetID + 1) % 3;
            }
        } else {
            // This is for the Keyboard not the Mouse...
            _ = devlib.io.inb(0x60);
        }
    }
}

pub fn LoadDriver() callconv(.C) devlib.Status {
    if (DriverInfo.krnlDispatch) |dispatch| {
        const old = dispatch.enableDisableIRQ(false);
        dispatch.put("PS/2 Driver for zorroOS (C) 2023 TalonFox\n");
        if (dispatch.attachDetatchIRQ(1, &PS2IRQ) != 1) {
            dispatch.abort("Failed to attach IRQ1 for PS/2 Keyboard!");
        }
        if (dispatch.attachDetatchIRQ(12, &PS2IRQ) != 12) {
            dispatch.abort("Failed to attach IRQ12 for PS/2 Mouse!");
        }
        // Initialize PS/2 Mouse
        while (devlib.io.inb(0x64) & 1 != 0)
            _ = devlib.io.inb(0x60);
        PS2MouseWait(1);
        devlib.io.outb(0x64, 0xa8);
        PS2MouseWait(1);
        devlib.io.outb(0x64, 0x20);
        const status: u8 = (devlib.io.inb(0x60) | 2) & (~@intCast(u8, 0x10));
        PS2MouseWait(1);
        devlib.io.outb(0x64, 0x60);
        PS2MouseWait(1);
        devlib.io.outb(0x64, status);

        PS2MouseWrite(0xf6);

        PS2MouseWrite(0xf4);
        _ = dispatch.enableDisableIRQ(old);
        return .Okay;
    }
    return .Failure;
}

pub fn UnloadDriver() callconv(.C) devlib.Status {
    return .Okay;
}
