const Thread = @import("thread.zig").Thread;
const std = @import("std");

pub const Team = struct {
    teamID: usize,
    threads: [128]Thread,
};
