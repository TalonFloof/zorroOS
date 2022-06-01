use alloc::vec::Vec;
use alloc::vec;
use spin::Mutex;
use x86_64::instructions::port::{PortRead,PortWrite};
use lazy_static::lazy_static;
use crate::Drivers::Arch::PCI::PCI_DEVICES;

lazy_static! {
    static ref PRIMARY_MAJOR: Mutex<ATADrive> = Mutex::new(ATADrive::new(0x1F0,false));
    static ref PRIMARY_MINOR: Mutex<ATADrive> = Mutex::new(ATADrive::new(0x1F0,true));
    static ref SECONDARY_MAJOR: Mutex<ATADrive> = Mutex::new(ATADrive::new(0x170,false));
    static ref SECONDARY_MINOR: Mutex<ATADrive> = Mutex::new(ATADrive::new(0x170,true));
}

#[allow(dead_code)]
const ATA_ERRORS: [&str; 8] = [
    "Couldn't find Address Mark",
    "Couldn't find Track #0",
    "Interrupted",
    "Media Change Request",
    "ID not found",
    "Media Change Interruption",
    "Uncorrectable Data Fault",
    "Dead Block Detected",
];

pub struct ATADrive {
    base: u16,
    is_minor: bool,
    pub identity_buffer: [u16; 256],
    pub supports_48lba: bool,
    pub sectors_on_disk: u64,
    pub is_atapi: bool,
}

impl ATADrive {
    pub fn new(base: u16, is_minor: bool) -> Self {
        Self {
            base,
            is_minor,
            identity_buffer: [0; 256],
            supports_48lba: false,
            sectors_on_disk: 0,
            is_atapi: false,
        }
    }

    pub fn Init(&mut self) {
        unsafe {
            u8::write_to_port(self.base+0x6, if self.is_minor {0xB0} else {0xA0});
            u8::write_to_port(self.base+0x2, 0);
            u8::write_to_port(self.base+0x3, 0);
            u8::write_to_port(self.base+0x4, 0);
            u8::write_to_port(self.base+0x5, 0);
            u8::write_to_port(self.base+0x7, 0xEC);
            let status = u8::read_from_port(self.base+0x7);
            if status == 0 {
                log::info!("ATA {} {}: No Drive", if self.base == 0x1F0 {"Primary"} else {"Secondary"}, if self.is_minor {"Minor"} else {"Major"});
                return;
            }
            let waitstatus = self.PollWait();
            if waitstatus.is_err() {
                log::info!("ATA {} {}: IDENTIFY Failure", if self.base == 0x1F0 {"Primary"} else {"Secondary"}, if self.is_minor {"Minor"} else {"Major"});
                return;
            }
            if u8::read_from_port(self.base+0x4) != 0 && u8::read_from_port(self.base+0x5) != 0 {
                self.is_atapi = true;
                log::info!("ATA {} {}: CD/DVD Drive", if self.base == 0x1F0 {"Primary"} else {"Secondary"}, if self.is_minor {"Minor"} else {"Major"});
                return;
            }
            loop {
                let status = u8::read_from_port(self.base + 0x07);
                if status & 0x8 != 0 {break};
                if status & 0x80 != 0 {
                    log::info!("ATA {} {}: IDENTIFY Failure", if self.base == 0x1F0 {"Primary"} else {"Secondary"}, if self.is_minor {"Minor"} else {"Major"});
                    return;
                }
            }
            for i in 0..256 {
                self.identity_buffer[i] = u16::read_from_port(self.base);
            }
            if self.identity_buffer[83] & 0x400 == 0x400 {
                self.supports_48lba = true;
                self.sectors_on_disk = self.identity_buffer[100] as u64 | ((self.identity_buffer[101] as u64) << 16) | ((self.identity_buffer[102] as u64) << 32) | ((self.identity_buffer[103] as u64) << 48);
            } else {
                self.sectors_on_disk = self.identity_buffer[60] as u64 | ((self.identity_buffer[61] as u64) << 16);
            }
            log::info!("ATA {} {}: Hard Drive ({} MiB)", if self.base == 0x1F0 {"Primary"} else {"Secondary"}, if self.is_minor {"Minor"} else {"Major"}, self.sectors_on_disk/2048);
            return;
        }
    }

