use interfaces::Logger;
use crate::sbi;

pub struct LogImpl {}

impl Logger for LogImpl {
    fn log(&self, data: &str) {
        for i in data.bytes() {
            sbi::sbi_call(1,0,i as usize,0,0);
        }
    }
}