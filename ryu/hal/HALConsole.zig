const std = @import("std");

pub const FBInfo = struct {
    ptr: *allowzero void = @intToPtr(*allowzero void, 0),
    width: usize = 0,
    height: usize = 0,
    pitch: usize = 0,
    bpp: usize = 0,
    nativeColor: *const fn (self: *const FBInfo, c: u8) usize,
    set: *const fn (self: *const FBInfo, x: isize, y: isize, w: usize, h: usize, c: usize) void,
};

var info: *const FBInfo = undefined;
var cursorX: usize = 0;
var cursorY: usize = 0;

fn fbDrawBitmap(x: isize, y: isize, w: usize, h: usize, bitmap: []u8, color: usize) void {
    const bytes = (w / 8) + (if ((w % 8) != 0) 1 else 0);
    var i: usize = 0;
    while (i < h) : (i += 1) {
        var j: usize = 0;
        while (j < bytes) : (j += 1) {
            var b: u8 = bitmap[(i * bytes) + j];
            var c: usize = j * 8;
            while (b != 0) : (b <<= 1) {
                if ((b & 0x80) != 0) {
                    info.set(info, x + c, y + i, 1, 1, color);
                }
                c += 1;
            }
        }
    }
}

pub fn Init(i: *const FBInfo) void {
    info = i;
    cursorX = 0;
    cursorY = 0;
    info.set(info, 0, 0, info.width, info.height, info.nativeColor(info, 0));
}

fn newline() void {
    cursorX = 0;
    if (((cursorY + 1) * 16) >= info.height) {
        // Scroll
        var i: usize = 16;
        while (i < info.height) : (i += 1) {
            @memcpy(@intToPtr([*]u8, @ptrToInt(info.ptr) + ((i - 16) * info.pitch)), @intToPtr([*]const u8, @ptrToInt(info.ptr) + (i * info.pitch)), info.pitch);
        }
    } else {
        cursorY += 1;
    }
}

fn conWriteString(_: @TypeOf(.{}), string: []const u8) error{}!usize {
    for (string) |c| {
        info.set(info, @intCast(isize, cursorX * 8), @intCast(isize, cursorY * 16), 8, 16, info.nativeColor(info, 0));
        //fbDrawBitmap(@intCast(i32, cursorX * 8), @intCast(i32, cursorY * 16), 8, 16, 0, 0);
        if (c == '\n') {
            newline();
        } else {
            cursorX += 1;
            if ((cursorX * 8) >= info.width) {
                newline();
            }
        }
        info.set(info, @intCast(isize, cursorX * 8), @intCast(isize, cursorY * 16), 8, 16, info.nativeColor(info, 255));
    }
    return string.len;
}

const Writer = std.io.Writer(@TypeOf(.{}), error{}, conWriteString);
const writer = Writer{ .context = .{} };

pub fn Put(comptime format: []const u8, args: anytype) void {
    try writer.print(format, args);
}

pub fn EnableDisable(en: bool) void {
    _ = en;
}
