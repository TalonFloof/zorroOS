use crate::arch::Task::State;
use crate::Scheduler::Scheduler;
use crate::CurrentHart;
use crate::Process::{Process,TaskState};
use cstr_core::{c_char,CStr,CString};
use crate::FS::VFS;
use alloc::string::String;
use alloc::vec::Vec;
use alloc::sync::Arc;
use crate::PageFrame::Allocate;

pub mod Errors {
    pub const EPERM: i32 = 1;  /* Operation not permitted */
    pub const ENOENT: i32 = 2;  /* No such file or directory */
    pub const ESRCH: i32 = 3;  /* No such process */
    pub const EINTR: i32 = 4;  /* Interrupted system call */
    pub const EIO: i32 = 5;  /* I/O error */
    pub const ENXIO: i32 = 6;  /* No such device or address */
    pub const E2BIG: i32 = 7;  /* Argument list too long */
    pub const ENOEXEC: i32 = 8;  /* Exec format error */
    pub const EBADF: i32 = 9;  /* Bad file number */
    pub const ECHILD: i32 = 10;  /* No child processes */
    pub const EAGAIN: i32 = 11;  /* Try again */
    pub const ENOMEM: i32 = 12;  /* Out of memory */
    pub const EACCES: i32 = 13;  /* Permission denied */
    pub const EFAULT: i32 = 14;  /* Bad address */
    pub const ENOTBLK: i32 = 15;  /* Block device required */
    pub const EBUSY: i32 = 16;  /* Device or resource busy */
    pub const EEXIST: i32 = 17;  /* File exists */
    pub const EXDEV: i32 = 18;  /* Cross-device link */
    pub const ENODEV: i32 = 19;  /* No such device */
    pub const ENOTDIR: i32 = 20;  /* Not a directory */
    pub const EISDIR: i32 = 21;  /* Is a directory */
    pub const EINVAL: i32 = 22;  /* Invalid argument */
    pub const ENFILE: i32 = 23;  /* File table overflow */
    pub const EMFILE: i32 = 24;  /* Too many open files */
    pub const ENOTTY: i32 = 25;  /* Not a typewriter */
    pub const ETXTBSY: i32 = 26;  /* Text file busy */
    pub const EFBIG: i32 = 27;  /* File too large */
    pub const ENOSPC: i32 = 28;  /* No space left on device */
    pub const ESPIPE: i32 = 29;  /* Illegal seek */
    pub const EROFS: i32 = 30;  /* Read-only file system */
    pub const EMLINK: i32 = 31;  /* Too many links */
    pub const EPIPE: i32 = 32;  /* Broken pipe */
    pub const EDOM: i32 = 33;  /* Math argument out of domain of func */
    pub const ERANGE: i32 = 34;  /* Math result not representable */
    pub const EDEADLK: i32 = 35;  /* Resource deadlock would occur */
    pub const ENAMETOOLONG: i32 = 36;  /* File name too long */
    pub const ENOLCK: i32 = 37;  /* No record locks available */
    pub const ENOSYS: i32 = 38;  /* Function not implemented */
    pub const ENOTEMPTY: i32 = 39;  /* Directory not empty */
    pub const ELOOP: i32 = 40;  /* Too many symbolic links encountered */
    pub const EWOULDBLOCK: i32 = 41;  /* Operation would block */
    pub const ENOMSG: i32 = 42;  /* No message of desired type */
    pub const EIDRM: i32 = 43;  /* Identifier removed */
    pub const ECHRNG: i32 = 44;  /* Channel number out of range */
    pub const EL2NSYNC: i32 = 45;  /* Level 2 not synchronized */
    pub const EL3HLT: i32 = 46;  /* Level 3 halted */
    pub const EL3RST: i32 = 47;  /* Level 3 reset */
    pub const ELNRNG: i32 = 48;  /* Link number out of range */
    pub const EUNATCH: i32 = 49;  /* Protocol driver not attached */
    pub const ENOCSI: i32 = 50;  /* No CSI structure available */
    pub const EL2HLT: i32 = 51;  /* Level 2 halted */
    pub const EBADE: i32 = 52;  /* Invalid exchange */
    pub const EBADR: i32 = 53;  /* Invalid request descriptor */
    pub const EXFULL: i32 = 54;  /* Exchange full */
    pub const ENOANO: i32 = 55;  /* No anode */
    pub const EBADRQC: i32 = 56;  /* Invalid request code */
    pub const EBADSLT: i32 = 57;  /* Invalid slot */
    pub const EDEADLOCK: i32 = 58; /* Resource deadlock would occur */
    pub const EBFONT: i32 = 59;  /* Bad font file format */
    pub const ENOSTR: i32 = 60;  /* Device not a stream */
    pub const ENODATA: i32 = 61;  /* No data available */
    pub const ETIME: i32 = 62;  /* Timer expired */
    pub const ENOSR: i32 = 63;  /* Out of streams resources */
    pub const ENONET: i32 = 64;  /* Machine is not on the network */
    pub const ENOPKG: i32 = 65;  /* Package not installed */
    pub const EREMOTE: i32 = 66;  /* Object is remote */
    pub const ENOLINK: i32 = 67;  /* Link has been severed */
    pub const EADV: i32 = 68;  /* Advertise error */
    pub const ESRMNT: i32 = 69;  /* Srmount error */
    pub const ECOMM: i32 = 70;  /* Communication error on send */
    pub const EPROTO: i32 = 71;  /* Protocol error */
    pub const EMULTIHOP: i32 = 72;  /* Multihop attempted */
    pub const EDOTDOT: i32 = 73;  /* RFS specific error */
    pub const EBADMSG: i32 = 74;  /* Not a data message */
    pub const EOVERFLOW: i32 = 75;  /* Value too large for defined data type */
    pub const ENOTUNIQ: i32 = 76;  /* Name not unique on network */
    pub const EBADFD: i32 = 77;  /* File descriptor in bad state */
    pub const EREMCHG: i32 = 78;  /* Remote address changed */
    pub const ELIBACC: i32 = 79;  /* Can not access a needed shared library */
    pub const ELIBBAD: i32 = 80;  /* Accessing a corrupted shared library */
    pub const ELIBSCN: i32 = 81;  /* .lib section in a.out corrupted */
    pub const ELIBMAX: i32 = 82;  /* Attempting to link in too many shared libraries */
    pub const ELIBEXEC: i32 = 83;  /* Cannot exec a shared library directly */
    pub const EILSEQ: i32 = 84;  /* Illegal byte sequence */
    pub const ERESTART: i32 = 85;  /* Interrupted system call should be restarted */
    pub const ESTRPIPE: i32 = 86;  /* Streams pipe error */
    pub const EUSERS: i32 = 87;  /* Too many users */
    pub const ENOTSOCK: i32 = 88;  /* Socket operation on non-socket */
    pub const EDESTADDRREQ: i32 = 89;  /* Destination address required */
    pub const EMSGSIZE: i32 = 90;  /* Message too long */
    pub const EPROTOTYPE: i32 = 91;  /* Protocol wrong type for socket */
    pub const ENOPROTOOPT: i32 = 92;  /* Protocol not available */
    pub const EPROTONOSUPPORT: i32 = 93;  /* Protocol not supported */
    pub const ESOCKTNOSUPPORT: i32 = 94;  /* Socket type not supported */
    pub const EOPNOTSUPP: i32 = 95;  /* Operation not supported on transport endpoint */
    pub const EPFNOSUPPORT: i32 = 96;  /* Protocol family not supported */
    pub const EAFNOSUPPORT: i32 = 97;  /* Address family not supported by protocol */
    pub const EADDRINUSE: i32 = 98;  /* Address already in use */
    pub const EADDRNOTAVAIL: i32 = 99;  /* Cannot assign requested address */
    pub const ENETDOWN: i32 = 100; /* Network is down */
    pub const ENETUNREACH: i32 = 101; /* Network is unreachable */
    pub const ENETRESET: i32 = 102; /* Network dropped connection because of reset */
    pub const ECONNABORTED: i32 = 103; /* Software caused connection abort */
    pub const ECONNRESET: i32 = 104; /* Connection reset by peer */
    pub const ENOBUFS: i32 = 105; /* No buffer space available */
    pub const EISCONN: i32 = 106; /* Transport endpoint is already connected */
    pub const ENOTCONN: i32 = 107; /* Transport endpoint is not connected */
    pub const ESHUTDOWN: i32 = 108; /* Cannot send after transport endpoint shutdown */
    pub const ETOOMANYREFS: i32 = 109; /* Too many references: cannot splice */
    pub const ETIMEDOUT: i32 = 110; /* Connection timed out */
    pub const ECONNREFUSED: i32 = 111; /* Connection refused */
    pub const EHOSTDOWN: i32 = 112; /* Host is down */
    pub const EHOSTUNREACH: i32 = 113; /* No route to host */
    pub const EALREADY: i32 = 114; /* Operation already in progress */
    pub const EINPROGRESS: i32 = 115; /* Operation now in progress */
    pub const ESTALE: i32 = 116; /* Stale NFS file handle */
    pub const EUCLEAN: i32 = 117; /* Structure needs cleaning */
    pub const ENOTNAM: i32 = 118; /* Not a XENIX named type file */
    pub const ENAVAIL: i32 = 119; /* No XENIX semaphores available */
    pub const EISNAM: i32 = 120; /* Is a named type file */
    pub const EREMOTEIO: i32 = 121; /* Remote I/O error */
    pub const EDQUOT: i32 = 122; /* Quota exceeded */
    pub const ENOMEDIUM: i32 = 123; /* No medium found */
    pub const EMEDIUMTYPE: i32 = 124; /* Wrong medium type */
    pub const ECANCELED: i32 = 125; /* Operation Canceled */
    pub const ENOKEY: i32 = 126; /* Required key not available */
    pub const EKEYEXPIRED: i32 = 127; /* Key has expired */
    pub const EKEYREVOKED: i32 = 128; /* Key has been revoked */
    pub const EKEYREJECTED: i32 = 129; /* Key was rejected by service */
    pub const EOWNERDEAD: i32 = 130; /* Owner died */
    pub const ENOTRECOVERABLE: i32 = 131; /* State not recoverable */
}

