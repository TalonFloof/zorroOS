const devlib = @import("devlib");
const std = @import("std");

pub export var DriverInfo = devlib.RyuDriverInfo{
    .apiMinor = 0,
    .apiMajor = 1,
    .drvName = "FopDriver",
};

pub export fn LoadDriver() callconv(.C) devlib.Status {
    if (DriverInfo.krnlDispatch) |dispatch| {
        dispatch.put("hii i am fop driver, i is fop :3\nHEHEHE NOW I CRASH COMPUTR\n");
        dispatch.abort("umm, i chewed da cables and it did somin bad owo");
        return .Okay;
    }
    return .Failure;
}

pub export fn UnloadDriver() callconv(.C) devlib.Status {
    return .Okay;
}
