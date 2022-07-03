pub(crate) fn SetupConsole() -> bool {
    let con = opapi::syscall::open("/dev/liminecon",0x4003);
    if con.is_negative() {
        return false;
    }
    if opapi::syscall::dup2(con,1).is_negative() || opapi::syscall::dup2(con,2).is_negative() {
        return false;
    }
    return true;
}