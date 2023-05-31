const limine = @import("limine");
const std = @import("std");
const HAL = @import("../HAL.zig");

export var con_request: limine.TerminalRequest = .{};
export var fb_request: limine.FramebufferRequest = .{};

fn setPixels(self: *const HAL.Console.FBInfo, x: isize, y: isize, w: usize, h: usize, c: usize) callconv(.C) void {
    var i: isize = y;
    while (i < (y + @intCast(isize, h))) : (i += 1) {
        if (i < 0) {
            continue;
        } else if (i >= self.width) {
            return;
        }
        var j: isize = x;
        while (j < (x + @intCast(isize, w))) : (j += 1) {
            if (j < 0) {
                continue;
            } else if (i >= self.width) {
                break;
            }
            @ptrCast([*]u32, @alignCast(4, self.ptr))[(@intCast(usize, i) * (self.pitch / (self.bpp / 8))) + @intCast(usize, j)] = @intCast(u32, c);
        }
    }
}

var info = HAL.Console.FBInfo{ .set = &setPixels };

pub fn init(bootLogo: ?[]u8) void {
    if (con_request.response) |response| {
        response.write(response.terminals()[0], "\x1b[?25l");
    }
    if (fb_request.response) |response| {
        for (response.framebuffers()) |fb| {
            info.ptr = @ptrCast(*allowzero void, fb.address + 0);
            info.width = @intCast(usize, fb.width);
            info.height = @intCast(usize, fb.height);
            info.pitch = @intCast(usize, fb.pitch);
            info.bpp = @intCast(usize, fb.bpp);
            HAL.Console.Init(&info, bootLogo);
            return;
        }
    }
}
