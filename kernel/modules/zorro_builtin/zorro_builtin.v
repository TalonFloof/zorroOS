module builtin

[noreturn]
pub fn C.kpanic(u8,string)

pub fn bare_print(buf &byte, len u64) {

}

pub fn bare_eprint(buf &byte, len u64) {

}

pub fn bare_panic(msg string) {
	C.kpanic(1,msg)
}

[export: 'malloc']
pub fn __malloc(n usize) &C.void {
	C.kpanic(3,"Attempt to allocate memory")
}

[export: 'free']
pub fn __free(ptr &C.void) {
	C.kpanic(3,"Attempt to free memory")
}

pub fn realloc(old_area &C.void, new_size usize) &C.void {
	C.kpanic(3,"Attempt to reallocate memory")
}

[export: 'calloc']
pub fn __calloc(nmemb usize, size usize) &C.void {
	C.kpanic(3,"Attempt to allocate memory")
}

[unsafe]
pub fn memcpy(dest &C.void, src &C.void, n usize) &C.void {
	dest_ := unsafe { &u8(dest) }
	src_ := unsafe { &u8(src) }
	unsafe {
		for i in 0 .. int(n) {
			dest_[i] = src_[i]
		}
	}
	return unsafe { dest }
}

[unsafe]
pub fn memmove(dest &C.void, src &C.void, n usize) &C.void {
	dest_ := unsafe { &u8(dest) }
	src_ := unsafe { &u8(src) }
	mut temp_buf := unsafe { malloc(int(n)) }
	for i in 0 .. int(n) {
		unsafe {
			temp_buf[i] = src_[i]
		}
	}

	for i in 0 .. int(n) {
		unsafe {
			dest_[i] = temp_buf[i]
		}
	}
	unsafe { free(temp_buf) }
	return unsafe { dest }
}

[unsafe]
pub fn memcmp(a &C.void, b &C.void, n usize) int {
	a_ := unsafe { &u8(a) }
	b_ := unsafe { &u8(b) }
	for i in 0 .. int(n) {
		if unsafe { a_[i] != b_[i] } {
			unsafe {
				return a_[i] - b_[i]
			}
		}
	}
	return 0
}

[unsafe]
pub fn strlen(_s &C.void) usize {
	s := unsafe { &u8(_s) }
	mut i := 0
	for ; unsafe { s[i] } != 0; i++ {}
	return usize(i)
}

[unsafe]
pub fn memset(s &C.void, c int, n usize) &C.void {
	mut s_ := unsafe { &char(s) }
	for i in 0 .. int(n) {
		unsafe {
			s_[i] = char(c)
		}
	}
	return unsafe { s }
}

pub fn getchar() int {
	return 0
}

pub fn vsprintf(str &char, format &char, ap &byte) int {
	panic('vsprintf(): string interpolation is not supported in `-freestanding`')
}

pub fn vsnprintf(str &char, size usize, format &char, ap &byte) int {
	panic('vsnprintf(): string interpolation is not supported in `-freestanding`')
}

pub fn bare_backtrace() string {
	return "Backtraces are not supported in the Zorro Kernel"
}

[export: 'exit']
pub fn __exit(code int) {

}