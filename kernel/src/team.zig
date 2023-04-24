const Thread = @import("thread.zig").Thread;
const std = @import("std");

pub const Team = struct {
    teamID: usize,
    parentTeam: ?*Team,
    teamName: [64]u8 = [_]u8{0} ** 64,
    threads: [256]?*Thread = [_]?*Thread{null} ** 256,

    comptime {
        std.debug.assert(@sizeOf(@This()) <= 4096);
    }
};
