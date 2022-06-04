use spin::Once;
use alloc::collections::{BTreeSet,BTreeMap};
use alloc::vec::Vec;
use alloc::string::String;

pub static RAW_CMDLINE: Once<String> = Once::new();
pub static FLAGS: Once<BTreeSet<&str>> = Once::new();
pub static OPTIONS: Once<BTreeMap<&str,&str>> = Once::new();

pub fn Parse(cmd: String) {
    unsafe {crate::Console::NO_COLOR = false;}
    if cmd.len() == 0 {
        FLAGS.call_once(|| BTreeSet::new());
        OPTIONS.call_once(|| BTreeMap::new());
        RAW_CMDLINE.call_once(|| cmd);
        return;
    }
    RAW_CMDLINE.call_once(|| cmd);
    let mut options: BTreeMap<&str,&str> = BTreeMap::new();
    let mut flags: BTreeSet<&str> = BTreeSet::new();
    for arg in RAW_CMDLINE.get().unwrap().trim().split_whitespace() {
        if arg.contains("=") {
            let keyval: Vec<&str> = arg.splitn(2,'=').collect();
            options.insert(keyval[0],keyval[1]);
        } else {
            flags.insert(arg);
            if arg == "--no_debug" {
                unsafe {crate::Console::QUIET = true;}
            } else if arg == "--no_color" {
                unsafe {crate::Console::NO_COLOR = true;}
            }
        }
    }
    FLAGS.call_once(|| flags);
    OPTIONS.call_once(|| options);
}