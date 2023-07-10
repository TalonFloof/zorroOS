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
    addr: *allowzero void = @ptrFromInt(0),
    entryCount: usize = 0,
    index: u32 = 0,
    id: usize = 0,
    event: bool = false,
    doorbell: *allowzero align(1) volatile u32 = @ptrFromInt(0),
};

const NVMeQueuePair = struct {
    currentPhase: u1 = 1,
    nextCommand: u16 = 0,
    submitQueue: NVMeQueueDesc = NVMeQueueDesc{},
    completeQueue: NVMeQueueDesc = NVMeQueueDesc{},
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

    comptime {
        if (@sizeOf(@This()) != 64) {
            @compileError("NVMeSubmitEntry size != 64!");
        }
    }
};

const NVMeCompletionEntry = packed struct {
    cmdSpecific: u32 = 0,
    reserved: u32 = 0,
    subqueuePtr: u16 = 0,
    subqueueID: u16 = 0,
    cmdID: u16 = 0,
    phase: u1 = 0,
    status: u15 = 0,

    comptime {
        if (@sizeOf(@This()) != 16) {
            @compileError("NVMeCompletionEntry size != 16!");
        }
    }
};

const NVMeLBAFormat = packed struct {
    metadataSize: u16,
    lbaDataSize: u8,
    relativePerformance: u2,
    reserved: u6,
};

const NVMeControllerID = extern struct {
    vendorID: u16,
    subsystemVendorID: u16,
    serialNumber: [20]u8,
    modelNumber: [40]u8,
    firmwareRevision: [8]u8,
    recommendedArbitrationBurst: u8,
    ieee: [3]u8,
    cmic: u8,
    maximumDataTransferSize: u8,
    controllerID: u16,
    version: u32,
    rtd3ResumeLatency: u32,
    rtd3EntryLatency: u32,
    oaes: u32,
    controllerAttributes: u32,
    rrls: u16,
    reserved: [9]u8,
    controllerType: u8,
    fGUID: [16]u8,
    crdt: [3]u16,
    reserved2: [122]u8,
    oacs: u16,
    acl: u8,
    aerl: u8,
    firmwareUpdates: u8,
    logPageAttributes: u8,
    errorLogPageEntries: u8,
    numberOfPowerStates: u8,
    apsta: u8,
    wcTemp: u16,
    ccTemp: u16,
    mtfa: u16,
    hostMemoryBufferPreferredSize: u32,
    hostMemoryBufferMinimumSize: u32,
    unused: [232]u8,
    sqEntrySize: u8,
    cqEntrySize: u8,
    maxCmd: u16,
    numNamespaces: u32,
    unused2: [248]u8,
    name: [256]u8,
    unused3: [3072]u8,

    comptime {
        if (@sizeOf(@This()) != 4096) {
            @compileLog(@sizeOf(@This()));
            @compileError("NVMe Controller ID size is != 4096!");
        }
    }
};

const NVMeNamespaceID = extern struct {
    namespaceSize: u64 align(1),
    lbaCapacity: u64 align(1),
    namespaceUtilized: u64 align(1),
    features: u8 align(1),
    lbaFormatCount: u8 align(1),
    fmtLbaSize: u8 align(1),
    unused: [101]u8 align(1),
    lbaFormat: [16]NVMeLBAFormat align(1),
    reserved: [192]u8 align(1),
    vendor: [3712]u8 align(1),
};

