const std = @import("std");

pub fn Object(comptime T: type) type {
    _ = T;
    return struct {};
}