    fn Delay400ns(&self) {
        unsafe {
            u8::read_from_port(self.base + 0x07);
            u8::read_from_port(self.base + 0x07);
            u8::read_from_port(self.base + 0x07);
            u8::read_from_port(self.base + 0x07);
        }
    }

    fn PollWait(&self) -> Result<(),i16> {
        loop {
            let status = unsafe {u8::read_from_port(self.base + 0x07)};
            if status & 0x80 == 0 {return Ok(())};
            if status & 0x01 != 0 {
                return Err(0)
            };
        }
    }

    fn Read28(&mut self, lba: u64, count: u16) -> Result<Vec<u8>,i16> {
        unsafe {
            let mut buf = vec![0; count as usize*512];
            u8::write_to_port(self.base+0x6, (if self.is_minor {0xF0} else {0xE0}) | ((lba >> 24) & 0x0F) as u8);
            u8::write_to_port(self.base+0x2, count as u8);
            u8::write_to_port(self.base+0x3, (lba & 0xFF) as u8);
            u8::write_to_port(self.base+0x4, ((lba >> 8) & 0xFF) as u8);
            u8::write_to_port(self.base+0x5, ((lba >> 16) & 0xFF) as u8);
            u8::write_to_port(self.base+0x7, 0x20);
            for i in 0..count {
                self.Delay400ns();
                self.PollWait()?;
                for j in 0..256 {
                    let word = u16::read_from_port(self.base);
                    buf[((i*512)+(j*2)+0) as usize] = (word & 0xFF) as u8;
                    buf[((i*512)+(j*2)+1) as usize] = ((word & 0xFF00) >> 8) as u8;
                }
            }
            Ok(buf)
        }
    }

    fn Read48(&mut self, lba: u64, count: u16) -> Result<Vec<u8>,i16> {
        unsafe {
            let mut buf = vec![0; count as usize*512];
            u8::write_to_port(self.base+0x6, if self.is_minor {0x50} else {0x40});
            u8::write_to_port(self.base+0x2, ((count & 0xFF00) >> 8) as u8);
            u8::write_to_port(self.base+0x3, ((lba >> 24) & 0xFF) as u8);
            u8::write_to_port(self.base+0x4, ((lba >> 32) & 0xFF) as u8);
            u8::write_to_port(self.base+0x5, ((lba >> 40) & 0xFF) as u8);
            u8::write_to_port(self.base+0x2, (count & 0xFF) as u8);
            u8::write_to_port(self.base+0x3, (lba & 0xFF) as u8);
            u8::write_to_port(self.base+0x4, ((lba >> 8) & 0xFF) as u8);
            u8::write_to_port(self.base+0x5, ((lba >> 16) & 0xFF) as u8);
            u8::write_to_port(self.base+0x7, 0x24);
            for i in 0..count {
                self.Delay400ns();
                self.PollWait()?;
                for j in 0..256 {
                    let word = u16::read_from_port(self.base);
                    buf[((i*512)+(j*2)+0) as usize] = (word & 0xFF) as u8;
                    buf[((i*512)+(j*2)+1) as usize] = ((word & 0xFF00) >> 8) as u8;
                }
            }
            Ok(buf)
        }
    }

    fn Write28(&mut self, lba: u64, buf: &[u8]) -> Result<(),i16> {
        unsafe {
            let count = buf.len()/512;
            u8::write_to_port(self.base+0x6, (if self.is_minor {0xF0} else {0xE0}) | ((lba >> 24) & 0x0F) as u8);
            u8::write_to_port(self.base+0x2, count as u8);
            u8::write_to_port(self.base+0x3, (lba & 0xFF) as u8);
            u8::write_to_port(self.base+0x4, ((lba >> 8) & 0xFF) as u8);
            u8::write_to_port(self.base+0x5, ((lba >> 16) & 0xFF) as u8);
            u8::write_to_port(self.base+0x7, 0x30);
            for i in 0..count {
                self.Delay400ns();
                self.PollWait()?;
                for j in 0..256 {
                    u16::write_to_port(self.base,buf[((i*512)+(j*2)+0) as usize] as u16 | ((buf[((i*512)+(j*2)+1) as usize] as u16) << 8));
                }
            }
            self.Flush();
            Ok(())
        }
    }

