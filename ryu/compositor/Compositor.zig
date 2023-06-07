const Spinlock = @import("root").Spinlock;
const Memory = @import("root").Memory;
const HAL = @import("root").HAL;
pub const Mouse = @import("Mouse.zig");

pub const WINFLAG_NOMOVE = 1;
pub const WINFLAG_RESIZE = 2;
pub const WINFLAG_OPAQUE = 4;

pub const Window = struct {
    prev: ?*Window = null,
    next: ?*Window = null,
    id: i64,
    x: isize,
    y: isize,
    w: usize,
    h: usize,
    flags: u8,
    buf: []u32,
    owner: i64, // Team ID
};

pub var windowHead: ?*Window = null;
pub var windowTail: ?*Window = null;
pub var cursorBuf: [13 * 21]u32 = [_]u32{0} ** (13 * 21);
pub var backgroundWin = Window{
    .id = 0,
    .x = 0,
    .y = 0,
    .w = 0,
    .h = 0,
    .flags = WINFLAG_NOMOVE | WINFLAG_OPAQUE,
    .buf = @ptrCast([*]u32, &cursorBuf)[0..(13 * 21)], // Temporary
    .owner = 0,
};
pub var cursorWin = Window{
    .id = 0,
    .x = 0,
    .y = 0,
    .w = 13,
    .h = 21,
    .flags = WINFLAG_NOMOVE,
    .buf = @ptrCast([*]u32, &cursorBuf)[0..(13 * 21)],
    .owner = 0,
};
pub var windowLock: Spinlock = .unaquired;
pub var nextWinID: i64 = 1;

pub fn BlendPixel(px1: u32, px2: u32) u32 {
    var m1: u32 = (px2 & 0xFF000000) >> 24;
    var m2: u32 = 255 - m1;
    var r2: u32 = m2 * (px1 & 0x00FF00FF);
    var g2: u32 = m2 * (px1 & 0x0000FF00);
    var r1: u32 = m1 * (px2 & 0x00FF00FF);
    var g1: u32 = m1 * (px2 & 0x0000FF00);
    var result: u32 = (0x0000FF00 & ((g1 + g2) >> 8)) | (0x00FF00FF & ((r1 + r2) >> 8));
    return result;
}

pub fn Redraw(x: isize, y: isize, w: usize, h: usize) void {
    windowLock.acquire();
    var maxX: isize = x + (@intCast(isize, w) - 1);
    var maxY: isize = y + (@intCast(isize, h));
    var win: ?*Window = &backgroundWin;
    while (win) |wi| {
        if (!(maxX <= wi.x or maxY <= wi.y or x >= (wi.x + (@intCast(isize, wi.w))) or y >= (wi.y + (@intCast(isize, wi.h))))) {
            var fX1 = @max(x, wi.x);
            var fX2 = @min(maxX, wi.x + (@intCast(isize, wi.w) - 1));
            var fY1 = @max(y, wi.y);
            var fY2 = @min(maxY, wi.y + (@intCast(isize, wi.h) - 1));
            var i = fY1;
            const pitch = HAL.Console.info.pitch;
            const bytes = HAL.Console.info.bpp / 8;
            while (i <= fY2) : (i += 1) {
                if (i < 0) {
                    continue;
                } else if (i >= HAL.Console.info.height) {
                    break;
                }
                var j = fX1;
                while (j <= fX2) : (j += 1) {
                    if (j < 0) {
                        continue;
                    } else if (j >= HAL.Console.info.width) {
                        break;
                    }
                    var pixel: u32 = @intToPtr(*u32, @ptrToInt(wi.buf.ptr) + @intCast(usize, (((i - wi.y) * @intCast(isize, wi.w)) + (j - wi.x)) * @intCast(isize, bytes))).*;
                    if ((pixel & 0xFF000000) == 0xFF000000 or (wi.flags & WINFLAG_OPAQUE) != 0) {
                        @intToPtr(*u32, @ptrToInt(HAL.Console.info.ptr) + (@intCast(usize, i) * pitch) + (@intCast(usize, j) * bytes)).* = (pixel & 0xFFFFFF);
                    } else if ((pixel & 0xFF000000) != 0) {
                        @intToPtr(*u32, @ptrToInt(HAL.Console.info.ptr) + (@intCast(usize, i) * pitch) + (@intCast(usize, j) * bytes)).* = BlendPixel(@intToPtr(*u32, @ptrToInt(backgroundWin.buf.ptr) + (@intCast(usize, i) * (backgroundWin.w * bytes)) + (@intCast(usize, j) * bytes)).*, pixel);
                    }
                }
            }
        }
        if (win == &backgroundWin) {
            if (windowHead == null) {
                win = &cursorWin;
            } else {
                win = windowHead;
            }
        } else if (win == windowTail) {
            win = &cursorWin;
        } else {
            win = wi.next;
        }
    }
    windowLock.release();
}

pub fn MoveWinToFront(win: *Window) void {
    windowLock.acquire();
    if (windowTail == win) {
        windowLock.release();
        return;
    }
    if (windowHead == win) {
        windowHead = win.next;
    }
    if (win.prev) |prev| {
        prev.next = win.next;
    }
    if (win.next) |next| {
        next.prev = win.prev;
    }
    windowTail.?.next = win;
    win.prev = windowTail;
    win.next = null;
    windowTail = win;
    windowLock.release();
}

pub fn Init() void {
    Mouse.InitMouseBitmap();
    const pixels = (HAL.Console.info.width * HAL.Console.info.height) * (HAL.Console.info.bpp / 8);
    backgroundWin.buf = @ptrCast([*]u32, @alignCast(4, Memory.Pool.PagedPool.AllocAnonPages(pixels).?.ptr))[0..(pixels / (HAL.Console.info.bpp / 8))];
    backgroundWin.w = HAL.Console.info.width;
    backgroundWin.h = HAL.Console.info.height;
    var i: usize = 0;
    while (i < HAL.Console.info.height) : (i += 1) {
        @memcpy(@intToPtr([*]u32, @ptrToInt(backgroundWin.buf.ptr) + (i * (HAL.Console.info.width * 4))), @intToPtr([*]u32, @ptrToInt(HAL.Console.info.ptr) + (i * HAL.Console.info.pitch))[0..HAL.Console.info.width]);
    }
    Redraw(0, 0, HAL.Console.info.width, HAL.Console.info.height);
}
