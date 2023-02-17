# The Design of zorroOS
## Initial Startup
The Owl Microkernel when first initialized, starts up a short boot procedure. Architecture specific initializion is preformed, and then the splash text is printed out to the debug console. After this, the rest of the architecture initialization is preformed (if there is any). Note that it is required to start up all Harts (Hardware Threads) in order for the Alpha Server to implement an SMP (Symmetric Multiprocessing) based scheduler. We then search for a bootable RAM Disk containing the Alpha Server. The Alpha Server is required in order for the rest of the operating system to properly function. If there is a RAM Disk containing the Alpha Server, then Hart #0 will hand over full control to it. The other Harts will be running Thread #0 (the Idle Thread).
## The Alpha Server
The Owl Microkernel is designed to have as little within the kernel as possible. Because of this the following things which you would find in a traditional UNIX-based Monolithic Kernel (Linux for instance) won't be found in the Owl Microkernel:
- File System Management
- IPC (This is abnormal compared to other microkernels)
- Device Drivers

This now brings up the question of what system calls are actually available to the user to allow them to do things like create threads, allocate memory, etc.
Well, it's simple. There's one system call and here it is:
```
OwlInvokeObjectMethod:
    Arguments:
        a0: Object ID
        a1: Function ID
        a2-a7: Arguments
    Output:
        a0: Result Code
        a2-a7: Output
    Description:
        Invokes a method defined within an object. This only works if the current thread is allowed to access the object.
        This system call can fail if the current thread doesn't have a/the privilage(s) that the method requires.
    Result Codes:
        >0: User Defined
        0: Success
        -1: Segmentation Fault
        -2: Object Access Denied or No Object
        -3: Missing Privilege Tag
        -4: Invalid Function ID
        <-4: User Defined
```
Okay, so how are you going to create threads then, and stuff, if this is the only system call? "The Superobject," that's how.
### The Superobject
All threads running under the Owl Kernel are allowed to access Object #1. This object is a very special object called the Superobject.
The Superobject allows you to both **create objects of an existing type**, but most importantly **CREATE NEW OBJECT TYPES**.
This is where the design of the Owl Microkernel becomes more interesting. You are allowed to define new object types using the superobject, and you can attach new methods to them. Attaching methods and calling them acts as a sort of primitive RPC (Remote Procedure Call) without having to design a protocol for each server. It works by switching to the address space of the thread which implements the method (but the context is completely different from the normal thread context). It then handles the method, and returns the data from it. This leads to **less latency compared to traditional microkernels**. Also, if an error occurs, it simply returns the Segmentation Fault status, and the thread continues to run.

---
So what does the Alpha Server actually do then? Well it starts up the other servers defined within the RAM Disk, and then lets the other servers do the work. This then bootstraps the entire operating system.

# Owl Kernel Object Calls
## Superobject
| Function ID |     Name     | Requirements  | Arguments | Description |
|-------------|--------------|---------------|-----------|-------------|
| 0x00000000 | CreateObject | The tag <code>OwlObj&nbsp;&nbsp;</code> | `typeID arg1 arg2 arg3 arg4 arg5 \| objID` | Create an object of a given object type, the meaning of the arguments passed depends on the object type. |
| 0x00000001  | CreateObjType | The tag `OwlDfObj` | `typeID objSize` | Creates a new object type. The objSize field will be used to determine the size of the object's data. This data can be accessed using `ObjDataAccess`. |
| 0x00000002  | ObjDataAccess | The thread must be the one that created the object type | `objID op offset data \| data` | Reads or writes data from the given object.<br>**Note**<br>`0-3: Read Byte/Short/Int/Long 4-7: Write Byte/Short/Int/Long` |
| 0x00000003  | ObjAttachMethod | The thread must be the one that created the object type | `typeID funcID handlePtr` | Adds a method to an existing object type. The `handlePtr` will be the function which is called when the method is triggered. If the pointer is null, than the method will be detached. <br>**Note**<br>Please ensure that the method is thread-safe. This will prevent race conditions from occurring, which can lead to unpredictable behavior. |
| 0x00000010 | ThreadHasTag | The tag <code>OwlThrd&nbsp;</code> | `objID tag \| hasTag` | Returns a 1 if the given thread has the given tag.<br>**Note**<br>This is not implemented in the Thread Object because this method bypasses the kernel's permission check. |
## All Objects
| Function ID |     Name     | Requirements  | Arguments | Description |
|-------------|--------------|---------------|-----------|-------------|
| 0xfffffffe  | ObjDereference | The tag <code>OwlObj&nbsp;&nbsp;</code> | None | Dereferences the current object. This will destroy all references to it.
| 0xffffffff | MethodReturn | The current hart's method call stack must have a length greater than 0 | `statusCode ret1 ret2 ret3 ret4 ret5` | Returns from a method. The Owl Kernel uses a call stack, so nested object calls are allowed. |

# This document is a work in progress!