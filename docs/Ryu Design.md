# Ryu Kernel Design
**Author: TalonFox    
First Draft  
CURRENTLY IMCOMPLETE**

## Table of Contents
- [Section 1 - Kernel Overview](#kernel-overview)
- [Section 2 - System Startup](#system-startup)
- [Section 3 - Hardware Abstraction Layer](#hardware-abstraction-layer)
- [Section 4 - Memory Management](#memory-management)
- [Section 5 - Interrupts](#interrupts)
- [Section 6 - Objects](#objects)
- [Section 7 - Driver I/O](#driver-io)
- [Section 8 - Multitasking and Scheduling](#multitasking-and-scheduling)
## Pseudocode
All routines within the **Ryu Design** documentation use a special pseudocode to represent the actual code which will be ran within the **Ryu Kernel**.  
An example of the syntax can be seen within this code sniplet:
```lua
fn ExampleRoutine(
    arg1: u8;
    arg2: *void;
    arg3, arg4: usize;
    arg5: [5]u32;
): u64;
    if 1 == 1 then
        while *arg2 ~= 0 then
            arg2 += 1
        end
    end
    for i=1,5 do
        HALConsolePut("Hello!\n")
    end
    return (2**32)-1 -- This is an example comment
end
ExampleRecord = record
    prev, next: *ExampleRecord;
    data: usize;
    valid, readwrite: u1;
    reserved: u6;
end
ExampleEnum = enum usize
    Red, Green, Blue
end
```
<br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br>

## **Kernel Overview**
This specification describes the kernel layer of the **zorroOS** operating system. The kernel is responsible for thread dispatching,  **hart** synchronization, hardware exception handling, and the implementation of low-level machine dependent functions.  
The kernel is then further abstracted by the **Ryu Executive** which provides high-level abstractions to userspace (via userspace APIs).  
Note that the **Ryu Kernel** enforces almost no policies. Policy enforcement is mostly handled by the **Ryu Executive**. However, there are certain situations where the kernel must make policy decisions in order to ensure system stability.  
The **Ryu Kernel** and the **Ryu Executive** (which is part of the kernel) operates within the architecture's **Supervisor Mode**. The kernel also never page swaps its own segments, therefore all kernel segments loaded at boot are within the **Static Pool**.

---
## **System Startup**
The exact startup procedure of the **Ryu Kernel** does vary between the targeted architecture, however this section attempts to give a generalized idea of the full startup procedure.
  
When the bootloader hands over control to the **Ryu Kernel**, we will be executing from the routine `HALPrefromStartup`. Some architectures will run a procedure other than the provided startup routine before running it to setup essential architecture specific things (ex. setup the stack, enable paging, etc.)  
`HALPreformStartup`'s job is to initialize the rest of the kernel. It will first setup essential parts of the architecture's abstractions (obtaining a memory map, startup **harts**, etc.)  
The **HAL Kernel Console** is then setup to allow the kernel to log debug information to the user. After the rest of the **HAL** has been setup, control is then handed over to `RyuInit`. `RyuInit` will then setup the rest of the kernel, which includes the system's memory management, thread team management, non-essential drivers, etc. Control will then be handed over to the executable `ZorroOS` within userspace, which will handle the rest of the startup procedure (including loading kernel modules and setting up the login screen)

---
## **Hardware Abstraction Layer**
The **Hardware Abstraction Layer** is an essential software layer that provides architecture specific abstractions to the **Ryu Kernel**.
### **Routines**
```lua
fn HALPreformStartup(stackTop: usize;): noreturn -- Kernel Entry Point
----------HALConsole----------
HALConsoleFBInfo = record
   ptr: *void;
   width, height, pitch, bpp: usize;
   set: *fn(x, y: isize; w, h, c: usize;);
end
fn HALConsoleInit(info: *HALConsoleFB;)
fn HALConsolePut(--[[Formatted String and Arguments]])
fn HALConsoleEnableDisable(en: bool;)
----------HALArch----------
fn HALArchPreformStartup()
fn HALArchIRQEnableDisable(en: bool;)
fn HALArchHalt(): noreturn
inline fn HALArchWaitForIRQ()
fn HALArchSendIPI(hartID: i32; type: IPIType;) -- Set hartID to -1 to send to all, set to -2 to send to all except ourselves
IPIType = enum usize
    IPIHalt,
    IPIReschedule,
    IPIFlushTLB,
end
fn HALArchGetHart(): *HartData
HALArchContext = record --[[GPR Context]] end
fn HALArchEnterContext(p: *HALArchContext;): noreturn
HALArchFloatContext = record --[[FPR Context]] end
fn HALArchSaveFloat(p: *HALArchFloatContext;)
fn HALArchRestoreFloat(p: *HALArchFloatContext;)
-- TODO: Add Arch-Specific Paging Routines
----------HALCrash----------
fn HALCrash(code: CrashCode;): noreturn
```
---
## **Memory Management**
The memory management subsystem is responsible for the mapping of physical memory into the virtual address space of a thread team. It is also responsible for handling page faults and swapping pages in and out of secondary storage.  
  
### **Design**
When the **HAL** is executed, machine-specific code that is ran via `HALArchPreformStartup` must setup a physical memory map of available memory ranges. This informs the kernel of what memory is allowed to be used for allocations. Up to 32 ranges can be specified. If **HAL** has more than 32, than the 32 largest entries will be used for memory allocations to ensure that the least amount of memory is wasted.  
  
All information relating to the pages that the **Ryu Kernel** can access is stored within the PFN database. This data must be accessable while a page is in use, so it cannot be stored within the page itself. An entry in the database has the following structure:
```lua
PFNEntry = record
    prev, next: *PFNEntry;
    refs: i28;
    state: u3; -- 0: Reserved 1: Free 2: Zeroed 3: Active 4: Transitioning 5: Swapped
    swappable: u1;
    pfe: PageFrame;
end
```
Memory Allocation 
### **Routines**
```lua
```
---