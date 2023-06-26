const HAL = @import("root").HAL;
const FS = @import("root").FS;
const Executive = @import("root").Executive;
const std = @import("std");

const CallCategory = enum(u16) {
    Null = 0,
    Filesystem = 1,
    Process = 2,
    Ryu = 3,
};

const FilesystemFuncs = enum(u16) { // All of these are just normal UNIX calls, kinda boring tbh...
    Open = 1,
    Close = 2,
    Read = 3,
    Write = 4,
    LSeek = 5,
    Trunc = 6,
    Stat = 7,
    FStat = 8,
    ChOwn = 9,
    FChOwn = 10,
    ChMod = 11,
    FChMod = 12,
    IOCtl = 13,
    MMap = 14,
    MUnMap = 15,
    ChDir = 16,
    Dup = 17, // functions like dup2
};

const ProcessFuncs = enum(u16) {
    NewTeam = 1,
    LoadExecImage = 2, // Basically exec except better since you can trigger it on either yourself or one of your child teams
    CloneImage = 3, // Basically like fork but you also have to create a team first
    NewThread = 4,
    KillThread = 5,
    KillTeam = 6,
    Exit = 7,
    GetThreadID = 8,
    GetTeamID = 9,
    GetParentID = 10,
    GetRUID = 11,
    GetRGID = 12,
    GetEUID = 13,
    GetEGID = 14,
    GetGroups = 15,
    SetRUID = 16,
    SetRGID = 17,
    SetEUID = 18,
    SetEGID = 19,
    SetGroups = 20,
    Wait = 21, // functions like waitpid not wait
};

const RyuFuncs = enum(u16) {
    KernelLog = 1,
};

const TEAM_CREATE_INHERIT_FILES: usize = 1;

pub export fn RyuSyscallDispatch(regs: *HAL.Arch.Context) callconv(.C) void {
    const cat: CallCategory = @intToEnum(CallCategory, @intCast(u16, (regs.GetReg(0) & 0xFFFF0000) >> 16));
    const func: u16 = @intCast(u16, regs.GetReg(0) & 0xFFFF);
    //HAL.Console.Put("SystemCall | Cat: {x} Func: {x} ({x},{x},{x},{x},{x},{x})\n", .{ @enumToInt(cat), func, regs.GetReg(1), regs.GetReg(2), regs.GetReg(3), regs.GetReg(4), regs.GetReg(5), regs.GetReg(6) });
    switch (cat) {
        .Filesystem => {},
        .Process => {
            switch (@intToEnum(ProcessFuncs, func)) {
                .NewTeam => { // TeamID_t NewTeam(*const char name, TeamCreateFlags flags)

                },
                else => {
                    regs.SetReg(0, @bitCast(u64, @intCast(i64, -4096)));
                },
            }
        },
        .Ryu => {
            switch (@intToEnum(RyuFuncs, func)) {
                .KernelLog => { // void KernelLog(*const char text)
                    var s: [*c]const u8 = @intToPtr([*c]const u8, regs.GetReg(1));
                    HAL.Console.Put("{s}", .{@ptrCast([*]const u8, s)[0..std.mem.len(s)]});
                    regs.SetReg(0, 0);
                },
            }
        },
        else => {
            regs.SetReg(0, @bitCast(u64, @intCast(i64, -4096)));
        },
    }
}

pub fn stub() void { // Doesn't do anything but helps to keep Zig from optimizing this file out

}
