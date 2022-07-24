#[repr(C)]
pub struct WinSize {
    pub row: u16,
    pub col: u16,
    pub reserved1: u16,
    pub reserved2: u16,
}

pub const TCGETS: usize = 0x4000;
pub const TCSETS: usize = 0x4001;
pub const TCSETSW: usize = 0x4002;
pub const TCSETSF: usize = 0x4003;

pub const TCGETA: usize = TCGETS;
pub const TCSETA: usize = TCSETS;
/*pub const TCGETAW: usize = TCGETSW;
pub const TCGETAF: usize = TCGETSF;*/

pub const TCSBRK: usize = 0x4004;
pub const TCXONC: usize = 0x4005;
pub const TCFLSH: usize = 0x4006;

pub const TIOCEXCL: usize = 0x4007;
pub const TIOCNXCL: usize = 0x4008;
pub const TIOCSCTTY: usize = 0x4009;
pub const TIOCGPGRP: usize = 0x400A;
pub const TIOCSPGRP: usize = 0x400B;
pub const TIOCOUTQ: usize = 0x400C;
pub const TIOCSTI: usize = 0x400D;
pub const TIOCGWINSZ: usize = 0x400E;
pub const TIOCSWINSZ: usize = 0x400F;
pub const TIOCMGET: usize = 0x4010;
pub const TIOCMBIS: usize = 0x4011;
pub const TIOCMBIC: usize = 0x4012;
pub const TIOCMSET: usize = 0x4013;
pub const TIOCGSOFTCAR: usize = 0x4014;
pub const TIOCSSOFTCAR: usize = 0x4015;