pub mod OpenFlags {
    pub const O_ACCMODE: usize   = 0x0007;
    pub const O_EXEC: usize      = 1;
    pub const O_RDONLY: usize    = 2;
    pub const O_RDWR: usize      = 3;
    pub const O_SEARCH: usize    = 4;
    pub const O_WRONLY: usize    = 5;
    pub const O_APPEND: usize    = 0x0008;
    pub const O_CREAT: usize     = 0x0010;
    pub const O_DIRECTORY: usize = 0x0020;
    pub const O_EXCL: usize      = 0x0040;
    pub const O_NOCTTY: usize    = 0x0080;
    pub const O_NOFOLLOW: usize  = 0x0100;
    pub const O_TRUNC: usize     = 0x0200;
    pub const O_NONBLOCK: usize  = 0x0400;
    pub const O_DSYNC: usize     = 0x0800;
    pub const O_RSYNC: usize     = 0x1000;
    pub const O_SYNC: usize      = 0x2000;
    pub const O_CLOEXEC: usize   = 0x4000;
    pub const O_PATH: usize      = 0x8000;
}

#[repr(packed)]
#[allow(dead_code)]
pub struct DirEntry {
    inode_id: i64,
    offset: i64,
    length: i64,
    file_type: i64,
}

#[repr(C)]
pub struct MmapStruct {
    addr: usize,
    size: usize,
    prot: usize,
    flags: usize,
    fd: usize,
    offset: isize,
}

#[allow(dead_code)]
const MAP_PRIVATE: usize = 0x1;
#[allow(dead_code)]
const MAP_SHARED: usize = 0x2;
const MAP_FIXED: usize = 0x4;
const MAP_ANONYOMUS: usize = 0x8;

