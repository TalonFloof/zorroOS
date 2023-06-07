const Compositor = @import("root").Compositor;
const HAL = @import("root").HAL;

const MouseBitmap = [_]u8{
    0xff, 0xff, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01,
    0xff, 0x66, 0xff, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01,
    0xff, 0x00, 0x66, 0xff, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01,
    0xff, 0x00, 0x00, 0x77, 0xff, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01,
    0xff, 0x00, 0x22, 0x11, 0x88, 0xff, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01,
    0xff, 0x00, 0x33, 0x22, 0x11, 0x99, 0xee, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01,
    0xff, 0x11, 0x33, 0x33, 0x22, 0x11, 0xaa, 0xee, 0x01, 0x01, 0x01, 0x01, 0x01,
    0xff, 0x11, 0x22, 0x22, 0x33, 0x22, 0x11, 0xaa, 0xee, 0x01, 0x01, 0x01, 0x01,
    0xee, 0x11, 0x22, 0x22, 0x22, 0x22, 0x22, 0x11, 0xbb, 0xee, 0x01, 0x01, 0x01,
    0xee, 0x11, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0xcc, 0xee, 0x01, 0x01,
    0xee, 0x11, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0xcc, 0xee, 0x01,
    0xee, 0x11, 0x22, 0x11, 0x11, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0xdd, 0xee,
    0xee, 0x11, 0x11, 0x11, 0x11, 0x11, 0x22, 0x22, 0x22, 0x33, 0x22, 0x33, 0xff,
    0xee, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x22, 0x22, 0x22, 0x22, 0xbb, 0xee,
    0xee, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x22, 0x22, 0x22, 0x88, 0xff, 0x01,
    0xee, 0x11, 0x11, 0x11, 0x00, 0x11, 0x11, 0x11, 0x22, 0x55, 0xff, 0x01, 0x01,
    0xdd, 0x11, 0x11, 0x00, 0x00, 0x00, 0x11, 0x11, 0x11, 0xaa, 0xee, 0x01, 0x01,
    0xee, 0xee, 0xcc, 0xaa, 0x88, 0x11, 0x11, 0x11, 0x11, 0xcc, 0xee, 0x01, 0x01,
    0x01, 0xee, 0xee, 0xee, 0xee, 0xee, 0x33, 0x11, 0x11, 0xee, 0x01, 0x01, 0x01,
    0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0xff, 0x66, 0x77, 0xff, 0x01, 0x01, 0x01,
    0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0xee, 0xee, 0x01, 0x01, 0x01, 0x01,
};

pub fn InitMouseBitmap() void {
    var i: usize = 0;
    while (i < MouseBitmap.len) : (i += 1) {
        if (MouseBitmap[i] == 1) {
            Compositor.cursorBuf[i] = 0;
        } else {
            const val = @intCast(u32, MouseBitmap[i]);
            Compositor.cursorBuf[i] = 0xff000000 | (val << 16) | (val << 8) | val;
        }
    }
}

var lButton: bool = false;
var winX: isize = 0;
var winY: isize = 0;
var winDrag: ?*Compositor.Window = null;

fn invertPixel(x: isize, y: isize) void {
    if (x >= 0 and x < HAL.Console.info.width and y >= 0 and y < HAL.Console.info.height) {
        const ptr: *u32 = @intToPtr(*u32, @ptrToInt(HAL.Console.info.ptr) + (@intCast(usize, y) * HAL.Console.info.pitch) + (@intCast(usize, x) * (HAL.Console.info.bpp / 8)));
        ptr.* = (~(ptr.*)) & 0xFFFFFF;
    }
}

fn renderInvertOutline(x: isize, y: isize, w: usize, h: usize) void {
    var i: isize = 0;
    while (i < w) : (i += 1) {
        if (i == 0 or i == w - 1) {
            var j: isize = 0;
            while (j < h) : (j += 1) {
                invertPixel(x + i, y + j);
            }
        } else {
            invertPixel(x + i, y);
            invertPixel(x + i, y + (@intCast(isize, w) - 1));
        }
    }
}

pub fn ProcessMouseUpdate(relX: isize, relY: isize, relZ: isize, buttons: u8) callconv(.C) void {
    _ = relZ;
    if (relX != 0 or relY != 0) {
        const oldX = Compositor.cursorWin.x;
        const oldY = Compositor.cursorWin.y;
        Compositor.cursorWin.x += relX;
        Compositor.cursorWin.y += relY;
        if (Compositor.cursorWin.x < 0) {
            Compositor.cursorWin.x = 0;
        } else if (Compositor.cursorWin.x >= @intCast(isize, HAL.Console.info.width)) {
            Compositor.cursorWin.x = @intCast(isize, HAL.Console.info.width) - 1;
        }
        if (Compositor.cursorWin.y < 0) {
            Compositor.cursorWin.y = 0;
        } else if (Compositor.cursorWin.y >= @intCast(isize, HAL.Console.info.height)) {
            Compositor.cursorWin.y = @intCast(isize, HAL.Console.info.height) - 1;
        }
        Compositor.Redraw(oldX, oldY, Compositor.cursorWin.w, Compositor.cursorWin.h);
        Compositor.Redraw(Compositor.cursorWin.x, Compositor.cursorWin.y, Compositor.cursorWin.w, Compositor.cursorWin.h);
        if (winDrag) |win| {
            renderInvertOutline(oldX - winX, oldY - winY, win.w, win.h);
            renderInvertOutline(Compositor.cursorWin.x - winX, Compositor.cursorWin.y - winY, win.w, win.h);
        }
    }
    if ((buttons & 1) == 0 and lButton and winDrag != null) {
        Compositor.windowLock.acquire();
        const oldX = winDrag.?.x;
        const oldY = winDrag.?.y;
        winDrag.?.x = Compositor.cursorWin.x - winX;
        winDrag.?.y = Compositor.cursorWin.y - winY;
        Compositor.windowLock.release();
        Compositor.MoveWinToFront(winDrag.?);
        Compositor.Redraw(oldX, oldY, winDrag.?.w, winDrag.?.h);
        Compositor.Redraw(winDrag.?.x, winDrag.?.y, winDrag.?.w, winDrag.?.h);
        winDrag = null;
    } else if ((buttons & 1) != 0 and !lButton) {
        Compositor.windowLock.acquire();
        var win = Compositor.windowTail;
        while (win) |wi| {
            if (Compositor.cursorWin.x >= wi.x and Compositor.cursorWin.x < wi.x + @intCast(isize, wi.w) and Compositor.cursorWin.y >= wi.y and Compositor.cursorWin.y < wi.y + 20 and (wi.flags & Compositor.WINFLAG_NOMOVE) == 0) {
                winDrag = wi;
                winX = Compositor.cursorWin.x - wi.x;
                winY = Compositor.cursorWin.y - wi.y;
                renderInvertOutline(Compositor.cursorWin.x - winX, Compositor.cursorWin.y - winY, wi.w, wi.h);
                break;
            } else if (Compositor.cursorWin.x >= wi.x and Compositor.cursorWin.x < wi.x + @intCast(isize, wi.w) and Compositor.cursorWin.y >= wi.y + 20 and Compositor.cursorWin.y < wi.y + @intCast(isize, wi.h)) {
                // Mouse Click Event
                break;
            }
            win = wi.prev;
        }
        Compositor.windowLock.release();
    }
    lButton = (buttons & 1) != 0;
}
