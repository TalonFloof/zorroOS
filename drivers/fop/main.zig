const devlib = @import("devlib");
const std = @import("std");

pub export var DriverInfo = devlib.RyuDriverInfo{
    .apiMinor = 1,
    .apiMajor = 0,
    .drvName = "FopDriver",
    .loadFn = &LoadDriver,
    .unloadFn = &UnloadDriver,
};

pub fn LoadDriver() callconv(.C) devlib.Status {
    if (DriverInfo.krnlDispatch) |dispatch| {
        dispatch.put("hii i am fop driver, i is fop :3\nHEHEHE NOW I CRASH COMPUTR\n");
        //dispatch.abort("umm, i chewed da cables and it did somin bad owo");
        return .Okay;
    }
    return .Failure;
}

pub fn UnloadDriver() callconv(.C) devlib.Status {
    return .Okay;
}
