const devlib = @import("devlib");
const HAL = @import("root").HAL;
const ELF = @import("root").ELF;

var drvrHead: ?*devlib.RyuDriverInfo = null;
var drvrTail: ?*devlib.RyuDriverInfo = null;
var drvrAddrTop: u64 = 0;

pub fn LoadDriver(name: []const u8, relocObj: *void) void {
    HAL.Console.Put("Loading Driver: {s}...\n", .{name});
    const addr = drvrAddrTop;
    _ = addr;
    ELF.LoadELF(relocObj, .Driver) catch |err| {
        HAL.Console.Put("Failed to Load Driver \"{s}\", Reason: {}\n", .{ name, err });
    };
}
