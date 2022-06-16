use crate::arch::Memory::PageTableImpl;
use crate::PageFrame::{Allocate,Free};
use crate::FS::VFS;
use alloc::vec::Vec;

fn LoadELF(data: &[u8], pt: &mut PageTableImpl) -> Result<usize,()> {
    match xmas_elf::ElfFile::new(data) {
        Ok(elf) => {
            for i in elf.program_iter() {
                if i.align() != 0x1000 {
                    log::error!("Failed to load ELF: \"One of the program sections is not page aligned\"");
                    return Err(());
                }
                let size = i.mem_size().div_ceil(0x1000) * 0x1000;
                let pages = Allocate(size).unwrap();
                let flags = i.flags();
                unsafe {core::ptr::copy((data.as_ptr() as u64 + i.offset()) as *const u8,pages,i.file_size() as usize);}
                if !crate::Memory::MapPages(pt,i.virtual_addr() as usize,pages as usize - crate::arch::PHYSMEM_BEGIN as usize,size as usize,flags.is_write(),flags.is_execute()) {
                    Free(pages,size);
                    log::error!("Failed to load ELF: \"Memory Mapping Failed (Partially loaded!)\"");
                    return Err(());
                }
            }
            crate::Memory::MapPages(pt,0x7FFFFFFFC000,Allocate(0x4000).unwrap() as usize - crate::arch::PHYSMEM_BEGIN as usize,0x4000,true,false);
            return Ok(elf.header.pt2.entry_point() as usize);
        }
        Err(e) => {
            log::error!("Failed to load ELF: \"{}\"", e);
            return Err(());
        }
    }
}

pub fn LoadELFFromPath(path: &str, pt: &mut PageTableImpl) -> Result<usize,isize> {
    match VFS::LookupPath(path) {
        Ok(file) => {
            let size = file.Stat().ok().unwrap().size;
            let mut data: Vec<u8> = Vec::new();
            if size <= 0 {
                return Err(0)
            }
            data.resize(size as usize,0);
            let result = file.Read(0,data.as_mut_slice());
            if result < 0 {
                return Err(result as isize)
            }
            match LoadELF(data.as_slice(),pt) {
                Ok(ret) => {
                    return Ok(ret)
                }
                Err(_) => {
                    return Err(0)
                }
            }
        }
        Err(e) => {
            Err(e.abs() as isize)
        }
    }
}