# Raven Kernel System Calls

- ## `Filesystem, Group 0x00`
    -   |    SystemCallID    |    SystemCallName    |   Arg1   |   Arg2  |     Arg3    | Ret |
        | ------------------ | -------------------- | -------- | ------- | ----------- | --- |
        |       `0x00`       | **Reserved**         |          |         |             |     |
        |       `0x01`       | `open`               | Path     | Length  | Mode        | FD  |
        |    `0x----##02`    | `foperation`         | FD       | Arg1    | Arg2        |     |
        | ***`0x0001##02`*** | ***`read`***         | FD       | Buf     | Length      |     |
        | ***`0x0002##02`*** | ***`write`***        | FD       | Buffer  | Length      |     |
        | ***`0x0003##02`*** | ***`lseek`***        | FD       | Offset  | Whence      |     |
        | ***`0x0004##02`*** | ***`ftruncate`***    | FD       | Length  |             |     |
        | ***`0x0005##02`*** | ***`close`***        | FD       |         |             |     |
        | ***`0x0006##02`*** | ***`fchmod`***       | FD       | Mode    |             |     |
        | ***`0x0007##02`*** | ***`fchown`***       | FD       | UID     | GID         |     |
        | ***`0x0008##02`*** | ***`frename`***      | FD       | Path    | Length      |     |
        | ***`0x0009##02`*** | ***`fstat`***        | FD       | Buffer  |             |     |
        | ***`0x000a##02`*** | ***`fsync`***        | FD       |         |             |     |
        | ***`0x000b##02`*** | ***`fnctl`***        | FD       | Command | Arg         | Ret |
        | ***`0x000c##02`*** | ***`futimens`***     | FD       | Seconds | NanoSeconds |     |
        |       `0x03`       | `unlink`             | Path     | Length  |             |     |
        |       `0x04`       | `dup`                | OldFD    |         |             | FD  |
        |       `0x05`       | `dup2`               | OldFD    | NewFD   |             |     |
        |       `0x06`       | `chdir`              | Path     | Length  |             |     |
        |       `0x07`       | `getcwd`             | PathBuf  | Length  |             |     |
- ## `Process, Group 0x01`
    -   | SystemCallID | SystemCallName |   Arg1  |    Arg2   | Arg3 |    Ret    |
        | ------------ | -------------- | ------- | --------- | ---- | --------- |
        |    `0x00`    | `yield`        |         |           |      |           |
        |    `0x01`    | `exit`         | Status  |           |      |           |
        |    `0x02`    | `clone`        | Stack   | Flags     |      | PID       |
        |    `0x03`    | `getpid`       |         |           |      | PID       |
        |    `0x04`    | `getppid`      |         |           |      | PPID      |
        |    `0x05`    | `fexec`        | FD      | Args      | Len  |           |
        |    `0x06`    | `brk`          | Address |           |      |           |
        |    `0x07`    | `kill`         | PID     | Signal    |      |           |
        |    `0x08`    | `waitpid`      | PID     | -> Status |      |           |
        |    `0x09`    | `umask`        | Mask    |           |      |           |
- ## `Privileges, Group 0x02`
    -   | SystemCallID | SystemCallName |   Arg1  |    Arg2   | Arg3 |    Ret    |
        | ------------ | -------------- | ------- | --------- | ---- | --------- |
        
---

****`Italicized`*** system calls indicate that it's not a real system call 
but rather one of the calls that the system call can do.<br>
*****`##`*** is a placeholder representing the group number