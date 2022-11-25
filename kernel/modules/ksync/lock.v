module ksync

import arch.interfaces.logger as log
import panic

pub struct Lock {
pub mut:
	l Atomic
	id string
}

fn C.__builtin_return_address(int) voidptr

pub fn (mut l Lock) acquire() {
	for i := u64(0); i < u64(50000000); i++ {
		if l.test_and_acquire() == true {
			return
		}
		asm volatile amd64 {
			pause
			; ; ; memory
		}
	}
	logger := zorro_arch.get_logger() or { unsafe { goto panic_routine } return }
	logger.log(log.ZorroLogLevel.fatal,"Detected Deadlock on KLock: \"",false)
	logger.raw_log(l.id)
	logger.raw_log("\"\n")
panic_routine:
	arr := ["Kernel is Deadlocked!",l.id]!
	unsafe {
		panic.panic_multiline(panic.ZorroPanicCategory.generic,&string(&arr),2)
	}
}

pub fn (mut l Lock) release() {
	l.l.store(0, AtomicOrder.release)
}

pub fn (mut l Lock) test_and_acquire() bool {
	return l.l.compare_exchange(0, 1, AtomicOrder.acquire, AtomicOrder.acquire)
}