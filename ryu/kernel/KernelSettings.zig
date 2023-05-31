const std = @import("std");

pub var isQuiet: bool = false;
pub var noSMP: bool = false;
pub var rescueMode: bool = false;

pub fn ParseCommandline(s: []const u8) void {
    var iter = std.mem.split(u8, std.mem.trim(u8, s, " "), " ");
    while (iter.next()) |arg| {
        if (std.mem.eql(u8, arg, "-quiet")) {
            isQuiet = true;
        } else if (std.mem.eql(u8, arg, "-nosmp")) {
            noSMP = true;
        } else if (std.mem.eql(u8, arg, "-rescue")) {
            rescueMode = true;
        }
    }
}
