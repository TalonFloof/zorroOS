module ksync

pub enum AtomicOrder as int {
	relaxed = C.__ATOMIC_RELAXED
	consume = C.__ATOMIC_CONSUME
	acquire = C.__ATOMIC_ACQUIRE
	release = C.__ATOMIC_RELEASE
	acq_rel = C.__ATOMIC_ACQ_REL
	seq_cst = C.__ATOMIC_SEQ_CST
}

fn C.__atomic_store_n(&usize, usize, AtomicOrder)
fn C.__atomic_load_n(&usize, AtomicOrder) usize
fn C.__atomic_compare_exchange_n(&usize, &usize, usize, bool, AtomicOrder, AtomicOrder) bool
fn C.__atomic_fetch_add(&usize, usize, AtomicOrder) usize
fn C.__atomic_fetch_sub(&usize, usize, AtomicOrder) usize
fn C.__atomic_fetch_and(&usize, usize, AtomicOrder) usize
fn C.__atomic_fetch_xor(&usize, usize, AtomicOrder) usize
fn C.__atomic_fetch_or(&usize, usize, AtomicOrder) usize
fn C.__atomic_fetch_nand(&usize, usize, AtomicOrder) usize

pub struct Atomic {
mut:
	value usize
}

pub fn (self &Atomic) store(val usize, order AtomicOrder) {
	C.__atomic_store_n(&usize(usize(self)+usize(__offsetof(Atomic,value))),val,order)
}

pub fn (self &Atomic) load(order AtomicOrder) usize {
	return C.__atomic_load_n(&usize(usize(self)+usize(__offsetof(Atomic,value))),order)
}

pub fn (self &Atomic) compare_exchange(_ifthis usize, writethis usize, success AtomicOrder, failure AtomicOrder) bool {
	mut ifthis := _ifthis
	return C.__atomic_compare_exchange_n(&usize(usize(self)+usize(__offsetof(Atomic,value))),&ifthis,writethis,false,success,failure)
}

pub fn (self &Atomic) fetch_add(val usize, order AtomicOrder) usize {
	return C.__atomic_fetch_add(&usize(usize(self)+usize(__offsetof(Atomic,value))),val,order)
}

pub fn (self &Atomic) fetch_sub(val usize, order AtomicOrder) usize {
	return C.__atomic_fetch_sub(&usize(usize(self)+usize(__offsetof(Atomic,value))),val,order)
}

pub fn (self &Atomic) fetch_and(val usize, order AtomicOrder) usize {
	return C.__atomic_fetch_and(&usize(usize(self)+usize(__offsetof(Atomic,value))),val,order)
}

pub fn (self &Atomic) fetch_xor(val usize, order AtomicOrder) usize {
	return C.__atomic_fetch_xor(&usize(usize(self)+usize(__offsetof(Atomic,value))),val,order)
}

pub fn (self &Atomic) fetch_or(val usize, order AtomicOrder) usize {
	return C.__atomic_fetch_or(&usize(usize(self)+usize(__offsetof(Atomic,value))),val,order)
}

pub fn (self &Atomic) fetch_nand(val usize, order AtomicOrder) usize {
	return C.__atomic_fetch_nand(&usize(usize(self)+usize(__offsetof(Atomic,value))),val,order)
}