module stubs

import panic
import arch.x86_64.framebuffer

struct C.__file {}

type FILE = C.__file

__global (
	stdin  = &FILE(voidptr(0))
	stdout = &FILE(voidptr(0))
	stderr = &FILE(voidptr(0))
)

[export: "fflush"]
pub fn fflush(stream &FILE) int {
	return 0
}
[export: "strlen"]
pub fn strlen(_ptr &C.char) u64 {
	unsafe {
		mut count := u64(0)
		for _ptr[count] != C.char(0) {
			count = count + 1
		}
		return count
	}
}
[export: "malloc"]
pub fn malloc(size int) &byte {
	panic.panic(panic.ZorroPanicCategory.generic,"Attempt to call stub: malloc")
}
[export: "calloc"]
pub fn calloc(n int, size int) &byte {
	panic.panic(panic.ZorroPanicCategory.generic,"Attempt to call stub: calloc")
}
[export: "realloc"]
pub fn realloc(ptr &byte, size int) &byte {
	panic.panic(panic.ZorroPanicCategory.generic,"Attempt to call stub: realloc")
}
[export: "free"]
pub fn free(ptr &byte) {
	panic.panic(panic.ZorroPanicCategory.generic,"Attempt to call stub: free")
}
[export: "memcpy"]
pub fn memcpy(dest voidptr, src voidptr, n u64) voidptr {
	unsafe {
		mut destm := &u8(dest)
		srcm := &u8(src)

		for i := 0; i < n; i++ {
			destm[i] = srcm[i]
		}
	}
	return dest
}
[export: "memset"]
pub fn memset(s voidptr, c int, n u64) voidptr {
	unsafe {
		mut destm := &u8(s)

		for i := 0; i < n; i++ {
			destm[i] = u8(c)
		}
	}
	return s
}
[export: "memmove"]
pub fn memmove(dest voidptr, src voidptr, n u64) voidptr {
	unsafe {
		mut destm := &u8(dest)
		srcm := &u8(src)

		if src > dest {
			for i := 0; i < n; i++ {
				destm[i] = srcm[i]
			}
		} else if src < dest {
			for i := n; i > 0; i-- {
				destm[i - 1] = srcm[i - 1]
			}
		}

		return dest
	}
}
[export: "tolower"]
pub fn tolower(c int) int {
	return if c >= int(`A`) && c <= int(`Z`) { c + 0x20 } else { c }
}
[export: "toupper"]
pub fn toupper(c int) int {
	return if c >= int(`a`) && c <= int(`z`) { c - 0x20 } else { c }
}
[export: "exit"]
pub fn exit(code int) {
	panic.panic(panic.ZorroPanicCategory.generic,"Attempt to call stub: exit")
}