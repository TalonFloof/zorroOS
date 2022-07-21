# <img align="center" height="128" src="Docs/owlOS (Full).svg"><br>

[![made-with-rust](https://img.shields.io/badge/Made%20with-Rust-1f425f.svg)](https://www.rust-lang.org/)
[![Hits](https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fgithub.com%2FTalon396%2FowlOS&count_bg=%2379C83D&title_bg=%23323232&icon=&icon_color=%23E7E7E7&title=hits&edge_flat=true)](https://hits.seeyoufarm.com)
[![Lines of Code](https://tokei.rs/b1/github/Talon396/owlOS)](https://github.com/Talon396/owlOS)
[![License](https://img.shields.io/github/license/Talon396/owlOS?logo=apache&style=flat-square)](https://www.apache.org/licenses/LICENSE-2.0)
[![owlOS Developer Builds (AMD64)](https://github.com/Talon396/owlOS/actions/workflows/AMD64_DevBuilds.yml/badge.svg)](https://github.com/Talon396/owlOS/actions/workflows/AMD64_DevBuilds.yml)

## What is owlOS?

**owlOS** is a free, open-source **UNIX**-like operating system made from<br>
scratch in the **Rust** Programming Language. The OS run on top of a<br>
kernel known as the **Fox Kernel**.

---
- **owlOS** tries to implement clean APIs to allow developers to easily create programs.
- **owlOS** is portable.
- **owlOS** is open.

<img src="Docs/Screenshot_June_29_22_FoxKernel.png" alt="Screenshot of Fox Kernel booting" width="640">

<img src="Docs/Screenshot_July_06_22_owlOS.png" alt="Screenshot of owlOS" width="640">

---
## Building

### macOS & Linux

Before trying to build owlOS you need the Rust Toolchain.<br>
You can install it by following the  [offical guide](https://www.rust-lang.org/tools/install). <br>
Follow the instructions given to install Rust onto your computer.<br>

---

**Please use the recommended rustup install process to install Rust 
on your computer. The version of Rust that your package manager
provides will be an old version of Rust. You need Rust 1.60 or
later to compile owlOS. You also need rustup to download the nightly
builds.**

---

Afterwards you need to install the nightly build of `rustc` in order to
build the operating system:
```sh
$ rustup install nightly

$ rustup default nightly
```
---
**Afterwards, please make sure that you have the following software installed:**

- `rustc` needs to be the **Latest Nightly**
- `coreutils` **(or equivilent)**
- `cargo`
- `xorriso`
- `python3`

---
To compile owlOS, you need to know what architecture you want to
target. For this example we'll use `AMD64` (aka x86_64). This is the CPU
architecture that PCs use. Run the following command to build owlOS:
```sh
$ python3 build.py build AMD64 NewWorldPC
```
The build script will automatically create a bootable image for you.

---
**If you want to compile owlOS for an architecture that's not the same
as your host architecture, you'll need to install the appropriate
target or else the build will fail. Here's an example of how to install the toolchain for `RiscV64`:**
```sh
$ rustup target add riscv64gc-unknown-none-elf
```
**Make sure that it ends with
`unknown-none-elf`, `unknown-none`, `none-eabi`, or `none-eabihf`
the other ones are for making software for other operating systems.**
<br><br>
**To see all the targets that Rust officially supports run the following
command:**
```sh
$ rustup target list
```

---
### Windows

owlOS cannot be properly built and ran on Windows, however it is
possible to use WSL (Windows Subsystem for Linux) to compile it.<br>
Other environments like MinGW or Cygwin have not been tested but<br>
should work.

## Running

If building owlOS is too complicated, or you just want to try out owlOS, you can just download the latest ISO
from the "[owlOS Developer Builds (AMD64)](https://github.com/Talon396/owlOS/actions/workflows/AMD64_DevBuilds.yml)" workflow in GitHub Actions.

---

### Running owlOS with QEMU
If you are going to use QEMU to run owlOS, we recommend using these settings:
```sh
$ qemu-system-x86_64 -M q35 -m 1G -enable-kvm -cpu host -device qemu-xhci -serial stdio -smp 4 -cdrom owlOS.iso
```

### Running owlOS with VirtualBox
If you are using VirtualBox, these settings are **required** to run owlOS:
- IOAPIC Enabled
- Chipset: ICH9
- USB: xHCI (USB 3.0+)
- Type: Other/Unknown (64-bit)
- EFI (Optional)

### Running owlOS on Real Hardware

---
**Although owlOS is capable of running on real hardware, IT IS NOT RECOMMENDED TO USE owlOS AS YOUR DAILY DRIVER.**<br>

---

The owlOS ISO can be burned onto a CD/DVD, flashed on a USB Flash Drive, or can be flashed onto an SD Card.<br>
We recommend using [balenaEtcher](https://www.balena.io/etcher/) to flash owlOS onto a USB Flash Drive or SD Card.<br>
balenaEtcher is free, easy to use, and is available on Windows, macOS, and Linux.

---

**owlOS requires the following minimal specs to run on a PC:**
- CPU: AMD64 (x86_64) based CPU with at least One Core. (Two Cores recommended)
- Firmware: ACPI compatible BIOS (UEFI recommended)
- Memory: At least 128 MiB (1 GiB recommended)
- Display: At least 1024x768 with 32-bit color depth
- USB: USB 3.0 or later (USB 2.0 controllers and prior are not supported, USB 2.0 and prior devices are supported)
- Keyboard & Mouse: PS/2 Keyboard & Mouse (USB Keyboard & Mouse isn't supported yet)

---
## License

owlOS, the Fox Kernel, and their core components are licensed under the [Apache License, Version 2.0](https://www.apache.org/licenses/LICENSE-2.0).<br>
The full text of the license is included in the license file of this software package, which can be accessed [here](COPYING).