const NVMeNamespace = struct {
    drive: *NVMeDrive,
    nsID: u32,
    id: *NVMeNamespaceID,
    blockSize: u64,
    blocks: u64,
    queue: NVMeQueuePair = NVMeQueuePair{},
    spinlock: u8 = 0,

    pub fn Read(self: *NVMeNamespace, lba: u64, buf: []u8) bool {
        var blocksToRead = buf.len / self.blockSize;
        var curLBA = lba;
        var curBase: [*]u8 = buf.ptr;
        var page = DriverInfo.krnlDispatch.?.pfnAlloc(false);
        while (blocksToRead > 0) {
            var command = NVMeSubmitEntry{};
            command.d0.opcode = 0x2; // READ
            command.namespace = self.nsID;
            command.dataptr[0] = @intFromPtr(page) - 0xffff800000000000;
            command.command[0] = @intCast(lba & 0xffffffff);
            command.command[1] = @intCast((lba >> 32) & 0xffffffff);
            command.command[2] = @intCast(@min((4096 / self.blockSize), blocksToRead) - 1);
            const result = self.drive.SubmitAndWait(command, &self.queue);
            if (result.status != 0) {
                DriverInfo.krnlDispatch.?.pfnDeref(@ptrFromInt(@intFromPtr(page) - 0xffff800000000000));
                return false;
            }
            std.mem.copyForwards(u8, curBase[0 .. @min((4096 / self.blockSize), blocksToRead) * self.blockSize], @as([*]u8, @alignCast(@ptrCast(page)))[0 .. @min((4096 / self.blockSize), blocksToRead) * self.blockSize]);
            curBase = @ptrFromInt(@intFromPtr(curBase) + 4096);
            curLBA += (4096 / self.blockSize);
            blocksToRead -= @min((4096 / self.blockSize), blocksToRead);
        }
        DriverInfo.krnlDispatch.?.pfnDeref(@ptrFromInt(@intFromPtr(page) - 0xffff800000000000));
        return true;
    }

    pub fn Init(self: *NVMeNamespace) void {
        // Create the Completion Queue
        self.queue.completeQueue.addr = DriverInfo.krnlDispatch.?.pfnAlloc(false);
        self.queue.completeQueue.entryCount = 4096 / @sizeOf(NVMeCompletionEntry);
        self.queue.completeQueue.id = self.drive.nextID;
        self.queue.completeQueue.event = false;
        self.queue.completeQueue.index = 0;
        self.queue.completeQueue.doorbell = @as(*align(1) volatile u32, @ptrFromInt(@intFromPtr(self.drive.regs) + 0x1000 + (self.drive.nextID * 2 + 1) * (@as(usize, 4) << @intCast(self.drive.doorbellStride))));
        var command: NVMeSubmitEntry = NVMeSubmitEntry{};
        command.d0.opcode = 0x5; // CREATEIOCOMPQUEUE
        command.dataptr[0] = @intFromPtr(self.queue.completeQueue.addr) - 0xffff800000000000;
        command.command[0] = @as(u32, @intCast(self.drive.nextID)) | ((@as(u32, @intCast(self.queue.completeQueue.entryCount)) - 1) << 16);
        command.command[1] = 3;
        var result = self.drive.SubmitAndWait(command, &self.drive.adminQueue);
        if (result.status != 0) {
            DriverInfo.krnlDispatch.?.abort("Failed to create completion queue!");
            return;
        }
        self.queue.submitQueue.addr = DriverInfo.krnlDispatch.?.pfnAlloc(false);
        self.queue.submitQueue.entryCount = 4096 / @sizeOf(NVMeSubmitEntry);
        self.queue.submitQueue.id = self.drive.nextID;
        self.queue.submitQueue.event = false;
        self.queue.submitQueue.index = 0;
        self.queue.submitQueue.doorbell = @as(*align(1) volatile u32, @ptrFromInt(@intFromPtr(self.drive.regs) + 0x1000 + (self.drive.nextID * 2) * (@as(usize, 4) << @intCast(self.drive.doorbellStride))));
        command = NVMeSubmitEntry{};
        command.d0.opcode = 0x1; // CREATEIOSUBQUEUE
        command.dataptr[0] = @intFromPtr(self.queue.submitQueue.addr) - 0xffff800000000000;
        command.command[0] = @as(u32, @intCast(self.drive.nextID)) | ((@as(u32, @intCast(self.queue.submitQueue.entryCount)) - 1) << 16);
        command.command[1] = 1 | (@as(u32, @intCast(self.drive.nextID)) << 16);
        result = self.drive.SubmitAndWait(command, &self.drive.adminQueue);
        if (result.status != 0) {
            DriverInfo.krnlDispatch.?.abort("Failed to create submission queue!");
            return;
        }
        self.drive.nextID += 1;
        var buf = @as([*]u8, @alignCast(@ptrCast(DriverInfo.krnlDispatch.?.staticAlloc(512))))[0..512];
        if (self.Read(1, buf)) {
            var i: usize = 0;
            while (i < 512) : (i += 16) {
                DriverInfo.krnlDispatch.?.putNumber(i, 16, false, '0', 4);
                DriverInfo.krnlDispatch.?.put(": ");
                var j: usize = 0;
                while (j < 16) : (j += 1) {
                    DriverInfo.krnlDispatch.?.putNumber(buf[i + j], 16, false, '0', 2);
                    DriverInfo.krnlDispatch.?.put(" ");
                }
                DriverInfo.krnlDispatch.?.put("|");
                DriverInfo.krnlDispatch.?.putRaw(@as([*c]u8, @ptrCast(&buf[i])), 16);
                DriverInfo.krnlDispatch.?.put("|\n");
            }
        } else {
            DriverInfo.krnlDispatch.?.abort("Failed to read LBA Sector 1");
        }
    }
};