    fn Write48(&mut self, lba: u64, buf: &[u8]) -> Result<(),i16> {
        unsafe {
            let count = buf.len()/512;
            u8::write_to_port(self.base+0x6, if self.is_minor {0x50} else {0x40});
            u8::write_to_port(self.base+0x2, ((count & 0xFF00) >> 8) as u8);
            u8::write_to_port(self.base+0x3, ((lba >> 24) & 0xFF) as u8);
            u8::write_to_port(self.base+0x4, ((lba >> 32) & 0xFF) as u8);
            u8::write_to_port(self.base+0x5, ((lba >> 40) & 0xFF) as u8);
            u8::write_to_port(self.base+0x2, (count & 0xFF) as u8);
            u8::write_to_port(self.base+0x3, (lba & 0xFF) as u8);
            u8::write_to_port(self.base+0x4, ((lba >> 8) & 0xFF) as u8);
            u8::write_to_port(self.base+0x5, ((lba >> 16) & 0xFF) as u8);
            u8::write_to_port(self.base+0x7, 0x34);
            for i in 0..count {
                self.Delay400ns();
                self.PollWait()?;
                for j in 0..256 {
                    u16::write_to_port(self.base,buf[((i*512)+(j*2)+0) as usize] as u16 | ((buf[((i*512)+(j*2)+1) as usize] as u16) << 8));
                }
            }
            self.Flush();
            Ok(())
        }
    }

    fn Flush(&self) {
        unsafe {
            u8::write_to_port(self.base+0x7, 0xE7);
            self.Delay400ns();
            self.PollWait();
        }
    }

    pub fn Read(&mut self, lba: u64, count: usize) -> Result<Vec<u8>,i16> {
        if lba > 0x0FFFFFFF || count > 0xFF {
            if self.supports_48lba {
                return self.Read48(lba,count as u16);
            } else {
                return Err(i16::MIN);
            }
        } else {
            return self.Read28(lba,count as u16);
        }
    }

    pub fn Write(&mut self, lba: u64, buf: &[u8]) -> Result<(),i16> {
        if lba > 0x0FFFFFFF || buf.len()/512 > 0xFF {
            if self.supports_48lba {
                return self.Write48(lba,buf);
            } else {
                return Err(i16::MIN);
            }
        } else {
            return self.Write28(lba,buf);
        }
    }
}

pub fn Initalize() {
    let lock = PCI_DEVICES.lock();
    for i in lock.iter() {
        if i.class == 0x1 && (i.subclass == 0x1 || i.subclass == 0x5) {
            log::debug!("Computer has ATA, using ATA driver.");
            PRIMARY_MAJOR.lock().Init();
            PRIMARY_MINOR.lock().Init();
            SECONDARY_MAJOR.lock().Init();
            SECONDARY_MINOR.lock().Init();
            return;
        }
    }
    for i in lock.iter() {
        if i.class == 0x1 && i.subclass == 0x6 {
            log::debug!("Computer has AHCI, disabling ATA driver.");
            return;
        } else if i.class == 0x1 && i.subclass == 0x7 {
            log::debug!("Computer has Serial-attached SCSI (SAS), disabling ATA driver.");
            return;
        } else if i.class == 0x1 && i.subclass == 0x8 {
            log::debug!("Computer has NVMe, disabling ATA driver.");
            return;
        } else if i.vendor == 0x1af4 && i.device == 0x1048 {
            log::debug!("Computer has VirtIO SCSI, disabling ATA driver.");
            return;
        }
    }
    log::warn!("Couldn't verify ATA support, will assume that an ATA controller is available.");
}