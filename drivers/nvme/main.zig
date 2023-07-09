const devlib = @import("devlib");
const std = @import("std");
const pci = @import("pci");

pub export var DriverInfo = devlib.RyuDriverInfo{
    .apiMinor = 1,
    .apiMajor = 0,
    .drvName = "NVMeDriver",
    .exportedDispatch = null,
    .loadFn = &LoadDriver,
    .unloadFn = &UnloadDriver,
};

pub var PCIDrvr: *allowzero pci.PCIInterface = @ptrFromInt(0);

const NVMeRegisters = extern struct {
    caps: u64 align(1),
    version: u32 align(1),
    intMask: u32 align(1),
    intMaskClear: u32 align(1),
    config: u32 align(1),
    reserved: u32 align(1),
    status: u32 align(1),
    nvmSubsysReset: u32 align(1),
    adminQueueAttr: u32 align(1),
    adminSubQueueBase: u64 align(1),
    adminCplQueueBase: u64 align(1),
    // There's more after this but this is all we care about
};

const NVMeDrive = struct {
    bus: u8,
    slot: u8,
    func: u8,
    irq: u16,
    regs: *volatile NVMeRegisters,
};

pub fn NVMeIRQ(irq: u16) callconv(.C) void {
    _ = irq;
}

pub fn LoadDriver() callconv(.C) devlib.Status {
    if (DriverInfo.krnlDispatch) |dispatch| {
        PCIDrvr = @alignCast(@ptrCast(devlib.FindDriver(&DriverInfo, "PCIDriver").?));
        dispatch.put("Searching for NVMe Drives...\n");
        var index: ?*pci.PCIDevice = PCIDrvr.getDevices();
        while (index) |device| {
            if (device.class == 1 and device.subclass == 8 and device.progif == 2) {
                // We got one!
                var drive: *NVMeDrive = @alignCast(@ptrCast(dispatch.staticAlloc(@sizeOf(NVMeDrive))));
                drive.bus = device.bus;
                drive.slot = device.slot;
                drive.func = device.func;
                drive.irq = PCIDrvr.acquireIRQ(drive.bus, drive.slot, drive.func, &NVMeIRQ);
                if (drive.irq == 0) {
                    dispatch.abort("Unable to aquire IRQ for NVMe drive!");
                } else {
                    dispatch.putNumber(drive.bus, 16, false, '0', 2);
                    dispatch.put(":");
                    dispatch.putNumber(drive.slot, 16, false, '0', 2);
                    dispatch.put(".");
                    dispatch.putNumber(drive.func, 16, false, '0', 1);
                    dispatch.put(": NVMe Drive with IRQ Line 0x");
                    dispatch.putNumber(drive.irq, 16, false, ' ', 0);
                    dispatch.put(" @ 0x");
                    dispatch.putNumber(PCIDrvr.readBar(drive.bus, drive.slot, drive.func, 0) + 0xffff800000000000, 16, false, ' ', 0);
                    dispatch.put("\n");
                }
                drive.regs = @ptrFromInt(PCIDrvr.readBar(drive.bus, drive.slot, drive.func, 0) + 0xffff800000000000);
            }
            index = device.next;
        }
        return .Okay;
    }
    return .Failure;
}

pub fn UnloadDriver() callconv(.C) devlib.Status {
    return .Okay;
}

pub fn panic(msg: []const u8, stacktrace: ?*std.builtin.StackTrace, wat: ?usize) noreturn {
    _ = wat;
    _ = stacktrace;
    while (true) {
        DriverInfo.krnlDispatch.?.abort(@ptrCast(msg.ptr));
    }
}
