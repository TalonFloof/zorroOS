const std = @import("std");
const HaikuFont = @import("HALConsoleFont.zig").HaikuFont;
const KernelSettings = @import("root").KernelSettings;

pub const FBInfo = struct {
    ptr: *allowzero void = @intToPtr(*allowzero void, 0),
    width: usize = 0,
    height: usize = 0,
    pitch: usize = 0,
    bpp: usize = 0,
    set: *const fn (self: *const FBInfo, x: isize, y: isize, w: usize, h: usize, c: usize) callconv(.C) void,
};

var info: *const FBInfo = undefined;
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

pub fn Init(i: *const FBInfo, bootLogo: ?[]u8) void {
    info = i;
    cursorX = 0;
    cursorY = 0;
    conHeight = ((info.height / 2) / 12) * 12;
    var runtime: usize = 0;
    _ = runtime;
    if (bootLogo) |logo| {
        var height = logo.len / 16;
        fbDrawBitmap(
            @intCast(isize, (info.width / 2) - 64),
            @intCast(isize, (info.height / 2) - (height / 2)),
            128,
            height,
            logo,
            0xffffff,
            false,
        );
    }
    EnableDisable(!KernelSettings.isQuiet);
    //var y = info.height - 96;
    //while (y <= info.height) : (y += 1) {
    //    var x: isize = if ((y % 2) == 1) 1 else 0;
    //    while (x <= info.width) : (x += 2) {
    //        info.set(info, x, @intCast(isize, y), 1, 1, 0x1E1E2E);
    //    }
    //}
    //fbDrawBitmap(@divTrunc(@intCast(isize, info.width), 2) - 84, @intCast(isize, info.height) - 96, 96, 24, @constCast(ryuLogo[runtime..ryuLogo.len]), 0xB57BEE);
    //fbDrawBitmap(@divTrunc(@intCast(isize, info.width), 2) - 84, @intCast(isize, info.height) - 72, 96, 24, @constCast(ryuLogo[runtime + (12 * 24) .. ryuLogo.len]), 0x8B61C1);
    //fbDrawBitmap(@divTrunc(@intCast(isize, info.width), 2) - 84, @intCast(isize, info.height) - 48, 96, 24, @constCast(ryuLogo[runtime + (24 * 24) .. ryuLogo.len]), 0x624795);
    //fbDrawBitmap(@divTrunc(@intCast(isize, info.width), 2) - 84, @intCast(isize, info.height) - 24, 96, 24, @constCast(ryuLogo[runtime + (36 * 24) .. ryuLogo.len]), 0x392D69);
    //fbDrawBitmap(@divTrunc(@intCast(isize, info.width), 2) + 20, @intCast(isize, info.height - 66), 64, 37, @constCast(ryuText[runtime..ryuText.len]), 0xffffff);
    Put("Ryu Kernel Version 0.0.1 (c) 2020-2023 TalonFox\n", .{});
    Put("Celebrating 3 years of zorroOS!\n", .{});
}

fn newline() void {
    cursorX = 0;
    if (((cursorY + 1) * 12) >= conHeight) {
        // Scroll
        @memcpy(
            @intToPtr([*]u8, @ptrToInt(info.ptr))[0..((conHeight - 12) * info.pitch)],
            @intToPtr([*]u8, @ptrToInt(info.ptr) + (12 * info.pitch))[0..((conHeight - 12) * info.pitch)],
        );
        info.set(info, 0, @intCast(isize, conHeight - 12), info.width, 12, 0x1e1e2e);
    } else {
        cursorY += 1;
    }
}

fn conWriteString(_: @TypeOf(.{}), string: []const u8) error{}!usize {
    for (0..string.len) |i| {
        const c = string[i];
        info.set(info, @intCast(isize, cursorX * 6), @intCast(isize, cursorY * 12), 6, 12, 0x1E1E2E);
        if (c == '\n') {
            newline();
        } else {
            if (c >= 0x20 and c <= 0x7e) {
                fbDrawBitmap(@intCast(isize, cursorX * 6), @intCast(isize, cursorY * 12), 8, 12, @constCast(HaikuFont[((@intCast(usize, c) - 0x20) * 12)..HaikuFont.len]), 0xcdd6f4, true);
            }
            cursorX += 1;
            if ((cursorX * 6) >= info.width) {
                newline();
            }
        }
        info.set(info, @intCast(isize, cursorX * 6), @intCast(isize, cursorY * 12), 6, 12, 0xCDD6F4);
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
        info.set(info, 0, 0, info.width, conHeight, 0x1E1E2E);
        info.set(info, @intCast(isize, cursorX * 6), @intCast(isize, cursorY * 12), 6, 12, 0xCDD6F4);
    }
    conEnabled = en;
}
