const Compositor = @import("root").Compositor;

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