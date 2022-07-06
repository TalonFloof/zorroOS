use core::mem::size_of;

pub struct Stack<'a> {
    pointer: &'a mut u64,
}

impl<'a> Stack<'a> {
    pub fn new(pointer: &'a mut u64) -> Self {
        Stack::<'a> { pointer }
    }
    pub fn Skip(&mut self, a: u64) {
        *self.pointer -= a;
    }
    pub fn GetTop(&self) -> u64 {
        *self.pointer
    }
    pub fn Align(&mut self) {
        *self.pointer = *self.pointer & !15;
    }
    pub fn OffsetPtr<T: Sized>(&mut self) -> &mut T {
        self.Skip(size_of::<T>() as u64);
        return unsafe {&mut *(*self.pointer as *mut T)};
    }
    pub fn Write<T: Sized>(&mut self, val: T) {
        self.Skip(size_of::<T>() as u64);
        unsafe {*(*self.pointer as *mut T) = val;}
    }
    pub fn WriteByteSlice(&mut self, b: &[u8]) {
        self.Skip(b.len() as u64);
        unsafe {(*self.pointer as *mut u8).copy_from(b.as_ptr(),b.len());}
    }
}