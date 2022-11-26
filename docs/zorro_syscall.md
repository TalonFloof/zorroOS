# System Call List for the Zorro Kernel

---
## `ZorroObjectCreate`
```c
uint64_t ZorroObjectCreate(
    uint64_t type, 
    ...arguments);
```

```
Syscall ID: 0x44df433d6ec2cfad
-----
Description:
Creates a new object.
If successful, the return value should be the handle ID of the object that
was just created.
```

---
## `ZorroObjectGrant`

```c
uint64_t ZorroObjectGrant(
    ThreadHandle thread, 
    VoidHandle handle, 
    uint64_t rights);
```

```
Syscall ID: 0xc9969df620c3641d
-----
Description:
Grant a thread the privilage to use a handle if the set right flags are
also set on the target thread. (If 0 the condition will always pass)
```

---
## `ZorroObjectReference`

```c
uint64_t ZorroObjectReference(VoidHandle handle);
```

```
Syscall ID: 0x890074221b7afef4
-----
Description:
Creates a new handle to the object pointed by the given handle.
```

---
## `ZorroObjectDereference`

```c
uint64_t ZorroObjectDereference(VoidHandle handle);
```

```
Syscall ID: 0x06756960036071ae
-----
Description:
Destroys the given handle. If all handles of an object are destroyed,
the object is also destroyed.
```
---
## `ZorroMemoryMap`

```c
uint64_t ZorroMemoryMap(
    MemoryHandle mem,
    MemorySpaceHandle memspace,
    uintptr_t memoffset,
    uintptr_t memlength,
    uintptr_t spacevaddr
    );
```

```
Syscall ID: 0x6c3ff70006c53045
-----
Description:
Maps the given memory object to the given memory space.
The offset and length within the ZorroMemory object is what is mapped
to the virtual address within the ZorroMemorySpace object.
```
---
## `ZorroMemoryUnmap`

```c
uint64_t ZorroMemoryUnmap(
    MemorySpaceHandle handle,
    uintptr_t vaddr,
    uintptr_t size
    );
```

```
Syscall ID: 0x8ba9170c530e1f25
-----
Description:
Unmaps the given range of memory from the given memory space
```
---
## `ZorroThreadBeginExecution`

```c
uint64_t ZorroThreadBeginExecution(
    ThreadHandle handle,
    uint64_t ip,
    uint64_t sp,
    uint64_t args[4]
    );
```

```
Syscall ID: 0x6578036eaf605a13
-----
Description:
Begins execution of the given thread using the given parameters
and intruction pointer.
```
---
## `ZorroThreadExit`

```c
uint64_t ZorroThreadExit(
    ThreadHandle handle,
    uint64_t exitcode
    );
```

```
Syscall ID: 0x136b091b5d834bf4
-----
Description:
Exits the thread with the given exit code.
Any threads waiting for the given thread to exit will recieve
the given exit code.
```
---