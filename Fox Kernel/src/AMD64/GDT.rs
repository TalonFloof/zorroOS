use x86_64::structures::gdt::{Descriptor,DescriptorFlags};
use x86_64::structures::tss::TaskStateSegment;
use x86_64::structures::DescriptorTablePointer;
use x86_64::registers::segmentation::{CS,SS,SegmentSelector,Segment};
use x86_64::PrivilegeLevel;
use x86_64::addr::VirtAddr;

#[derive(Debug, Clone)]
pub struct GlobalDescriptorTable {
    table: [u64; 16],
    len: usize,
}
impl GlobalDescriptorTable {
    pub fn new() -> Self {
        GlobalDescriptorTable {
            table: [0; 16],
            len: 1,
        }
    }
    #[inline]
    pub fn add_entry(&mut self, entry: Descriptor) -> SegmentSelector {
        let index = match entry {
            Descriptor::UserSegment(value) => {
                if self.len > self.table.len().saturating_sub(1) {
                    panic!("GDT full")
                }
                self.push(value)
            }
            Descriptor::SystemSegment(value_low, value_high) => {
                if self.len > self.table.len().saturating_sub(2) {
                    panic!("GDT requires two free spaces to hold a SystemSegment")
                }
                let index = self.push(value_low);
                self.push(value_high);
                index
            }
        };

        let rpl = match entry {
            Descriptor::UserSegment(value) => {
                if DescriptorFlags::from_bits_truncate(value).contains(DescriptorFlags::DPL_RING_3)
                {
                    PrivilegeLevel::Ring3
                } else {
                    PrivilegeLevel::Ring0
                }
            }
            Descriptor::SystemSegment(_, _) => PrivilegeLevel::Ring0,
        };

        SegmentSelector::new(index as u16, rpl)
    }
    #[inline]
    pub fn load(&'static self) {
        // SAFETY: static lifetime ensures no modification after loading.
        unsafe { self.load_unsafe() };
    }
    #[inline]
    pub unsafe fn load_unsafe(&self) {
        use x86_64::instructions::tables::lgdt;
        lgdt(&self.pointer());
    }
    #[inline]
    fn push(&mut self, value: u64) -> usize {
        let index = self.len;
        self.table[index] = value;
        self.len += 1;
        index
    }
    fn pointer(&self) -> DescriptorTablePointer {
        use core::mem::size_of;
        DescriptorTablePointer {
            base: VirtAddr::new(self.table.as_ptr() as u64),
            limit: (self.len * size_of::<u64>() - 1) as u16,
        }
    }
}

pub struct Hart {
    pub gdt: GlobalDescriptorTable,
    pub tss: TaskStateSegment,
    pub scdata: [u64; 3],
}

pub static mut HARTS: [Option<Hart>; 64] = [
    None, None, None, None, None, None, None, None, None, None, None, None, None, None, None, None,
    None, None, None, None, None, None, None, None, None, None, None, None, None, None, None, None,
    None, None, None, None, None, None, None, None, None, None, None, None, None, None, None, None,
    None, None, None, None, None, None, None, None, None, None, None, None, None, None, None, None,
];

impl Hart {
    pub fn new() -> Self {
        Hart {
            gdt: GlobalDescriptorTable::new(),
            tss: TaskStateSegment::new(),
            scdata: [0u64; 3],
        }
    }
    pub unsafe fn init(&'static mut self, stack_top: u64) {
        self.tss.privilege_stack_table[0] = VirtAddr::new(stack_top);
        self.scdata[0] = stack_top;
        self.gdt.add_entry(LIMINE_16CODE); // 0x08
        self.gdt.add_entry(LIMINE_16DATA); // 0x10
        self.gdt.add_entry(LIMINE_32CODE); // 0x18
        self.gdt.add_entry(LIMINE_32DATA); // 0x20
        self.gdt.add_entry(KCODE);         // 0x28
        self.gdt.add_entry(KDATA);         // 0x30
        self.gdt.add_entry(UDATA);         // 0x3B
        self.gdt.add_entry(UCODE);         // 0x43
        self.gdt.add_entry(Descriptor::tss_segment(&self.tss));
        self.gdt.load();
        CS::set_reg(SegmentSelector::new(5,PrivilegeLevel::Ring0));
        SS::set_reg(SegmentSelector::new(6,PrivilegeLevel::Ring0));
        x86_64::instructions::tables::load_tss(SegmentSelector::new(9,PrivilegeLevel::Ring0));
        x86_64::registers::model_specific::GsBase::write(VirtAddr::new(0u64));
        x86_64::registers::model_specific::KernelGsBase::write(VirtAddr::new(self.scdata.as_ptr() as u64));
    }
    pub fn set_rsp0(&mut self, addr: u64) {
        self.tss.privilege_stack_table[0] = VirtAddr::new(addr);
        self.scdata[0] = addr;
    }
}

pub fn Setup(stack_top: u64) {
    unsafe {
        HARTS[0] = Some(Hart::new());
        HARTS[0].as_mut().unwrap().init(stack_top);
    }
}

// Copied from xv6 x86_64 (Yes, I credit work here!)
const LIMINE_16CODE: Descriptor = Descriptor::UserSegment(0x00009a000000ffff);
const LIMINE_16DATA: Descriptor = Descriptor::UserSegment(0x000092000000ffff);
const LIMINE_32CODE: Descriptor = Descriptor::UserSegment(0x00cf9a000000ffff);
const LIMINE_32DATA: Descriptor = Descriptor::UserSegment(0x00cf92000000ffff);
const KCODE: Descriptor = Descriptor::UserSegment(0x00209A0000000000); // EXECUTABLE | USER_SEGMENT | PRESENT | LONG_MODE
const UCODE: Descriptor = Descriptor::UserSegment(0x0020FA0000000000); // EXECUTABLE | USER_SEGMENT | USER_MODE | PRESENT | LONG_MODE
const KDATA: Descriptor = Descriptor::UserSegment(0x0000920000000000); // DATA_WRITABLE | USER_SEGMENT | PRESENT
const UDATA: Descriptor = Descriptor::UserSegment(0x0000F20000000000); // DATA_WRITABLE | USER_SEGMENT | USER_MODE | PRESENT