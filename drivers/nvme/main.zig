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
};

const NVMeQueueDesc = struct {
    addr: *allowzero void,
    entryCount: usize,
    index: u32,
    id: usize,
    event: bool = false,
    doorbell: *volatile u32,
};

const NVMeQueuePair = struct {
    currentPhase: u1 = 1,
    submitQueue: NVMeQueueDesc,
    completeQueue: NVMeQueueDesc,
};

const NVMeSubmitDWord = packed struct {
    opcode: u8 = 0,
    fused: u2 = 0,
    reserved: u4 = 0,
    prporsgl: u2 = 0,
    cmdid: u16 = 0,
};

const NVMeSubmitEntry = extern struct {
    d0: NVMeSubmitDWord align(1) = NVMeSubmitDWord{},
    namespace: u32 align(1) = 0,
    reserved: [2]u32 align(1) = .{ 0, 0 },
    metadata: u64 align(1) = 0,
    dataptr: [2]u64 align(1) = .{ 0, 0 },
    command: [6]u32 align(1) = .{ 0, 0, 0, 0, 0, 0 },
};

const NVMeCompletionEntry = packed struct {
    cmdSpecific: u32 = 0,
    reserved: u32 = 0,
    subqueuePtr: u16 = 0,
    subqueueID: u16 = 0,
    cmdID: u16 = 0,
    phase: u1 = 0,
    status: u15 = 0,
};

const NVMeLBAFormat = packed struct {
    metadataSize: u16,
    lbaDataSize: u8,
    relativePerformance: u2,
    reserved: u6,
};

const NVMeNamespaceID = extern struct {
    lbaSize: u64 align(1),
    lbaCapacity: u64 align(1),
    lbaUtilized: u64 align(1),
    features: u8 align(1),
    lbaFormatCount: u8 align(1),
    metadataCap: u8 align(1),
    endToEndProt: u8 align(1),
    endToEndProtSettings: u8 align(1),
    sharingCap: u8 align(1),
    resCap: u8 align(1),
    fpi: u8 align(1),
    deallocate: u8 align(1),
    atomicWrite: u16 align(1),
    atomicWritePowerFail: u16 align(1),
    atomicCompareWrite: u16 align(1),
    atomicBoundaryWrite: u16 align(1),
    atomicBoundaryOffset: u16 align(1),
    atomicBoundaryPowerFail: u16 align(1),
    optimalIOBoundary: u16 align(1),
    nvmCapacity: [2]u64 align(1),
    preferredWriteGranularity: u16 align(1),
    preferredWriteAlignment: u16 align(1),
    preferredDeallocateGranularity: u16 align(1),
    preferredDeallocateAlignment: u16 align(1),
    optimalWriteSize: u16 align(1),
    _reserved1: [18]u8 align(1),
    anaGrpID: u32 align(1),
    _reserved2: [3]u8 align(1),
    namespaceAttr: u8 align(1),
    nvmsetID: u16 align(1),
    endgID: u16 align(1),
    namespaceGUID: [2]u64 align(1),
    eui64: u64 align(1),
    lbaFormat: [16]NVMeLBAFormat align(1),
};

