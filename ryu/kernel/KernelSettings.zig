const std = @import("std");

pub var isQuiet: bool = false;
pub var noSMP: bool = false;
pub var rescueMode: bool = false;
var rootConfigBuf: [256]u8 = [_]u8{0} ** 256;
pub var rootFS: ?[]u8 = null;

pub fn ParseCommandline(s: []const u8) void {
    var iter = std.mem.split(u8, std.mem.trim(u8, s, " "), " ");
    while (iter.next()) |arg| {
        if (std.mem.eql(u8, arg, "-quiet")) {
            isQuiet = true;
        } else if (std.mem.eql(u8, arg, "-nosmp")) {
            noSMP = true;
        } else if (std.mem.eql(u8, arg, "-rescue")) {
            rescueMode = true;
        } else if (arg.len >= 6) {
            if (std.mem.eql(u8, arg[0..6], "-root=")) {
                @memcpy(rootConfigBuf[0..(arg.len - 6)], arg[6..arg.len]);
                rootFS = rootConfigBuf[0..(arg.len - 6)];
            }
        }
    }
}