const NVMeDrive = struct {
    next: ?*NVMeDrive,
    bus: u8,
    slot: u8,
    func: u8,
    irq: u16,
    nextID: u64 = 1,
    regs: *volatile NVMeRegisters,
    namespaces: []NVMeNamespace,
    contID: *NVMeControllerID,
    // Controller Info
    maxQueue: usize,
    doorbellStride: usize,
    adminQueue: NVMeQueuePair,

    pub fn SubmitAndWait(self: *NVMeDrive, entry: NVMeSubmitEntry, queue: *NVMeQueuePair) NVMeCompletionEntry {
        _ = self;
        queue.completeQueue.event = false;
        if (@intFromPtr(queue.submitQueue.addr) == 0) {
            DriverInfo.krnlDispatch.?.abort("Cannot submit a command to a null submission queue!");
        }
        const subq = @as([*]align(1) NVMeSubmitEntry, @alignCast(@ptrCast(queue.submitQueue.addr)));
        const compq = @as([*]align(1) NVMeCompletionEntry, @alignCast(@ptrCast(queue.completeQueue.addr)));
        if (@intFromPtr(&subq[@intCast(queue.submitQueue.index)]) == 0) {
            DriverInfo.krnlDispatch.?.abort("Cannot submit a command to a null location!");
        }
        subq[@intCast(queue.submitQueue.index)] = entry;
        subq[@intCast(queue.submitQueue.index)].d0.cmdid = @intCast(queue.nextCommand);
        queue.nextCommand +%= 1;
        const id = queue.submitQueue.index;
        _ = id;
        queue.submitQueue.index = (queue.submitQueue.index + 1) % @as(u32, @intCast(queue.submitQueue.entryCount));
        queue.submitQueue.doorbell.* = @intCast(queue.submitQueue.index);
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
                    queue.currentPhase = if (queue.currentPhase == 1) 0 else 1;
                queue.completeQueue.doorbell.* = @intCast(queue.completeQueue.index);
                return completion;
            }
            std.atomic.spinLoopHint();
        }
    }

    pub fn Identify(self: *NVMeDrive, buf: []u8, t: u32, what: u32) bool {
        if (t >= 3) {
            DriverInfo.krnlDispatch.?.abort("NVMe Identification of t >= 3 is not supported");
            return false;
        }
        var sub: NVMeSubmitEntry = NVMeSubmitEntry{};
        sub.dataptr[0] = @intFromPtr(DriverInfo.krnlDispatch.?.pfnAlloc(false)) - 0xffff800000000000;
        sub.command[0] = t;
        sub.d0.opcode = 0x6; // IDENTIFY
        if (t == 0)
            sub.namespace = what;
        const response = self.SubmitAndWait(sub, &self.adminQueue);
        if (response.status == 0) {
            std.mem.copyForwards(u8, buf[0..4096], @as([*]u8, @ptrFromInt(sub.dataptr[0] + 0xffff800000000000))[0..4096]);
        }
        DriverInfo.krnlDispatch.?.pfnDeref(@as(*void, @ptrFromInt(sub.dataptr[0])));
        return response.status == 0;
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
        PCIDrvr.writeU16(self.bus, self.slot, self.func, 0x04, PCIDrvr.readU16(self.bus, self.slot, self.func, 0x04) | 2);
        PCIDrvr.writeU16(self.bus, self.slot, self.func, 0x04, PCIDrvr.readU16(self.bus, self.slot, self.func, 0x04) | 4);
        var conf = self.regs.config;
        conf &= ~@as(u32, 1); // Reset Controller
        self.regs.config = conf;
        while ((self.regs.status & 1) == 1) {
            std.atomic.spinLoopHint();
        }
        // NVM Command Set
        conf &= ~@as(u32, 0b1110000);
        // 4K Page Size
        conf &= ~@as(u32, 0b11110000000);
        // Round Robin AMS
        conf &= ~@as(u32, 0b11100000000000);
        self.regs.config = conf;
        self.regs.adminQueueAttr = (@as(u32, (4096 / @sizeOf(NVMeCompletionEntry)) - 1) << 16) | ((4096 / @sizeOf(NVMeSubmitEntry)) - 1);
        self.adminQueue.completeQueue.addr = DriverInfo.krnlDispatch.?.pfnAlloc(false);
        self.adminQueue.submitQueue.addr = DriverInfo.krnlDispatch.?.pfnAlloc(false);
        self.regs.adminCplQueueBase = @intFromPtr(self.adminQueue.completeQueue.addr) - 0xffff800000000000;
        self.regs.adminSubQueueBase = @intFromPtr(self.adminQueue.submitQueue.addr) - 0xffff800000000000;
        self.regs.config = self.regs.config | 1;
        while ((self.regs.status & 3) == 0) {
            std.atomic.spinLoopHint();
        }
        if ((self.regs.status & 2) != 0) {
            DriverInfo.krnlDispatch.?.abort("Failed to initialize NVMe Controller!");
            return;
        }
        self.regs.intMaskClear = 0xffffffff;
        // NVMe Controller was successfully reset!
        self.maxQueue = (self.regs.caps & 0xFFFF) + 1;
        self.doorbellStride = (((self.regs.caps) >> 32) & 0xf);
        self.adminQueue.completeQueue.entryCount = 4096 / @sizeOf(NVMeCompletionEntry);
        self.adminQueue.submitQueue.entryCount = 4096 / @sizeOf(NVMeSubmitEntry);
        self.adminQueue.submitQueue.doorbell = @as(*align(1) volatile u32, @ptrFromInt(@intFromPtr(self.regs) + 0x1000 + (0 * 2) * (@as(usize, 4) << @intCast(self.doorbellStride))));
        self.adminQueue.completeQueue.doorbell = @as(*align(1) volatile u32, @ptrFromInt(@intFromPtr(self.regs) + 0x1000 + (0 * 2 + 1) * (@as(usize, 4) << @intCast(self.doorbellStride))));
        self.adminQueue.submitQueue.doorbell.* = 0;
        self.adminQueue.completeQueue.doorbell.* = 0;
        self.adminQueue.currentPhase = 1;
        const conAddr = @intFromPtr(DriverInfo.krnlDispatch.?.staticAllocAnon(4096));
        _ = self.Identify(@as([*]u8, @ptrFromInt(conAddr))[0..4096], 1, 0);
        self.contID = @ptrFromInt(conAddr);
        DriverInfo.krnlDispatch.?.put("Serial Number: \"");
        DriverInfo.krnlDispatch.?.putRaw(@as([*c]u8, @ptrCast(&self.contID.serialNumber)), 20);
        DriverInfo.krnlDispatch.?.put("\", Name: \"");
        DriverInfo.krnlDispatch.?.put(@as([*c]const u8, @ptrCast(&self.contID.name)));
        DriverInfo.krnlDispatch.?.put("\" with ");
        DriverInfo.krnlDispatch.?.putNumber(self.contID.numNamespaces, 10, false, ' ', 0);
        DriverInfo.krnlDispatch.?.put(" namespace(s), and a maximum of ");
        DriverInfo.krnlDispatch.?.putNumber(self.maxQueue, 10, false, ' ', 0);
        DriverInfo.krnlDispatch.?.put(" queues\n");
        _ = self.SubmitAndWait(NVMeSubmitEntry{
            .d0 = NVMeSubmitDWord{
                .opcode = 0x9,
            },
            .command = .{ 0x80, 0, 0, 0, 0, 0 },
        }, &self.adminQueue);
        var i: u32 = 0;
        var first: bool = true;
        var entries: usize = 0;
        while (i < self.contID.numNamespaces) : (i += 1) {
            const namespace: *NVMeNamespaceID = @alignCast(@ptrCast(DriverInfo.krnlDispatch.?.staticAllocAnon(4096)));
            if (!self.Identify(@as([*]u8, @alignCast(@ptrCast(namespace)))[0..4096], 0, i + 1)) {
                DriverInfo.krnlDispatch.?.staticFreeAnon(@as(*void, @ptrCast(namespace)), 4096);
            } else {
                const nsEntry = NVMeNamespace{
                    .drive = self,
                    .nsID = i + 1,
                    .id = namespace,
                    .blockSize = @as(u64, 1) << @as(u6, @intCast(namespace.lbaFormat[namespace.fmtLbaSize & 0xf].lbaDataSize)),
                    .blocks = namespace.lbaCapacity,
                };
                if (nsEntry.blocks == 0) {
                    DriverInfo.krnlDispatch.?.staticFreeAnon(@as(*void, @ptrCast(namespace)), 4096);
                    continue;
                }
                DriverInfo.krnlDispatch.?.put("Namespace #");
                DriverInfo.krnlDispatch.?.putNumber(i + 1, 10, false, ' ', 0);
                DriverInfo.krnlDispatch.?.put(": ");
                DriverInfo.krnlDispatch.?.putNumber(nsEntry.blocks, 10, false, ' ', 0);
                DriverInfo.krnlDispatch.?.put(" blocks (");
                DriverInfo.krnlDispatch.?.putNumber(nsEntry.blockSize, 10, false, ' ', 0);
                DriverInfo.krnlDispatch.?.put(" bytes per block)\n");
                entries += 1;
                if (first) {
                    var newNs = @as([*]NVMeNamespace, @ptrCast(@alignCast(DriverInfo.krnlDispatch.?.staticAlloc(@sizeOf(NVMeNamespace)))))[0..1];
                    newNs[0] = nsEntry;
                    self.namespaces = newNs;
                    first = false;
                } else {
                    var newNs = @as([*]NVMeNamespace, @ptrCast(@alignCast(DriverInfo.krnlDispatch.?.staticAlloc(@sizeOf(NVMeNamespace) * (self.namespaces.len + 1)))))[0 .. self.namespaces.len + 1];
                    var j: usize = 0;
                    while (j < self.namespaces.len) : (j += 1) {
                        newNs[j] = self.namespaces[j];
                    }
                    newNs[self.namespaces.len] = nsEntry;
                    DriverInfo.krnlDispatch.?.staticFree(@as(*void, @ptrCast(self.namespaces)), self.namespaces.len * @sizeOf(NVMeNamespace));
                    self.namespaces = newNs;
                }
            }
        }
        i = 0;
        while (i < entries) : (i += 1) {
            self.namespaces[i].Init();
        }
    }
};

var driveHead: ?*NVMeDrive = null;

pub fn NVMeIRQ(irq: u16) callconv(.C) void {
    _ = irq;
    var drive = driveHead;
    while (drive != null) {
        drive.?.adminQueue.completeQueue.event = true;
        var i: usize = 0;
        while (i < drive.?.namespaces.len) : (i += 1) {
            drive.?.namespaces[i].queue.completeQueue.event = true;
        }
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
                drive.nextID = 1;
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
