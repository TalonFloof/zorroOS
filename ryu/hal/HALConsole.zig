const std = @import("std");
const HaikuFont = @import("HALConsoleFont.zig").HaikuFont;
const LargeFont = @import("HALConsoleFont.zig").LargeFont;
const KernelSettings = @import("root").KernelSettings;
const Memory = @import("root").Memory;

pub const FBInfo = struct {
    ptr: *allowzero void = @intToPtr(*allowzero void, 0),
    width: usize = 0,
    height: usize = 0,
    pitch: usize = 0,
    bpp: usize = 0,
    set: *const fn (self: *const FBInfo, x: isize, y: isize, w: usize, h: usize, c: usize) callconv(.C) void,
};

pub var bgColor: usize = 0x1e1e2e;
pub var showCursor: bool = true;
pub var largeFont: bool = false;
pub var info: *FBInfo = undefined;
var cursorX: usize = 0;
var cursorY: usize = 0;
var conHeight: usize = 0;
var conEnabled: bool = false;

fn fbDrawBitmap(x: isize, y: isize, w: usize, h: usize, bitmap: []u8, color: usize, flip: bool) void {
    var i: usize = 0;
    while (i < h) : (i += 1) {
        var j: usize = 0;
        while (j < (w / 8)) : (j += 1) {
            var b: u8 = bitmap[(i * (w / 8)) + j];
            var c: isize = @intCast(isize, j * 8);
            while (b != 0) {
                if (flip) {
                    if ((b & 0x1) != 0) {
                        info.set(info, x + c, y + @intCast(isize, i), 1, 1, color);
                    }
                    c += 1;
                    b >>= 1;
                } else {
                    if ((b & 0x80) != 0) {
                        info.set(info, x + c, y + @intCast(isize, i), 1, 1, color);
                    }
                    c += 1;
                    b <<= 1;
                }
            }
        }
    }
}

pub fn DrawScaledBitmap(x: isize, y: isize, w: usize, h: usize, scW: usize, scH: usize, bitmap: []u8, color: usize) void {
    const x_ratio: usize = ((w << 16) / scW) + 1;
    const y_ratio: usize = ((h << 16) / scH) + 1;
    var i: usize = 0;
    while (i < scH) : (i += 1) {
        var j: usize = 0;
        while (j < scW) : (j += 1) {
            var finalX: usize = (j * x_ratio) >> 16;
            var finalY: usize = (i * y_ratio) >> 16;
            var index = (finalY * w) + finalX;
            var dat = bitmap[index / 8];
            if ((dat >> @intCast(u3, 7 - (index % 8))) & 1 != 0) {
                info.set(info, @intCast(isize, j) + x, @intCast(isize, i) + y, 1, 1, color);
            }
        }
    }
}

pub fn Init(i: *FBInfo) void {
    info = i;
    cursorX = 0;
    cursorY = 0;
    conHeight = (info.height / 12) * 12;
    EnableDisable(!KernelSettings.isQuiet);
    Put("Ryu Kernel Version 0.0.1 (c) 2020-2023 TalonFox\n", .{});
}

fn newline() void {
    cursorX = 0;
    if (largeFont) {
        if (((cursorY + 1) * 16) >= conHeight) {
            cursorY = 0;
        } else {
            cursorY += 1;
        }
    } else {
        cursorY += 1;
    }
    if (largeFont) {
        if (showCursor) {
            info.set(info, 0, @intCast(isize, cursorY * 16), info.width, 16, bgColor);
        }
    } else {
        info.set(info, 0, @intCast(isize, cursorY * 12), info.width, 12, bgColor);
    }
}

fn conWriteString(_: @TypeOf(.{}), string: []const u8) error{}!usize {
    for (0..string.len) |i| {
        const c = string[i];
        if (showCursor) {
            if (largeFont) {
                info.set(info, @intCast(isize, cursorX * 9), @intCast(isize, cursorY * 16), 9, 16, bgColor);
            } else {
                info.set(info, @intCast(isize, cursorX * 6), @intCast(isize, cursorY * 12), 6, 12, bgColor);
            }
        }
        if (c == 8) {
            if (cursorX == 0) {
                if (largeFont) {
                    cursorX = info.width / 9;
                } else {
                    cursorX = info.width / 6;
                }
                cursorY -= 1;
            } else {
                cursorX -= 1;
            }
        } else if (c == '\n') {
            newline();
        } else {
            if (c >= 0x20 and c <= 0x7e) {
                if (largeFont) {
                    fbDrawBitmap(
                        @intCast(isize, cursorX * 9),
                        @intCast(isize, cursorY * 16),
                        16,
                        16,
                        @constCast(LargeFont[((@intCast(usize, c) - 0x20) * (16 * 2))..LargeFont.len]),
                        0xcdd6f4,
                        false,
                    );
                } else {
                    fbDrawBitmap(@intCast(isize, cursorX * 6), @intCast(isize, cursorY * 12), 8, 12, @constCast(HaikuFont[((@intCast(usize, c) - 0x20) * 12)..HaikuFont.len]), 0xcdd6f4, true);
                }
            }
            cursorX += 1;
            if (largeFont) {
                if ((cursorX * 9) >= info.width) {
                    newline();
                }
            } else {
                if ((cursorX * 6) >= info.width) {
                    newline();
                }
            }
        }
        if (showCursor) {
            if (largeFont) {
                info.set(info, @intCast(isize, cursorX * 9), @intCast(isize, cursorY * 16), 9, 16, 0xCDD6F4);
            } else {
                info.set(info, @intCast(isize, cursorX * 6), @intCast(isize, cursorY * 12), 6, 12, 0xCDD6F4);
            }
        }
    }
    return string.len;
}

const Writer = std.io.Writer(@TypeOf(.{}), error{}, conWriteString);
const writer = Writer{ .context = .{} };

pub fn Put(comptime format: []const u8, args: anytype) void {
    if (conEnabled) {
        try writer.print(format, args);
    }
}

pub fn EnableDisable(en: bool) void {
    if (en and !conEnabled) {
        cursorX = 0;
        cursorY = 0;
        if (largeFont) {
            info.set(info, 0, 0, info.width, 16, bgColor);
        } else {
            info.set(info, 0, 0, info.width, 12, bgColor);
        }
        if (showCursor) {
            if (largeFont) {
                info.set(info, @intCast(isize, cursorX * 9), @intCast(isize, cursorY * 16), 9, 16, 0xCDD6F4);
            } else {
                info.set(info, @intCast(isize, cursorX * 6), @intCast(isize, cursorY * 12), 6, 12, 0xCDD6F4);
            }
        }
    }
    conEnabled = en;
}
