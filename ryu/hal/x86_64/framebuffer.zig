const limine = @import("limine");
const std = @import("std");
const HAL = @import("../HAL.zig");

export var fb_request: limine.FramebufferRequest = .{};

fn setPixels(self: *const HAL.Console.FBInfo, x: isize, y: isize, w: usize, h: usize, c: usize) callconv(.C) void {
    var i: isize = y;
    while (i < (y + @as(isize, @intCast(h)))) : (i += 1) {
        if (i < 0) {
            continue;
        } else if (i >= self.height) {
            return;
        }
        var j: isize = x;
        while (j < (x + @as(isize, @intCast(w)))) : (j += 1) {
            if (j < 0) {
                continue;
            } else if (j >= self.width) {
                break;
            }
            @as([*]u32, @ptrCast(@alignCast(self.ptr)))[(@as(usize, @intCast(i)) * (self.pitch / (self.bpp / 8))) + @as(usize, @intCast(j))] = @as(u32, @intCast(c));
        }
    }
}

var info = HAL.Console.FBInfo{ .set = &setPixels };

pub fn init() void {
    if (fb_request.response) |response| {
        for (response.framebuffers()) |fb| {
            info.ptr = @as(*allowzero void, @ptrCast(fb.address + 0));
            info.width = @as(usize, @intCast(fb.width));
            info.height = @as(usize, @intCast(fb.height));
            info.pitch = @as(usize, @intCast(fb.pitch));
            info.bpp = @as(usize, @intCast(fb.bpp));
            HAL.Console.Init(&info);
            return;
        }
    }
}
