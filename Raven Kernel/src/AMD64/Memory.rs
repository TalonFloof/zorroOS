use alloc::boxed::Box;
use core::ops::{Index, IndexMut};
use stivale_boot::v2::*;
use crate::PageFrame::{Setup,HeapRange};
use x86_64::structures::paging::{frame::PhysFrame as PageFrame, page::Size4KiB, page_table::{PageTable as HWPageTable, PageTableEntry, PageTableFlags}};
use crate::arch::PHYSMEM_BEGIN;
use spin::Mutex;
use x86_64::{PhysAddr, VirtAddr};
use x86_64::registers::control::Cr3Flags;
use crate::Memory::{PageEntry, PageTable};
use crate::PageFrame::{Allocate,Free,KernelPageTable};
use log::debug;

static Startup_PageTable: Mutex<Option<u64>> = Mutex::new(None);

#[inline(always)]
fn GetStartPageTable() -> *mut HWPageTable {
    (*Startup_PageTable.lock()).unwrap() as *mut HWPageTable
}

pub fn AnalyzeMMAP(mmap: &StivaleMemoryMapTag) {
    *Startup_PageTable.lock() = Some(x86_64::registers::control::Cr3::read().0.start_address().as_u64()+PHYSMEM_BEGIN);
    let pml4: *mut HWPageTable = GetStartPageTable();
    unsafe {
        // Make all kernel pages global and prevent userspace from accessing them
        for i in 256..512 {
            if (*pml4).index(i).flags().contains(PageTableFlags::PRESENT) {
                (*pml4).index_mut(i).set_flags((*pml4).index(i).flags() & !PageTableFlags::USER_ACCESSIBLE);
                let pdpt = (*pml4).index(i).addr().as_u64() as *mut HWPageTable;
                for j in 0..512 {
                    if (*pdpt).index(j).flags().contains(PageTableFlags::PRESENT) {
                        (*pdpt).index_mut(j).set_flags((*pdpt).index(j).flags() & !PageTableFlags::USER_ACCESSIBLE);
                        if !(*pdpt).index(j).flags().contains(PageTableFlags::HUGE_PAGE) {
                            let pd = (*pdpt).index(j).addr().as_u64() as *mut HWPageTable;
                            for k in 0..512 {
                                if (*pd).index(k).flags().contains(PageTableFlags::PRESENT) {
                                    (*pd).index_mut(k).set_flags((*pd).index(k).flags() & !PageTableFlags::USER_ACCESSIBLE);
                                    if !(*pd).index(k).flags().contains(PageTableFlags::HUGE_PAGE) {
                                        let pt = (*pd).index(k).addr().as_u64() as *mut HWPageTable;
                                        for l in 0..512 {
                                            if (*pt).index(l).flags().contains(PageTableFlags::PRESENT) {
                                                (*pt).index_mut(l).set_flags((*pd).index(k).flags() & !PageTableFlags::USER_ACCESSIBLE);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        x86_64::instructions::tlb::flush_all();
    }
    let mut array: [HeapRange; 64] = [HeapRange {base: 0, length: 0}; 64];
    let mut array_index = 0;
    for i in mmap.iter() {
        let base = (i.base as usize) + (PHYSMEM_BEGIN as usize);
        let end = (base as u64) + i.length;
        let entry_type = match i.entry_type {
            StivaleMemoryMapEntryType::Usable => "Usable",
            StivaleMemoryMapEntryType::Reserved => "Reserved",
            StivaleMemoryMapEntryType::AcpiReclaimable => "ACPI Table Data (Reclaimable)",
            StivaleMemoryMapEntryType::AcpiNvs => "ACPI Non-volatile Storage",
            StivaleMemoryMapEntryType::BadMemory => "Damaged/Bad Memory",
            StivaleMemoryMapEntryType::BootloaderReclaimable => "Usable (Bootloader Data)",
            StivaleMemoryMapEntryType::Kernel => "Raven Kernel/InitRD",
            StivaleMemoryMapEntryType::Framebuffer => "GPU Framebuffer",
        };
        debug!("[mem 0x{:016x}-0x{:016x}] {}", base, end, entry_type);
        if i.entry_type == StivaleMemoryMapEntryType::Usable {
            array[array_index].base = i.base;
            array[array_index].length = i.length;
            array_index += 1;
        } else if i.entry_type == StivaleMemoryMapEntryType::Kernel || i.entry_type == StivaleMemoryMapEntryType::BootloaderReclaimable || i.entry_type == StivaleMemoryMapEntryType::AcpiReclaimable {
            crate::PageFrame::TotalMem.fetch_add(i.length,core::sync::atomic::Ordering::SeqCst);
        }
    }
    Setup(array);
    unsafe { KernelPageTable.lock().Switch(); }
}

////////////////////////////////////////////////////////////////////////////////////////////////////
// This portion has the hardware level paging stuff
pub struct PageTableImpl {
    page_table: &'static mut HWPageTable,
    page_frame: PageFrame<Size4KiB>,
}

fn AllocateFrameToPT(pt: *mut HWPageTable, index: u64) -> PageFrame {
    let flags = PageTableFlags::PRESENT | PageTableFlags::WRITABLE | PageTableFlags::USER_ACCESSIBLE;
    let frame = PhysAddr::new((Allocate(0x1000).unwrap() as u64)-PHYSMEM_BEGIN);
    unsafe {
        (*pt).index_mut(index as usize).set_addr(frame, flags);
        return (*pt).index(index as usize).frame().unwrap();
    }
}

impl PageTableImpl {
    pub fn new() -> Self {
        let frame = (Allocate(0x1000).unwrap() as u64)-PHYSMEM_BEGIN;
        let pt_struct = (frame + PHYSMEM_BEGIN) as *mut HWPageTable;
        unsafe {
            let pt = PageTableImpl {
                page_table: pt_struct.as_mut().unwrap(),
                page_frame: PageFrame::from_start_address(PhysAddr::new(frame)).unwrap() as PageFrame<Size4KiB>,
            };
            let pml4: *mut HWPageTable = GetStartPageTable();
            for i in 256..512 {
                pt.page_table.index_mut(i).set_addr((*pml4).index(i).addr(),(*pml4).index(i).flags());
            }
            pt
        }
    }
}
impl Drop for PageTableImpl {
    fn drop(&mut self) {
        for h in 0..256 {
            if self.page_table.index(h).flags().contains(PageTableFlags::PRESENT) {
                let pd_pagetable = (self.page_table.index(h).addr().as_u64()+PHYSMEM_BEGIN) as *mut HWPageTable;
                unsafe {
                    for i in 0..512 {
                        if (*pd_pagetable).index(i).flags().contains(PageTableFlags::PRESENT) {
                            let pagedirectory = ((*pd_pagetable).index(i).addr().as_u64()+PHYSMEM_BEGIN) as *mut HWPageTable;
                            for j in 0..512 {
                                if (*pagedirectory).index(j).flags().contains(PageTableFlags::PRESENT) {
                                    let pagetable = ((*pagedirectory).index(i).addr().as_u64()+PHYSMEM_BEGIN) as *mut HWPageTable;
                                    for k in 0..512 {
                                        if (*pagetable).index(k).flags().contains(PageTableFlags::PRESENT) {
                                            if (*pagetable).index(k).addr().as_u64() >= PHYSMEM_BEGIN {
                                                Free(((*pagetable).index(k).addr().as_u64()+PHYSMEM_BEGIN) as *mut u8, 0x1000);
                                            }
                                        }
                                    }
                                    Free(pagetable as *mut u8, 0x1000);
                                }
                            }
                            Free(pagedirectory as *mut u8, 0x1000);
                        }
                    }
                    Free(pd_pagetable as *mut u8, 0x1000);
                }
            }
        }
        Free((self.page_frame.start_address().as_u64()+PHYSMEM_BEGIN) as *mut u8, 0x1000);
        self.page_table = unsafe {&mut *(core::ptr::null_mut())};
        self.page_frame = PageFrame::from_start_address(PhysAddr::new(0)).unwrap() as PageFrame<Size4KiB>
    }
}

impl PageTable for PageTableImpl {
    fn Map(&mut self, addr: u64, target: u64) -> Box<dyn PageEntry> {
        let flags = PageTableFlags::PRESENT | PageTableFlags::WRITABLE | PageTableFlags::NO_EXECUTE;
        let pml4_index: usize = ((addr >> 39) & 0x1FF) as usize;
        let pdpt_index: usize = ((addr >> 30) & 0x1FF) as usize;
        let pd_index: usize = ((addr >> 21) & 0x1FF) as usize;
        let pt_index: usize = ((addr >> 12) & 0x1FF) as usize;
        let pd_pagetable = (self.page_table.index(pml4_index).frame().unwrap_or_else(|_val| {
            return AllocateFrameToPT(self.page_table as *mut HWPageTable, 0)
        }).start_address().as_u64()+PHYSMEM_BEGIN) as *mut HWPageTable;
        unsafe {
            let pagedirectory = ((*pd_pagetable).index(pdpt_index).frame().unwrap_or_else(|_val| {
                return AllocateFrameToPT(pd_pagetable, pdpt_index as u64)
            }).start_address().as_u64()+PHYSMEM_BEGIN) as *mut HWPageTable;
            let pagetable = ((*pagedirectory).index(pd_index).frame().unwrap_or_else(|_val| {
                return AllocateFrameToPT(pagedirectory, pd_index as u64)
            }).start_address().as_u64()+PHYSMEM_BEGIN) as *mut HWPageTable;
            (*pagetable).index_mut(pt_index).set_addr(PhysAddr::new(target),flags);
            x86_64::instructions::tlb::flush(VirtAddr::new(addr));
            return Box::new(PageEntryImpl::new((*pagetable).index_mut(pt_index) as *mut PageTableEntry,addr));
        }
    }

    fn Unmap(&mut self, addr: u64) {
        let pml4_index: usize = ((addr >> 39) & 0x1FF) as usize;
        let pdpt_index: usize = ((addr >> 30) & 0x1FF) as usize;
        let pd_index: usize = ((addr >> 21) & 0x1FF) as usize;
        let pt_index: usize = ((addr >> 12) & 0x1FF) as usize;
        if !self.page_table.index(pml4_index).flags().contains(PageTableFlags::PRESENT) {
            return
        }
        let pd_pagetable = (self.page_table.index(pml4_index).frame().unwrap().start_address().as_u64()+PHYSMEM_BEGIN) as *mut HWPageTable;
        unsafe {
            if !(*pd_pagetable).index(pdpt_index).flags().contains(PageTableFlags::PRESENT) {
                return
            }
            let pagedirectory = ((*pd_pagetable).index(pdpt_index).frame().unwrap().start_address().as_u64()+PHYSMEM_BEGIN) as *mut HWPageTable;
            if !(*pagedirectory).index(pd_index).flags().contains(PageTableFlags::PRESENT) {
                return
            }
            let pagetable = ((*pagedirectory).index(pd_index).frame().unwrap().start_address().as_u64()+PHYSMEM_BEGIN) as *mut HWPageTable;
            if !(*pagetable).index(pt_index).flags().contains(PageTableFlags::PRESENT) {
                return
            }
            (*pagetable).index_mut(pt_index).set_addr(PhysAddr::new(0),PageTableFlags::empty());
            x86_64::instructions::tlb::flush(VirtAddr::new(addr));
        }
    }

    fn GetEntry(&self, addr: u64) -> Option<Box<dyn PageEntry>> {
        let pml4_index: usize = ((addr >> 39) & 0x1FF) as usize;
        let pdpt_index: usize = ((addr >> 30) & 0x1FF) as usize;
        let pd_index: usize = ((addr >> 21) & 0x1FF) as usize;
        let pt_index: usize = ((addr >> 12) & 0x1FF) as usize;
        if !self.page_table.index(pml4_index).flags().contains(PageTableFlags::PRESENT) {
            return None;
        }
        let pd_pagetable = (self.page_table.index(pml4_index).frame().unwrap().start_address().as_u64()+PHYSMEM_BEGIN) as *mut HWPageTable;
        unsafe {
            if !(*pd_pagetable).index(pdpt_index).flags().contains(PageTableFlags::PRESENT) {
                return None;
            }
            let pagedirectory = ((*pd_pagetable).index(pdpt_index).frame().unwrap().start_address().as_u64()+PHYSMEM_BEGIN) as *mut HWPageTable;
            if !(*pagedirectory).index(pd_index).flags().contains(PageTableFlags::PRESENT) {
                return None;
            }
            let pagetable = ((*pagedirectory).index(pd_index).frame().unwrap().start_address().as_u64()+PHYSMEM_BEGIN) as *mut HWPageTable;
            if !(*pagetable).index(pt_index).flags().contains(PageTableFlags::PRESENT) {
                return None;
            }
            return Some(Box::new(PageEntryImpl::new((*pagetable).index_mut(pt_index) as *mut PageTableEntry,addr)));
        }
    }

    fn GetMutPageSlice<'a>(&mut self, _addr: u64) -> &'a mut [u8] {
        todo!()
    }

    unsafe fn Switch(&self) {
        x86_64::registers::control::Cr3::write(self.page_frame,Cr3Flags::empty());
    }

    fn Flush() {
        x86_64::instructions::tlb::flush_all();
    }
}

#[repr(C)]
pub struct PageEntryImpl {
    entry: *mut PageTableEntry,
    vaddr: u64,
}

impl PageEntryImpl {
    fn new(entry: *mut PageTableEntry, vaddr: u64) -> Self {
        Self {
            entry,
            vaddr
        }
    }
}

impl PageEntry for PageEntryImpl {
    fn Update(&mut self) {
        x86_64::instructions::tlb::flush(VirtAddr::new(self.vaddr));
    }

    fn Accessed(&self) -> bool { unsafe {(*self.entry).flags().contains(PageTableFlags::ACCESSED)} }

    fn Dirty(&self) -> bool {
        unsafe {(*self.entry).flags().contains(PageTableFlags::DIRTY)}
    }

    fn Writable(&self) -> bool {
        unsafe {(*self.entry).flags().contains(PageTableFlags::WRITABLE)}
    }

    fn Executable(&self) -> bool {
        unsafe {!(*self.entry).flags().contains(PageTableFlags::NO_EXECUTE)}
    }

    fn User(&self) -> bool {
        unsafe {(*self.entry).flags().contains(PageTableFlags::USER_ACCESSIBLE)}
    }

    fn Present(&self) -> bool {
        unsafe {(*self.entry).flags().contains(PageTableFlags::PRESENT)}
    }

    fn ClearAccessed(&mut self) {
        unsafe {
            let mut flags = (*self.entry).flags();
            flags.set(PageTableFlags::ACCESSED, false);
            (*self.entry).set_flags(flags);
        }
    }

    fn ClearDirty(&mut self) {
        unsafe {
            let mut flags = (*self.entry).flags();
            flags.set(PageTableFlags::DIRTY, false);
            (*self.entry).set_flags(flags);
        }
    }

    fn SetWritable(&mut self, value: bool) {
        unsafe {
            let mut flags = (*self.entry).flags();
            flags.set(PageTableFlags::WRITABLE, value);
            (*self.entry).set_flags(flags);
        }
    }

    fn SetExecutable(&mut self, value: bool) {
        unsafe {
            let mut flags = (*self.entry).flags();
            flags.set(PageTableFlags::NO_EXECUTE, !value);
            (*self.entry).set_flags(flags);
        }
    }

    fn SetUser(&mut self, value: bool) {
        unsafe {
            let mut flags = (*self.entry).flags();
            flags.set(PageTableFlags::USER_ACCESSIBLE, value);
            (*self.entry).set_flags(flags);
        }
    }

    fn SetPresent(&mut self, value: bool) {
        unsafe {
            let mut flags = (*self.entry).flags();
            flags.set(PageTableFlags::PRESENT, value);
            (*self.entry).set_flags(flags);
        }
    }

    fn Target(&self) -> u64 {
        unsafe {(*self.entry).addr().as_u64()}
    }

    fn SetTarget(&mut self, target: u64) {
        unsafe {(*self.entry).set_addr(PhysAddr::new(target),(*self.entry).flags());}
    }
}