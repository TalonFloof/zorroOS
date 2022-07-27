use crate::arch::Memory::PageTableImpl;
use crate::PageFrame::{Allocate,Free};
use crate::FS::VFS;
use alloc::vec::Vec;
use alloc::string::String;

fn LoadELF(path: &str, inode_id: i64, data: &[u8], pt: &mut PageTableImpl, seg: &mut Vec<(usize,usize,String,u8,i64,usize)>) -> Result<usize,()> {
    match xmas_elf::ElfFile::new(data) {
        Ok(elf) => {
            /*if path != "/usr/lib/ld.so" {
                seg.push((0,4096,String::from("[zero_page]"),0,0,0));
            }*/
            let mut entry = elf.header.pt2.entry_point();
            let mut highest_addr = 0;
            for i in elf.program_iter() {
                match i.get_type().expect("Invalid ELF Type") {
                    xmas_elf::program::Type::Load => {
                        if i.align() != 0x1000 {
                            log::error!("Failed to load ELF: \"One of the program sections is not page aligned\"");
                            return Err(());
                        }
                        let size = i.mem_size().div_ceil(0x1000) * 0x1000;
                        if i.virtual_addr() + size > highest_addr {
                            highest_addr = i.virtual_addr() + size;
                        }
                        let pages = Allocate(size).unwrap();
                        let flags = i.flags();
                        unsafe {core::ptr::copy((data.as_ptr() as u64 + i.offset()) as *const u8,pages,i.file_size() as usize);}
                        seg.push((i.virtual_addr() as usize,size as usize,String::from(path),1 | if flags.is_write() {2} else {0} | if flags.is_execute() {4} else {0},inode_id,i.offset() as usize));
                        if !crate::Memory::MapPages(pt,i.virtual_addr() as usize,pages as usize - crate::arch::PHYSMEM_BEGIN as usize,size as usize,flags.is_write(),flags.is_execute()) {
                            Free(pages,size);
                            log::error!("Failed to load ELF: \"Memory Mapping Failed (Partially loaded!)\"");
                            return Err(());
                        }
                    }
                    xmas_elf::program::Type::Interp => { // This executable uses shared libraries
                        match LoadELFFromPath(String::from("/usr/lib/ld.so"),pt,seg) {
                            Err(ret) => {
                                log::error!("Failed to load Dynamic Linker: {}", ret);
                                return Err(());
                            }
                            Ok(a) => {
                                entry = a as u64;
                            }
                        }
                    }
                    _ => {}
                }
            }
            if path != "/usr/lib/ld.so" {
                seg.push((0x7f8000000000,0x8000000000,String::from("[stack]"),3,0,0));
            }
            seg.sort_by(|a,b| a.0.partial_cmp(&b.0).unwrap());
            return Ok(entry as usize);
        }
        Err(e) => {
            log::error!("Failed to load ELF: \"{}\"", e);
            return Err(());
        }
    }
}

pub fn LoadELFFromPath(path: String, pt: &mut PageTableImpl, seg: &mut Vec<(usize,usize,String,u8,i64,usize)>) -> Result<usize,isize> {
    match VFS::LookupPath(path.as_str()) {
        Ok(file) => {
            let size = file.Stat().ok().unwrap().size;
            let id = file.Stat().ok().unwrap().inode_id;
            let mut data: Vec<u8> = Vec::new();
            if size <= 0 {
                return Err(0)
            }
            data.resize(size as usize,0);
            let result = file.Read(0,data.as_mut_slice());
            if result < 0 {
                return Err(result as isize)
            }
            match LoadELF(path.as_str(),id,data.as_slice(),pt,seg) {
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