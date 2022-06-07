# <img align="center" height="100" src="Docs/owlOS Light.png"><br>owlOS

[![forthebadge](https://forthebadge.com/images/badges/made-with-rust.svg)](https://forthebadge.com)
[![forthebadge](https://forthebadge.com/images/badges/open-source.svg)](https://forthebadge.com)

## What is owlOS?

**owlOS** is a free, open-source **UNIX**-like operating system made from<br>
scratch in the **Rust** Programming Language. The OS run on top of a<br>
kernel known as the **Fox Kernel**.

---
- **owlOS** tries to implement clean APIs to allow developers to easily create programs.
- **owlOS** features modern concepts inside its libraries like **fibers**.
- **owlOS** is portable.
- **owlOS** is open.

<img src="Docs/Screenshot_June_7_22.png" alt="Screenshot of Fox Kernel booting" width="640">

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

---
## License

owlOS, the Fox Kernel, and their core components are licensed under **the Apache License, Version 2.0**.<br>
The full text of the license is included in the license file of this software package, which can be accessed [here](COPYING).
