use x86_64::structures::gdt::{GlobalDescriptorTable, Descriptor};
use x86_64::structures::tss::TaskStateSegment;
use x86_64::registers::segmentation::{CS,SS,SegmentSelector,Segment};
use x86_64::PrivilegeLevel;
use x86_64::addr::VirtAddr;

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
        self.gdt.add_entry(KCODE);
        self.gdt.add_entry(KDATA);
        self.gdt.add_entry(UDATA);
        self.gdt.add_entry(UCODE);
        self.gdt.add_entry(Descriptor::tss_segment(&self.tss));
        self.gdt.load();
        CS::set_reg(SegmentSelector::new(1,PrivilegeLevel::Ring0));
        SS::set_reg(SegmentSelector::new(2,PrivilegeLevel::Ring0));
        x86_64::instructions::tables::load_tss(SegmentSelector::new(5,PrivilegeLevel::Ring0));
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
const KCODE: Descriptor = Descriptor::UserSegment(0x0020980000000000); // EXECUTABLE | USER_SEGMENT | PRESENT | LONG_MODE
const UCODE: Descriptor = Descriptor::UserSegment(0x0020F80000000000); // EXECUTABLE | USER_SEGMENT | USER_MODE | PRESENT | LONG_MODE
const KDATA: Descriptor = Descriptor::UserSegment(0x0000920000000000); // DATA_WRITABLE | USER_SEGMENT | PRESENT
const UDATA: Descriptor = Descriptor::UserSegment(0x0000F20000000000); // DATA_WRITABLE | USER_SEGMENT | USER_MODE | PRESENT