pub fn SystemCall(regs: &mut State) {
    let curproc = Scheduler::CurrentPID();
    match regs.GetSC0() {
        0x00 => { // yield
            Scheduler::Tick(CurrentHart(),regs);
            panic!("You'll never see this message, isn't that weird?");
        }
        0x01 => { // exit
            if curproc == 1 {
                panic!("Init Died. If execution continued, all processess would be killed anyway.\nStatus Code: 0x{:02x}", regs.GetSC1());
            }
            let mut plock = crate::Process::PROCESSES.lock();
            let proc = plock.get_mut(&curproc).unwrap();
            proc.status = crate::Process::ProcessStatus::FINISHING((regs.GetSC1() as isize).abs());
            drop(plock);
            Scheduler::Tick(CurrentHart(),regs);
        }
        0x02 => { // fork
            let mut plock = crate::Process::PROCESSES.lock();
            let proc = plock.get_mut(&curproc).unwrap();
            if regs.GetSC1() == 0 {proc.task_state.Save(regs);}
            let forked_proc = Process::Fork(proc,regs.GetSC2());
            let forked_ip = if regs.GetSC1() > 0 {regs.GetSC1()} else {forked_proc.task_state.GetIP()};
            let forked_sp = if regs.GetSC2() > 0 {regs.GetSC2()} else {if regs.GetSC1() > 0 {0x8000_0000_0000-8} else {forked_proc.task_state.GetSP()}};
            drop(plock);
            let val = Process::AddProcess(forked_proc);
            if val > 0 {
                Process::StartProcess(val,forked_ip,forked_sp);
            }
            regs.SetSC0(val as usize);
        }
        0x03 => { // open
            let mut plock = crate::Process::PROCESSES.lock();
            let proc = plock.get_mut(&curproc).unwrap();
            let path = unsafe {CStr::from_ptr(regs.GetSC1() as *const c_char)}.to_str();
            let mut mode = regs.GetSC2();
            if path.is_err() {
                regs.SetSC0((-Errors::EINVAL as isize) as usize);
                drop(plock);
                return;
            }
            if mode & 7 == 0 || mode & 7 == 1 || mode & 7 == 4 {
                mode = (mode & !7) | OpenFlags::O_RDONLY;
            }
            if mode & OpenFlags::O_CREAT != 0 {
                let abspath = VFS::GetAbsPath(path.ok().unwrap(),proc.cwd.as_str());
                let file = VFS::LookupPath(abspath.as_str());
                if file.is_err() {
                    let mut parent: Vec<_> = abspath.split("/").filter(|e| *e != "" && *e != ".").collect();
                    let name = parent.pop().unwrap();
                    let parinode = VFS::LookupPath([String::from("/"),parent.join("/")].join("").as_str());
                    if parinode.is_err() {
                        regs.SetSC0((-parinode.err().unwrap() as isize) as usize);
                        drop(plock);
                        return;
                    }
                    let inode = parinode.ok().unwrap().Creat(name,(if mode & 0x0020 == OpenFlags::O_DIRECTORY {0o0040000 | (0o777 & !proc.umask as usize)} else {0o666 & !proc.umask as usize}) as i32);
                    if inode.is_err() {
                        regs.SetSC0((-inode.err().unwrap() as isize) as usize);
                        drop(plock);
                        return;
                    }
                    inode.ok().unwrap().ChOwn(proc.euid as i32,proc.egid as i32);
                }
            }
            let file = VFS::LookupPath(VFS::GetAbsPath(path.ok().unwrap(),proc.cwd.as_str()).as_str());
            if file.is_err() {
                regs.SetSC0((-file.err().unwrap() as isize) as usize);
                drop(plock);
                return;
            }
            let metadata = file.as_ref().ok().unwrap().Stat().ok().unwrap();
            if !VFS::HasPermission(&metadata,proc.euid,proc.egid,proc.supgroups.as_ref(),if mode & 1 == 1 {0b10} else {0} | if mode & 2 == 2 {0b100} else {0}) && metadata.mode & 0o0170000 != 0 {
                regs.SetSC0((-Errors::EACCES as isize) as usize);
                drop(plock);
                return;
            }
            // We can finally create the File Descriptor!
            let len = if proc.fds.keys().last().is_some() {(*proc.fds.keys().last().unwrap())+1} else {0};
            file.as_ref().ok().unwrap().Open(mode);
            proc.fds.insert(len,VFS::FileDescriptor {
                inode: file.ok().unwrap(),
                path: VFS::GetAbsPath(path.ok().unwrap(),proc.cwd.as_str()),
                offset: 0,
                mode,
                is_dir: metadata.mode & 0o0040000 != 0,
                close_on_exec: mode & OpenFlags::O_CLOEXEC != 0,
            });
            regs.SetSC0(len as usize);
            drop(plock);
        }
        0x04 => { // close
            let mut plock = crate::Process::PROCESSES.lock();
            let proc = plock.get_mut(&curproc).unwrap();
            let fd = proc.fds.get_mut(&(regs.GetSC1() as i64));
            if fd.is_none() {
                drop(plock);
                regs.SetSC0((-Errors::EBADF) as usize);
                return;
            }
            fd.as_ref().unwrap().inode.Close();
            proc.fds.remove(&(regs.GetSC1() as i64));
            regs.SetSC0(0);
            drop(plock);
        }
        0x05 => { // read
            let mut plock = crate::Process::PROCESSES.lock();
            let proc = plock.get_mut(&curproc).unwrap();
            let mut fd = proc.fds.get_mut(&(regs.GetSC1() as i64));
            let buf = unsafe {core::slice::from_raw_parts_mut(regs.GetSC2() as *mut u8, regs.GetSC3())};
            if fd.is_none() {
                drop(plock);
                regs.SetSC0((-Errors::EBADF) as usize);
                return;
            }
            if fd.as_ref().unwrap().mode & 7 != 3 && fd.as_ref().unwrap().mode & 7 != 2 {
                drop(plock);
                regs.SetSC0((-Errors::EBADF) as usize);
                return;
            }
            if fd.as_ref().unwrap().is_dir {
                let result = fd.as_ref().unwrap().inode.ReadDir(fd.as_ref().unwrap().offset as usize);
                if result.is_err() {
                    regs.SetSC0((-(result.err().unwrap() as isize)) as usize);
                    drop(plock);
                    return;
                }
                if result.as_ref().is_ok() {
                    if result.as_ref().ok().unwrap().is_some() {
                        if buf.len() < 33+result.as_ref().ok().unwrap().as_ref().unwrap().GetName().ok().unwrap().len() {
                            drop(plock);
                            regs.SetSC0(0);
                            return;
                        }
                    }
                }
                match result.ok().unwrap() {
                    Some(inode) => {
                        fd.as_mut().unwrap().offset += 1;
                        let name = CString::new(inode.GetName().ok().unwrap()).ok().unwrap();
                        let entry = DirEntry {
                            inode_id: inode.Stat().ok().unwrap().inode_id,
                            offset: fd.as_ref().unwrap().offset,
                            length: ((&name).as_bytes_with_nul().len()+32) as i64,
                            file_type: 0,
                        };
                        unsafe {core::ptr::copy(&entry as *const _ as *const u8, regs.GetSC2() as *mut u8,32);}
                        unsafe {core::ptr::copy(name.as_bytes_with_nul().as_ptr(), (regs.GetSC2()+32) as *mut u8,name.as_bytes_with_nul().len());}
                        regs.SetSC0(entry.length as usize);
                        drop(plock);
                        return;
                    }
                    _ => {
                        regs.SetSC0(0);
                        drop(plock);
                        return;
                    }
                }
            } else {
                let res = fd.as_ref().unwrap().inode.Read(fd.as_ref().unwrap().offset,buf);
                if res < 0 {
                    drop(plock);
                    regs.SetSC0(res as usize);
                    return;
                }
                fd.unwrap().offset += res as i64;
                regs.SetSC0(res as usize);
                drop(plock);
            }
        }
        0x06 => { // write
            let mut plock = crate::Process::PROCESSES.lock();
            let proc = plock.get_mut(&curproc).unwrap();
            let fd = proc.fds.get_mut(&(regs.GetSC1() as i64));
            let buf = unsafe {core::slice::from_raw_parts(regs.GetSC2() as *const u8, regs.GetSC3())};
            if fd.is_none() {
                drop(plock);
                regs.SetSC0((-Errors::EBADF) as usize);
                return;
            }
            if fd.as_ref().unwrap().mode & 7 != 3 && fd.as_ref().unwrap().mode & 7 != 5 {
                drop(plock);
                regs.SetSC0((-Errors::EBADF) as usize);
                return;
            }
            if fd.as_ref().unwrap().is_dir {
                drop(plock);
                regs.SetSC0((-Errors::EINVAL) as usize);
                return;
            }
            let res = fd.as_ref().unwrap().inode.Write(fd.as_ref().unwrap().offset,buf);
            if res < 0 {
                drop(plock);
                regs.SetSC0(res as usize);
                return;
            }
            fd.unwrap().offset += res as i64;
            regs.SetSC0(res as usize);
            drop(plock);
        }
        0x07 => { // lseek
            let mut plock = crate::Process::PROCESSES.lock();
            let proc = plock.get_mut(&curproc).unwrap();
            let mut fd = proc.fds.get_mut(&(regs.GetSC1() as i64));
            if fd.is_none() {
                drop(plock);
                regs.SetSC0((-Errors::EBADF) as usize);
                return;
            }
            let max_size = fd.as_ref().unwrap().inode.Stat().ok().unwrap().size;
            match regs.GetSC3() {
                1 => { // SEEK_CUR
                    fd.as_mut().unwrap().offset += (regs.GetSC2() as isize) as i64;
                }
                2 => { // SEEK_END
                    if fd.as_ref().unwrap().is_dir {
                        drop(plock);
                        regs.SetSC0((-Errors::EINVAL) as usize);
                        return;
                    }
                    fd.as_mut().unwrap().offset = max_size + ((regs.GetSC2() as isize) as i64);
                }
                3 => { // SEEK_SET
                    fd.as_mut().unwrap().offset = (regs.GetSC2() as isize) as i64;
                }
                _ => {
                    drop(plock);
                    regs.SetSC0((-Errors::EINVAL) as usize);
                    return;
                }
            }
            if !fd.as_ref().unwrap().is_dir {
                if fd.as_ref().unwrap().offset < 0 {fd.as_mut().unwrap().offset = 0;} else if fd.as_ref().unwrap().offset > max_size {fd.as_mut().unwrap().offset = max_size;}
            }
            regs.SetSC0(fd.unwrap().offset as usize);
            drop(plock);
        }
        0x08 => { // dup
            let mut plock = crate::Process::PROCESSES.lock();
            let proc = plock.get_mut(&curproc).unwrap();
            let old_fd = proc.fds.get(&(regs.GetSC1() as i64));
            if old_fd.is_none() {
                drop(plock);
                regs.SetSC0((-Errors::EBADF) as usize);
                return;
            }
            if regs.GetSC2() as isize == -1 {
                let len = if proc.fds.keys().last().is_some() {*(proc.fds.keys().last().unwrap())} else {0};
                old_fd.as_ref().unwrap().inode.Open(!0);
                proc.fds.insert(len,VFS::FileDescriptor {
                    inode: old_fd.as_ref().unwrap().inode.clone(),
                    path: old_fd.as_ref().unwrap().path.clone(),
                    offset: old_fd.as_ref().unwrap().offset,
                    mode: old_fd.as_ref().unwrap().mode,
                    is_dir: old_fd.as_ref().unwrap().is_dir,
                    close_on_exec: old_fd.as_ref().unwrap().close_on_exec,
                });
                drop(plock);
                regs.SetSC0(len as usize);
            } else {
                if proc.fds.contains_key(&(regs.GetSC2() as i64)) {
                    drop(plock);
                    regs.SetSC0((-Errors::EBADF) as usize);
                    return;
                }
                old_fd.as_ref().unwrap().inode.Open(!0);
                proc.fds.insert(regs.GetSC2() as i64,VFS::FileDescriptor {
                    inode: old_fd.as_ref().unwrap().inode.clone(),
                    path: old_fd.as_ref().unwrap().path.clone(),
                    offset: old_fd.as_ref().unwrap().offset,
                    mode: old_fd.as_ref().unwrap().mode,
                    is_dir: old_fd.as_ref().unwrap().is_dir,
                    close_on_exec: old_fd.as_ref().unwrap().close_on_exec,
                });
                drop(plock);
                regs.SetSC0(regs.GetSC2());
            }
        }
        0x0a => { // unlink
            let plock = crate::Process::PROCESSES.lock();
            let proc = plock.get(&curproc).unwrap();
            let path = unsafe {CStr::from_ptr(regs.GetSC1() as *const c_char)}.to_str();
            if path.is_err() {
                regs.SetSC0((-Errors::EINVAL as isize) as usize);
                drop(plock);
                return;
            }
            let abspath = VFS::GetAbsPath(path.ok().unwrap(),proc.cwd.as_str());
            let mut parent: Vec<_> = abspath.split("/").filter(|e| *e != "" && *e != ".").collect();
            let name = parent.pop().unwrap();
            let parinode = VFS::LookupPath([String::from("/"),parent.join("/")].join("").as_str());
            if parinode.is_err() {
                regs.SetSC0((-parinode.err().unwrap() as isize) as usize);
                drop(plock);
                return;
            }
            regs.SetSC0(parinode.ok().unwrap().Unlink(name) as usize);
            drop(plock);
        }
        0x0b => { // stat
            let plock = crate::Process::PROCESSES.lock();
            let proc = plock.get(&curproc).unwrap();
            let path = unsafe {CStr::from_ptr(regs.GetSC1() as *const c_char)}.to_str();
            if path.is_err() {
                regs.SetSC0((-Errors::EINVAL as isize) as usize);
                drop(plock);
                return;
            }
            let file = VFS::LookupPath(VFS::GetAbsPath(path.ok().unwrap(),proc.cwd.as_str()).as_str());
            if file.is_err() {
                regs.SetSC0((-file.err().unwrap() as isize) as usize);
                drop(plock);
                return;
            }
            let stat = file.ok().unwrap().Stat().ok().unwrap();
            unsafe {core::ptr::copy(&stat as *const _ as *const u8,regs.GetSC2() as *mut u8,core::mem::size_of::<VFS::Metadata>());}
            drop(plock);
            regs.SetSC0(0);
        }
        0x0c => { // fstat
            let plock = crate::Process::PROCESSES.lock();
            let proc = plock.get(&curproc).unwrap();
            let fd = proc.fds.get(&(regs.GetSC1() as i64));
            if fd.is_none() {
                drop(plock);
                regs.SetSC0((-Errors::EBADF) as usize);
                return;
            }
            let stat = fd.unwrap().inode.Stat().ok().unwrap();
            unsafe {core::ptr::copy(&stat as *const _ as *const u8,regs.GetSC2() as *mut u8,core::mem::size_of::<VFS::Metadata>());}
            drop(plock);
            regs.SetSC0(0);
        }
        0x0d => { // access
            let plock = crate::Process::PROCESSES.lock();
            let proc = plock.get(&curproc).unwrap();
            let path = unsafe {CStr::from_ptr(regs.GetSC1() as *const c_char)}.to_str();
            let mode = regs.GetSC2();
            if path.is_err() {
                regs.SetSC0((-Errors::ENOENT as isize) as usize);
                drop(plock);
                return;
            }
            let file = VFS::LookupPath(VFS::GetAbsPath(path.ok().unwrap(),proc.cwd.as_str()).as_str());
            if file.is_err() {
                regs.SetSC0((-file.err().unwrap() as isize) as usize);
                drop(plock);
                return;
            }
            let metadata = file.as_ref().ok().unwrap().Stat().ok().unwrap();
            if !VFS::HasPermission(&metadata,proc.euid,proc.egid,proc.supgroups.as_ref(),if mode & 1 == 1 {0b10} else {0} | if mode & 2 == 2 {0b100} else {0}) && metadata.mode & 0o0770000 != 0o0040000 {
                regs.SetSC0((-Errors::EACCES as isize) as usize);
                drop(plock);
                return;
            }
            regs.SetSC0(0);
            drop(plock);
        }
        0x0e => { // chmod
            let plock = crate::Process::PROCESSES.lock();
            let proc = plock.get(&curproc).unwrap();
            let path = unsafe {CStr::from_ptr(regs.GetSC1() as *const c_char)}.to_str();
            if path.is_err() {
                regs.SetSC0((-Errors::ENOENT as isize) as usize);
                drop(plock);
                return;
            }
            let file = VFS::LookupPath(VFS::GetAbsPath(path.ok().unwrap(),proc.cwd.as_str()).as_str());
            if file.is_err() {
                regs.SetSC0((-file.err().unwrap() as isize) as usize);
                drop(plock);
                return;
            }
            let metadata = file.as_ref().ok().unwrap().Stat().ok().unwrap();
            if metadata.uid != proc.euid && proc.euid != 0 {
                regs.SetSC0((-Errors::EPERM as isize) as usize);
                drop(plock);
                return;
            }
            regs.SetSC0((file.ok().unwrap().ChMod(regs.GetSC2() as i32) as isize) as usize);
            drop(plock);
        }
        0x0f => { // chown
            let plock = crate::Process::PROCESSES.lock();
            let proc = plock.get(&curproc).unwrap();
            let path = unsafe {CStr::from_ptr(regs.GetSC1() as *const c_char)}.to_str();
            if path.is_err() {
                regs.SetSC0((-Errors::ENOENT as isize) as usize);
                drop(plock);
                return;
            }
            let file = VFS::LookupPath(VFS::GetAbsPath(path.ok().unwrap(),proc.cwd.as_str()).as_str());
            if file.is_err() {
                regs.SetSC0((-file.err().unwrap() as isize) as usize);
                drop(plock);
                return;
            }
            let metadata = file.as_ref().ok().unwrap().Stat().ok().unwrap();
            if metadata.uid != proc.euid && proc.euid != 0 {
                regs.SetSC0((-Errors::EPERM as isize) as usize);
                drop(plock);
                return;
            }
            regs.SetSC0((file.ok().unwrap().ChOwn(regs.GetSC2() as i32,regs.GetSC3() as i32) as isize) as usize);
            drop(plock);
        }
        0x10 => { // umask
            let mut plock = crate::Process::PROCESSES.lock();
            let mut proc = plock.get_mut(&curproc).unwrap();
            let ret = proc.umask;
            proc.umask = regs.GetSC1() as i32;
            regs.SetSC0(ret as usize);
            drop(plock);
        }
        0x11 => { // ioctl
            let plock = crate::Process::PROCESSES.lock();
            let proc = plock.get(&curproc).unwrap();
            let fd = proc.fds.get(&(regs.GetSC1() as i64));
            if fd.is_none() {
                drop(plock);
                regs.SetSC0((-Errors::EBADF) as usize);
                return;
            }
            let result = fd.unwrap().inode.IOCtl(regs.GetSC2(),regs.GetSC3());
            if result.is_err() {
                regs.SetSC0((-result.err().unwrap() as isize) as usize);
                drop(plock);
                return;
            }
            regs.SetSC0(result.ok().unwrap());
            drop(plock);
        }
        0x12 => { // execve
            let path = unsafe {CStr::from_ptr(regs.GetSC1() as *const c_char)}.to_str();
            if path.is_err() {
                regs.SetSC0((-Errors::ENOENT as isize) as usize);
                return;
            }
            regs.SetSC0(crate::Process::Process::Exec(curproc,path.ok().unwrap(),if regs.GetSC2() > 0 {Some(regs.GetSC2() as *const usize)} else {None},if regs.GetSC3() > 0 {Some(regs.GetSC3() as *const usize)} else {None}));
        }
        0x13 => { // pollpid
            let plock = crate::Process::PROCESSES.lock();
            let proc = plock.get(&curproc).unwrap();
            let pid = regs.GetSC1() as i32;
            let wstatus = regs.GetSC2() as *mut usize;
            let pgrp;
            if proc.children.len() == 0 {
                regs.SetSC0((-Errors::ECHILD as isize) as usize);
                drop(plock);
                return;
            }
            if pid < -1 {
                pgrp = pid.abs();
            } else if pid == -1 {
                pgrp = -1;
            } else if pid == 0 {
                pgrp = proc.pgid;
            } else {
                if let Some(child) = plock.get(&pid) {
                    if let crate::Process::ProcessStatus::FINISHED(status) = child.status {
                        if !wstatus.is_null() {
                            if status < 0 {
                                unsafe {*wstatus = status.abs() as usize & 0xFF;}
                            } else {
                                unsafe {*wstatus = (status as usize & 0xFF) << 8;}
                            }
                        }
                        regs.SetSC0(pid as usize);
                        drop(plock);
                        crate::Process::Process::CleanupProcess(pid);
                        return;
                    } else if let crate::Process::ProcessStatus::STOPPED = child.status {
                        regs.SetSC0(pid as usize);
                        if !wstatus.is_null() {
                            unsafe {*wstatus = 0x13ff};
                        }
                    } else {
                        regs.SetSC0(0);
                    }
                    drop(plock);
                    return;
                } else {
                    regs.SetSC0((-Errors::ECHILD as isize) as usize);
                    drop(plock);
                    return;
                }
            }
            // < -1 or 0
            for i in proc.children.iter() {
                if let Some(child) = plock.get(&i) {
                    if child.pgid == pgrp || pgrp == -1 {
                        if let crate::Process::ProcessStatus::FINISHED(status) = child.status {
                            if !wstatus.is_null() {
                                if status < 0 {
                                    unsafe {*wstatus = status.abs() as usize & 0xFF;}
                                } else {
                                    unsafe {*wstatus = (status as usize & 0xFF) << 8;}
                                }
                            }
                            let ret = *i;
                            regs.SetSC0(ret as usize);
                            drop(plock);
                            crate::Process::Process::CleanupProcess(ret);
                            return;
                        } else if let crate::Process::ProcessStatus::STOPPED = child.status {
                            regs.SetSC0(*i as usize);
                            if !wstatus.is_null() {
                                unsafe {*wstatus = 0x13ff};
                            }
                            drop(plock);
                            return;
                        }
                    }
                }
            }
            regs.SetSC0(0);
            drop(plock);
        }
        0x14 => { // getuid
            let plock = crate::Process::PROCESSES.lock();
            let proc = plock.get(&curproc).unwrap();
            regs.SetSC0(proc.ruid as usize);
            drop(plock);
        }
        0x15 => { // geteuid
            let plock = crate::Process::PROCESSES.lock();
            let proc = plock.get(&curproc).unwrap();
            regs.SetSC0(proc.euid as usize);
            drop(plock);
        }
        0x16 => { // getgid
            let plock = crate::Process::PROCESSES.lock();
            let proc = plock.get(&curproc).unwrap();
            regs.SetSC0(proc.rgid as usize);
            drop(plock);
        }
        0x17 => { // getegid
            let plock = crate::Process::PROCESSES.lock();
            let proc = plock.get(&curproc).unwrap();
            regs.SetSC0(proc.egid as usize);
            drop(plock);
        }
        0x18 => { // setgroups
            let mut plock = crate::Process::PROCESSES.lock();
            let proc = plock.get_mut(&curproc).unwrap();
            if proc.ruid != 0 {
                drop(plock);
                regs.SetSC0((-Errors::EPERM as isize) as usize);
                return;
            }
            if regs.GetSC1() > 32 { // Not specified in POSIX, but you shouldn't ever exceed this number.
                drop(plock);
                regs.SetSC0((-Errors::EINVAL as isize) as usize);
                return;
            }
            let gids = unsafe {core::slice::from_raw_parts_mut(regs.GetSC2() as *mut u32,regs.GetSC1())};
            proc.supgroups.clear();
            proc.supgroups.extend_from_slice(gids);
            drop(plock);
            regs.SetSC0(0);
        }
        0x19 => { // getgroups
            let plock = crate::Process::PROCESSES.lock();
            let proc = plock.get(&curproc).unwrap();
            if regs.GetSC1() < proc.supgroups.len() {
                drop(plock);
                regs.SetSC0((-Errors::EINVAL as isize) as usize);
                return;
            }
            let gids = unsafe {core::slice::from_raw_parts_mut(regs.GetSC2() as *mut u32,proc.supgroups.len())};
            gids.copy_from_slice(proc.supgroups.as_slice());
            drop(plock);
            regs.SetSC0(gids.len());
        }
        0x1a => { // getpid
            let plock = crate::Process::PROCESSES.lock();
            let proc = plock.get(&curproc).unwrap();
            regs.SetSC0(proc.id as usize);
            drop(plock);
        }
        0x1b => { // getppid
            let plock = crate::Process::PROCESSES.lock();
            let proc = plock.get(&curproc).unwrap();
            regs.SetSC0(proc.parent_id as usize);
            drop(plock);
        }
        0x1c => { // setpgid
            let plock = crate::Process::PROCESSES.lock();
            let proc_self = plock.get(&curproc).unwrap();
            let proc = plock.get(&(regs.GetSC1() as i32));
            if proc.is_none() {
                regs.SetSC0((-Errors::EPERM as isize) as usize);
                drop(plock);
                return;
            }
            let pgid = proc.as_ref().unwrap().pgid;
            if proc_self.pgid != pgid && proc_self.id != proc.as_ref().unwrap().id {
                regs.SetSC0((-Errors::EPERM as isize) as usize);
                drop(plock);
                return;
            }
            drop(plock);
            crate::Process::PROCESSES.lock().get_mut(&(regs.GetSC1() as i32)).unwrap().pgid = regs.GetSC2() as i32;
            regs.SetSC0(0);
        }
        0x1d => { // getpgrp
            let plock = crate::Process::PROCESSES.lock();
            let proc = plock.get(&curproc).unwrap();
            regs.SetSC0(proc.pgid as usize);
            drop(plock);
        }
        0x1e => { // signal
            if regs.GetSC1() > 0x17 || regs.GetSC1() == 0 {
                regs.SetSC0((-Errors::EINVAL as isize) as usize);
                return;
            }
            let mut plock = crate::Process::PROCESSES.lock();
            let proc = plock.get_mut(&curproc).unwrap();
            proc.signals[regs.GetSC1()] = regs.GetSC2();
            drop(plock);
        }
        0x1f => { // kill
            regs.SetSC0(crate::Process::Process::SendSignal(regs.GetSC1() as i32,regs.GetSC2() as u8) as usize);
        }
        0x20 => { // sigreturn
            let mut plock = crate::Process::PROCESSES.lock();
            let proc = plock.get_mut(&curproc).unwrap();
            if proc.sig_state.GetIP() != 0 {
                regs.Save(&proc.sig_state);
                proc.sig_state.SetIP(0);
                drop(plock);
                Scheduler::Tick(CurrentHart(),regs);
                panic!("You'll never see this message, isn't that weird?");
            }
            drop(plock);
        }
        0x21 => { // clock_get
            let timestamp = crate::arch::Timer::GetTimeStamp();
            unsafe {
                *(regs.GetSC1() as *mut i64) = timestamp.0;
                *(regs.GetSC2() as *mut i64) = timestamp.1;
            }
            regs.SetSC0(0);
        }
        0x22 => { // chdir
            let mut plock = crate::Process::PROCESSES.lock();
            let proc = plock.get_mut(&curproc).unwrap();
            let path = unsafe {CStr::from_ptr(regs.GetSC1() as *const c_char)}.to_str();
            if path.is_err() {
                regs.SetSC0((-Errors::ENOENT as isize) as usize);
                drop(plock);
                return;
            }
            proc.cwd = VFS::GetAbsPath(path.ok().unwrap(),proc.cwd.as_str());
            regs.SetSC0(0);
            drop(plock);
        }
        0x23 => { // getcwd
            let mut plock = crate::Process::PROCESSES.lock();
            let proc = plock.get_mut(&curproc).unwrap();
            if proc.cwd.as_bytes().len() > regs.GetSC2() {
                regs.SetSC0((-Errors::ENAMETOOLONG as isize) as usize);
                drop(plock);
                return;
            }
            if regs.GetSC2() == usize::MAX {
                regs.SetSC0(proc.cwd.as_bytes().len());
                drop(plock);
                return;
            }
            unsafe {core::ptr::copy(proc.cwd.as_ptr(),regs.GetSC1() as *mut u8,proc.cwd.as_bytes().len());}
            drop(plock);
            regs.SetSC0(regs.GetSC1());
        }
        0x24 => { // pipe
            let mut plock = crate::Process::PROCESSES.lock();
            let proc = plock.get_mut(&curproc).unwrap();
            let pipes = crate::Drivers::Generic::UNIXPipe::Pipe::new();
            let mode = regs.GetSC2();
            let ptr: *mut isize = regs.GetSC1() as *mut isize;
            let len = if proc.fds.keys().last().is_some() {*(proc.fds.keys().last().unwrap())} else {0};
            proc.fds.insert(len,VFS::FileDescriptor {
                inode: pipes.0,
                path: String::from(""),
                offset: 0,
                mode: 3 | (mode & OpenFlags::O_CLOEXEC),
                is_dir: false,
                close_on_exec: mode & OpenFlags::O_CLOEXEC != 0,
            });
            proc.fds.insert(len+1,VFS::FileDescriptor {
                inode: pipes.1,
                path: String::from(""),
                offset: 0,
                mode: 3 | (mode & OpenFlags::O_CLOEXEC),
                is_dir: false,
                close_on_exec: mode & OpenFlags::O_CLOEXEC != 0,
            });
            unsafe {
                *ptr = len as isize;
                *(ptr.offset(1)) = (len+1) as isize;
            }
            drop(proc);
            regs.SetSC0(0);
        }
        0x25 => { // mmap
            let mut plock = crate::Process::PROCESSES.lock();
            let proc = plock.get_mut(&curproc).unwrap();
            let args = unsafe {&*(regs.GetSC1() as *const MmapStruct)};
            if args.addr & 0xFFF != 0 || args.size == 0 {
                drop(plock);
                regs.SetSC0((-Errors::EINVAL as isize) as usize);
                return;
            }
            let mut segs = proc.memory_segments.lock();
            let mut space: (usize,usize) = (usize::MAX,usize::MAX);
            if args.flags & MAP_FIXED == 0 {
                let mut got_space = false;
                for i in 0..(&segs).len() {
                    let cur_val = (&segs).get(i).unwrap();
                    match (&segs).get(i+1) {
                        Some(next_val) => {
                            let begin = cur_val.0+cur_val.1;
                            let size = next_val.0-begin;
                            if size >= args.size {
                                space = (begin,i+1);
                                got_space = true;
                                break;
                            }
                        }
                        None => {
                            break;
                        }
                    }
                }
                if !got_space {
                    drop(segs);
                    drop(plock);
                    regs.SetSC0((-Errors::ENOMEM as isize) as usize);
                    return;
                }
            } else {
                let prev_val = (&segs).iter()
                .enumerate()
                .filter(|x| x.1.0 <= args.addr)
                .max_by(|x,y| x.1.0.cmp(&(y.1.0)));
                let next_val = (&segs).iter()
                .enumerate()
                .filter(|x| x.1.0 >= args.addr)
                .min_by(|x,y| x.1.0.cmp(&(y.1.0)));
                space = (args.addr,if next_val.is_some() {next_val.unwrap().0} else {(&segs).len()});
                if prev_val.is_some() {
                    if (prev_val.unwrap().1.0..(prev_val.unwrap().1.0+prev_val.unwrap().1.1)).contains(&args.addr) {
                        drop(segs);
                        drop(plock);
                        regs.SetSC0((-Errors::EEXIST as isize) as usize);
                        return;
                    }
                }
                if next_val.is_some() {
                    if (next_val.unwrap().1.0..(next_val.unwrap().1.0+next_val.unwrap().1.1)).contains(&(args.addr+args.size-1)) {
                        drop(segs);
                        drop(plock);
                        regs.SetSC0((-Errors::EEXIST as isize) as usize);
                        return;
                    }
                }
            }
            // Now we get to map the memory!
            if space.0 == usize::MAX {
                drop(segs);
                drop(plock);
                regs.SetSC0((-Errors::ENOMEM as isize) as usize);
                return;
            }
            if args.flags & MAP_ANONYOMUS != 0 || (args.fd as isize) < 0 {
                let pages = Allocate((args.size.div_ceil(0x1000)*0x1000) as u64).unwrap() as u64 - crate::arch::PHYSMEM_BEGIN;
                if !crate::Memory::MapPages(Arc::get_mut(&mut proc.pagetable).unwrap(),space.0,pages as usize,args.size.div_ceil(0x1000)*0x1000,args.prot & 2 != 0,args.prot & 4 != 0) {
                    drop(segs);
                    drop(plock);
                    regs.SetSC0((-Errors::ENOMEM as isize) as usize);
                    return;
                }
                segs.insert(space.1,(space.0,args.size.div_ceil(0x1000)*0x1000,String::from(""),args.prot as u8,0,0));
                regs.SetSC0(space.0);
                drop(segs);
                drop(plock);
                return;
            } else {
                match proc.fds.get_mut(&(args.fd as i64)) {
                    Some(fd) => {
                        match (&fd).inode.MMap(args.offset as i64,args.size,args.prot as u8,args.flags & MAP_SHARED != 0) {
                            Ok(data) => {
                                if !crate::Memory::MapPages(Arc::get_mut(&mut proc.pagetable).unwrap(),space.0,data.as_ptr() as usize - crate::arch::PHYSMEM_BEGIN as usize,args.size.div_ceil(0x1000)*0x1000,args.prot & 2 != 0,args.prot & 4 != 0) {
                                    drop(segs);
                                    drop(plock);
                                    regs.SetSC0((-Errors::ENOMEM as isize) as usize);
                                    return;
                                }
                                segs.insert(space.1,(space.0,args.size.div_ceil(0x1000)*0x1000,fd.path.clone(),args.prot as u8,fd.inode.Stat().ok().unwrap().inode_id,args.offset as usize));
                                regs.SetSC0(space.0);
                                drop(segs);
                                drop(plock);
                                return;
                            }
                            Err(e) => {
                                regs.SetSC0(e as usize);
                                drop(segs);
                                drop(plock);
                                return;
                            }
                        }
                    }
                    None => {
                        regs.SetSC0((-Errors::EBADF as isize) as usize);
                        drop(segs);
                        drop(plock);
                        return;
                    }
                }
            }
        }
        0x26 => { // munmap
            let mut plock = crate::Process::PROCESSES.lock();
            let proc = plock.get_mut(&curproc).unwrap();
            let mut segs = proc.memory_segments.lock();
            let addr = regs.GetSC1();
            let length = regs.GetSC2().div_ceil(0x1000)*0x1000;
            let mut conflicts = Vec::new();
            for i in 0..(&segs).len() {
                let val = (&segs).get(i).unwrap();
                if addr >= val.0 && addr < val.0+val.1 {
                    conflicts.push((i,val.clone()));
                }
            }
            conflicts.sort_by(|a,b| a.1.0.partial_cmp(&b.1.0).unwrap());
            for segment in conflicts.iter() {
                if addr == segment.1.0 && length == segment.1.1 { // Complete Delete
                    segs.remove(segment.0);
                } else if addr <= segment.1.0 { // Partial Left Delete
                    segs.get_mut(segment.0).unwrap().0 = addr + length;
                    segs.get_mut(segment.0).unwrap().1 = segment.1.0 + segment.1.1 - (addr+length);
                } else if segment.1.0 <= addr+length { // Partial Right Delete
                    segs.get_mut(segment.0).unwrap().1 -= segment.1.0 + segment.1.1 - addr;
                } else if segment.1.0 < addr && addr + length - segment.1.0 <= segment.1.1 { // Split Delete
                    let right_segment: (usize,usize,String,u8,i64,usize) = (addr + length,segment.1.0 + segment.1.1 - (addr + length),segment.1.2.clone(),segment.1.3,segment.1.4,segment.1.5);
                    segs.get_mut(segment.0).unwrap().1 = addr - segment.1.0;
                    segs.insert(segment.0+1,right_segment);
                } else {
                    panic!("Invalid Segment Conflict");
                }
            }
            drop(conflicts);
            crate::Memory::UnmapPages(Arc::get_mut(&mut proc.pagetable).unwrap(),addr,length);
            drop(segs);
            drop(plock);
            regs.SetSC0(0);
        }
        0x27 => { // futex_wait

        }
        0x28 => { // futex_wake

        }
        0x29 => { // set_thread_area
            let mut plock = crate::Process::PROCESSES.lock();
            let proc = plock.get_mut(&curproc).unwrap();
            proc.tcb = regs.GetSC1();
            crate::arch::Task::SetTCB(proc.tcb);
            drop(plock);
            regs.SetSC0(0);
        }
        0xf0 => { // foxkernel_powerctl
            if curproc > 1 {
                regs.SetSC0((-Errors::EACCES as isize) as usize);
                return;
            }
            if regs.GetSC1() as u32 == 3166499024 { // FOXKERNEL_HALT
                regs.Exit();
                unsafe {crate::Console::QUIET = false;}
                log::warn!("Fox Kernel will now halt");
                crate::halt_other_harts!();
                crate::halt!();
                unreachable!();
            } else if regs.GetSC1() as u32 == 926892958 { // FOXKERNEL_SHUTDOWN
                unsafe {crate::Console::QUIET = true;}
                log::info!("It is now safe to turn off your computer");
                if let Some(fb) = crate::Framebuffer::MainFramebuffer.lock().as_mut() {
                    let ptr = fb.pointer as *mut u32;
                    for i in 0..(fb.width*fb.height) {
                        let pxl = unsafe {ptr.offset(i as isize).read()};
                        let val = ((((pxl & 0xFF0000) >> 16)+((pxl & 0xFF00) >> 8)+(pxl & 0xFF))/3)/2;
                        unsafe {ptr.offset(i as isize).write((val << 16) | (val << 8) | val)};
                    }
                    let msg = "It is now safe to turn off your computer";
                    fb.DrawString((fb.width/2)-(msg.len()*8),fb.height/2-16,msg,0xFFFFFF,2);
                }
                crate::halt_other_harts!();
                crate::halt!();
                unreachable!();
            } else if regs.GetSC1() as u32 == 1468614837 { // FOXKERNEL_GETSYSV_LEVEL
                if crate::CommandLine::OPTIONS.get().unwrap().contains_key("--sysvlevel") {
                    regs.SetSC0(crate::CommandLine::OPTIONS.get().unwrap().get("--sysvlevel").unwrap().trim().parse().unwrap_or_else(|_| 5));
                } else {
                    regs.SetSC0(5);
                }
                return
            }
            regs.SetSC0((-Errors::EINVAL as isize) as usize);
        }
        0xf1 => { // foxkernel_log
            let msg = unsafe {CStr::from_ptr(regs.GetSC1() as *const c_char)}.to_str();
            if msg.is_err() {
                regs.SetSC0((-Errors::EINVAL as isize) as usize);
                return;
            }
            print!("{}\n", msg.ok().unwrap());
            regs.SetSC0(0);
        }
        _ => {

        }
    }
}
