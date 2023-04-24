const native = @import("native");
const std = @import("std");
const Team = @import("team.zig").Team;

pub const Thread = struct {
    kstack: [3072]u8 = [_]u8{0} ** 3072,
    context: native.context.Context,
    floatContext: native.context.FloatContext,
    prev: ?*Thread,
    next: ?*Thread,
    id: u64,
    hartID: u64,
    team: *Team,

    comptime {
        std.debug.assert(@sizeOf(@This()) <= 4096);
    }
};
