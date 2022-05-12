use alloc::boxed::Box;
pub use crate::arch::Memory::*;

pub fn MapPages(pt: &mut PageTableImpl, vaddr: usize, paddr: usize, size: usize, can_write: bool, can_exec: bool) -> bool {
    // Check if the space is empty first
    let mut index = vaddr;
    let end = vaddr+size;
    while index < end {
        match pt.GetEntry(index as u64) {
            Some(_page) => {
                return false;
            },
            _ => {}
        }
        index += 0x1000;
    }
    index = 0;
    while index < size {
        let mut page = pt.Map((vaddr+index) as u64,(paddr as u64)+index as u64);
        page.SetUser(true);
        page.SetWritable(can_write);
        page.SetExecutable(can_exec);
        page.Update();
        index += 0x1000;
    }
    return true;
}

pub fn UnmapPages(pt: &mut PageTableImpl, vaddr: usize, size: usize) {
    let mut index = vaddr;
    let end = vaddr+size;
    while index < end {
        pt.Unmap(index as u64);
        index += 0x1000;
    }
}

pub trait PageTable {
    fn Map(&mut self, addr: u64, target: u64) -> Box<dyn PageEntry>;
    fn Unmap(&mut self, addr: u64);
    fn GetEntry(&self, addr: u64) -> Option<Box<dyn PageEntry>>;
    fn GetMutPageSlice<'a>(&mut self, addr: u64) -> &'a mut [u8];
    unsafe fn Switch(&self);
    fn Flush();
}

pub trait PageEntry {
    fn Update(&mut self);
    fn Accessed(&self) -> bool;
    fn Dirty(&self) -> bool;
    fn Writable(&self) -> bool;
    fn Executable(&self) -> bool;
    fn User(&self) -> bool;
    fn Present(&self) -> bool;

    fn ClearAccessed(&mut self);
    fn ClearDirty(&mut self);
    fn SetWritable(&mut self, value: bool);
    fn SetExecutable(&mut self, value: bool);
    fn SetUser(&mut self, value: bool);
    fn SetPresent(&mut self, value: bool);

    fn Target(&self) -> u64;
    fn SetTarget(&mut self, target: u64);

}