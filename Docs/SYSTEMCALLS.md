# Fox Kernel System Calls
| Name (SC0)                  | SC1                      | SC2                 | SC3             | Return                                    |
|-----------------------------|--------------------------|---------------------|-----------------|-------------------------------------------|
| yield (`0x00`)              |                          |                     |                 | `Always 0`                                |
| exit (`0x01`)               | `Exit Code`              |                     |                 | `None (Process dies after this)`          |
| fork (`0x02`)               | `IsThread`               |                     |                 | `Parent: Process ID, Child: 0`            |
| open (`0x03`)               | `Name: CStr`             | `Mode`              |                 | `FileDescriptor on success`               |
| close (`0x04`)              | `FileDescriptor`         |                     |                 | `0 on success`                            |
| read (`0x05`)               | `FileDescriptor`         | `BufBase`           | `ReadSize`      | `Number of bytes read, on success`        |
| write (`0x06`)              | `FileDescriptor`         | `BufBase`           | `WriteSize`     | `Number of bytes written, on success`     |
| lseek (`0x07`)              | `FileDescriptor`         | `Offset`            | `Whence`        | `Location from file start, on success`    |
| dup (`0x08`)                | `OldFileDescriptor`      | `NewFileDescriptor` |                 | `NewFD on success`                        |
| Reserved (`0x09`)           |                          |                     |                 |                                           |
| unlink (`0x0a`)             | `Name: CStr`             |                     |                 | `0 on success`                            |
| creat (`0x0b`)              | `Name: CStr`             | `Mode`              |                 | `FD unless O_DIRECTORY is set, 0 if set`  |
| stat (`0x0c`)               | `Name: CStr`             | `ModeBuf`           |                 | `0 on success`                            |
| fstat (`0x0d`)              | `FileDescriptor`         | `ModeBuf`           |                 | `0 on success`                            |
| access (`0x0e`)             | `Name: CStr`             | `Mode`              |                 | `0 if accessible`                         |
| chmod (`0x0f`)              | `Name: CStr`             | `Mode`              |                 | `0 on success`                            |
| chown (`0x10`)              | `Name: CStr`             | `UID`               | `GID`           | `0 on success`                            |
| umask (`0x11`)              | `NewUMask`               |                     |                 | `OldUMask, never fails`                   |
| ioctl (`0x12`)              | `FileDescriptor`         | `Request`           | `Arg`           | `No standard, depends on FD & SC2 Value`  |
| execve (`0x13`)             | `Name: CStr`             | `ArgV: &[CStr]`     | `EnvP: &[CStr]` | `No return on success`                    |
| waitpid (`0x14`)            | `PID`                    | `WStatus: &u32`     | `Options`       | `ChildPID on child process termination`   |
| getuid (`0x15`)             |                          |                     |                 | `RealUID, never fails`                    |
| geteuid (`0x16`)            |                          |                     |                 | `EffectiveUID, never fails`               |
| getgid (`0x17`)             |                          |                     |                 | `RealGID, never fails`                    |
| getegid (`0x18`)            |                          |                     |                 | `EffectiveGID, never fails`               |
| getpid (`0x19`)             |                          |                     |                 | `PID, never fails`                        |
| getppid (`0x1a`)            |                          |                     |                 | `ParentPID, never fails`                  |
| setpgid (`0x1b`)            | `PID`                    | `ProcessGroup`      |                 | `0 on success`                            |
| getpgrp (`0x1c`)            |                          |                     |                 | `ProcessGroup, never fails, POSIX.1 ver.` |
| signal (`0x1d`)             | `SignalID`               | `SigHandler`        |                 | `OldSigHandler on success`                |
| kill (`0x1e`)               | `PID`                    | `SignalID`          |                 | `0 on success`                            |
| Reserved (`0x1f`)           |                          |                     |                 |                                           |
| nanosleep (`0x20`)          | `Seconds`                | `Microseconds`      |                 | `0 on success (uninterruptible)`          |
| chdir (`0x21`)              | `Path: CStr`             |                     |                 | `0 on success`                            |
| pipe (`0x22`)               | `Pipes: &mut [isize; 2]` |                     |                 | `0 on success, Pipes will contain FDs`    |
| sbrk (`0x23`)               | `Increment`              |                     |                 | `Previous heap end on success`            |
| Unused (`0x24-0xef`)        |                          |                     |                 |                                           |
| foxkernel_powerctl (`0xf0`) | `Command`                |                     |                 | `0 on success, ENOENT if not supported`   |
| Unused (`0xf1-0xff`)        |                          |                     |                 |                                           |