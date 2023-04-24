const native = @import("native");
const std = @import("std");

pub const Thread = struct {
    kstack: [3072]u8,
    context: native.context.Context,
    floatContext: native.context.FloatContext,

    comptime {
        std.debug.assert(@sizeOf(@This()) <= 4096);
    }
};
