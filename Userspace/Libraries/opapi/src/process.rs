pub fn exec(path: &str) -> isize {
    crate::syscall::exec(path)
}

/*pub fn execv(path: &str, argv: &[&str]) -> isize {
    crate::syscall::exec(path)
}*/