const NVMeDrive = struct {
    next: ?*NVMeDrive,
    bus: u8,
    slot: u8,
    func: u8,
    irq: u16,
    regs: *volatile NVMeRegisters,
    identify: *NVMeNamespaceID,
    // Controller Info
    maxQueue: usize,
    doorbellStride: usize,
    adminQueue: NVMeQueuePair,
    ioQueue: NVMeQueuePair,
    maxDataTransfer: u8,

    pub fn SubmitAndWait(self: *NVMeDrive, entry: NVMeSubmitEntry, queue: *NVMeQueuePair) NVMeCompletionEntry {
        _ = self;
        queue.completeQueue.event = false;
        const subq = @as([*]NVMeSubmitEntry, @alignCast(@ptrCast(queue.submitQueue.addr)));
        const compq = @as([*]NVMeCompletionEntry, @alignCast(@ptrCast(queue.completeQueue.addr)));
        subq[@intCast(queue.submitQueue.index)] = entry;
        const id = queue.submitQueue.index;
        _ = id;
        queue.submitQueue.index = (queue.submitQueue.index + 1) % @as(u32, @intCast(queue.submitQueue.entryCount));
        queue.submitQueue.doorbell.* = queue.submitQueue.index;
        while (true) {
            while (!queue.completeQueue.event) {
                _ = DriverInfo.krnlDispatch.?.enableDisableIRQ(true);
                asm volatile ("hlt");
                _ = DriverInfo.krnlDispatch.?.enableDisableIRQ(false);
            }
            queue.completeQueue.event = false;
            while (true) {
                if (compq[@intCast(queue.completeQueue.index)].phase == ~queue.currentPhase) {
                    break;
                }
                const completion: NVMeCompletionEntry = compq[@intCast(queue.completeQueue.index)];
                queue.completeQueue.index = (queue.completeQueue.index + 1) % @as(u32, @intCast(queue.completeQueue.entryCount));
                if (queue.completeQueue.index == 0)
                    queue.currentPhase = ~queue.currentPhase;
                queue.completeQueue.doorbell.* = queue.completeQueue.index;
                return completion;
            }
        }
    }

    pub fn Identify(self: *NVMeDrive, buf: []u8, t: u32, what: u32) void {
        if (t >= 3) {
            DriverInfo.krnlDispatch.?.abort("NVMe Identification of t >= 3 is not supported");
            return;
        }
        var sub: NVMeSubmitEntry = NVMeSubmitEntry{};
        sub.dataptr[0] = @intFromPtr(DriverInfo.krnlDispatch.?.pfnAlloc(false)) - 0xffff800000000000;
        sub.command[0] = t;
        sub.d0.opcode = 0x6; // IDENTIFY
        if (t == 0)
            sub.namespace = what;
        _ = self.SubmitAndWait(sub, &self.adminQueue);
        std.mem.copyForwards(u8, buf[0..4096], @as([*]u8, @ptrFromInt(sub.dataptr[0] + 0xffff800000000000))[0..4096]);
        DriverInfo.krnlDispatch.?.pfnDeref(@as(*void, @ptrFromInt(sub.dataptr[0])));
    }

    pub fn Init(self: *NVMeDrive) void {
        const majorVer = self.regs.version >> 16;
        const minorVer = (self.regs.version >> 8) & 0xFF;
        if (majorVer == 1 and minorVer < 4) {
            DriverInfo.krnlDispatch.?.abort("Unsupported NVMe Version!");
            return;
        }
        if ((self.regs.caps & (@as(u64, 1) << 37)) == 0) {
            DriverInfo.krnlDispatch.?.abort("NVMe Controller doesn't support the NVM command set!");
            return;
        }
        if (std.math.pow(u64, 2, 12 + ((self.regs.caps & 0xF000000) >> 32)) > 4096) {
            DriverInfo.krnlDispatch.?.abort("NVMe Controller's minimum page size is larger than Ryu's page size of 4096!");
            return;
        }
        PCIDrvr.writeU16(self.bus, self.slot, self.func, 0x04, PCIDrvr.readU16(self.bus, self.slot, self.func, 0x04) | 6);
        var conf = self.regs.config;
        conf &= ~@as(u32, 1); // Reset Controller
        self.regs.config = conf;
        // NVM Command Set
        conf &= ~@as(u32, 0b1110000);
        // 4K Page Size
        conf &= ~@as(u32, 0b11110000000);
        // Round Robin AMS
        conf &= ~@as(u32, 0b11100000000000);
        self.regs.config = conf;
        self.regs.adminQueueAttr = (@as(u32, (4096 / @sizeOf(NVMeCompletionEntry)) - 1) << 16) | ((4096 / @sizeOf(NVMeSubmitEntry)) - 1);
        self.regs.adminSubQueueBase = @intFromPtr(DriverInfo.krnlDispatch.?.pfnAlloc(false)) - 0xffff800000000000;
        self.regs.adminCplQueueBase = @intFromPtr(DriverInfo.krnlDispatch.?.pfnAlloc(false)) - 0xffff800000000000;
        self.regs.config = self.regs.config | 1;
        while ((self.regs.status & 3) == 0) {
            std.atomic.spinLoopHint();
        }
        if ((self.regs.status & 2) != 0) {
            DriverInfo.krnlDispatch.?.abort("Failed to initialize NVMe Controller!");
            return;
        }
        // NVMe Controller was successfully reset!
        self.maxQueue = (self.regs.caps & 0xFFFF) + 1;
        self.doorbellStride = @as(u64, 1) << @as(u6, @intCast(2 + ((self.regs.caps & 0xF00000000) >> 32)));
        self.adminQueue.submitQueue.addr = @ptrFromInt(self.regs.adminSubQueueBase + 0xffff800000000000);
        self.adminQueue.completeQueue.addr = @ptrFromInt(self.regs.adminCplQueueBase + 0xffff800000000000);
        self.adminQueue.completeQueue.entryCount = 4096 / @sizeOf(NVMeCompletionEntry);
        self.adminQueue.submitQueue.entryCount = 4096 / @sizeOf(NVMeSubmitEntry);
        self.adminQueue.submitQueue.doorbell = @as(*volatile u32, @ptrFromInt(@intFromPtr(self.regs) + 0x1000 + 0 * 2 * self.doorbellStride));
        self.adminQueue.completeQueue.doorbell = @as(*volatile u32, @ptrFromInt(@intFromPtr(self.regs) + 0x1000 + (0 * 2 + 1) * self.doorbellStride));
        self.adminQueue.currentPhase = 1;
        const conAddr = @intFromPtr(DriverInfo.krnlDispatch.?.staticAllocAnon(4096));
        self.Identify(@as([*]u8, @ptrFromInt(conAddr))[0..4096], 1, 0);
        self.maxDataTransfer = @as(*u8, @ptrFromInt(conAddr + 77)).*;
        DriverInfo.krnlDispatch.?.staticFreeAnon(@as(*void, @ptrFromInt(conAddr)), 4096);
    }
};

var driveHead: ?*NVMeDrive = null;

pub fn NVMeIRQ(irq: u16) callconv(.C) void {
    _ = irq;
    var drive = driveHead;
    while (drive != null) {
        drive.?.adminQueue.completeQueue.event = true;
        drive.?.ioQueue.completeQueue.event = true;
        drive = drive.?.next;
    }
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
                drive.identify = @as(*NVMeNamespaceID, @alignCast(@ptrCast(dispatch.staticAllocAnon(4096))));
                drive.regs = @ptrFromInt(PCIDrvr.readBar(drive.bus, drive.slot, drive.func, 0) + 0xffff800000000000);
                drive.next = driveHead;
                driveHead = drive;
                drive.Init();
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
