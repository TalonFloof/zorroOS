# <img align="center" height="100" src="Docs/owlOS Light.png"><br>owlOS

[![forthebadge](https://forthebadge.com/images/badges/made-with-rust.svg)](https://forthebadge.com)
[![forthebadge](data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxNDQuOTciIGhlaWdodD0iMzUiIHZpZXdCb3g9IjAgMCAxNDQuOTcgMzUiPjxyZWN0IGNsYXNzPSJzdmdfX3JlY3QiIHg9IjAiIHk9IjAiIHdpZHRoPSI5MS43NiIgaGVpZ2h0PSIzNSIgZmlsbD0iIzQxOUI1QSIvPjxyZWN0IGNsYXNzPSJzdmdfX3JlY3QiIHg9Ijg5Ljc2IiB5PSIwIiB3aWR0aD0iNTUuMjA5OTk5OTk5OTk5OTk0IiBoZWlnaHQ9IjM1IiBmaWxsPSIjMkY3MzQyIi8+PHBhdGggY2xhc3M9InN2Z19fdGV4dCIgZD0iTTE5LjU3IDIyTDE0LjIyIDIyTDE0LjIyIDEzLjQ3TDE1LjcwIDEzLjQ3TDE1LjcwIDIwLjgyTDE5LjU3IDIwLjgyTDE5LjU3IDIyWk0yNS4yNiAyMkwyMy43OSAyMkwyMy43OSAxMy40N0wyNS4yNiAxMy40N0wyNS4yNiAyMlpNMjkuODAgMTguMTlMMjkuODAgMTguMTlMMjkuODAgMTcuMzlRMjkuODAgMTYuMTkgMzAuMjMgMTUuMjdRMzAuNjYgMTQuMzUgMzEuNDYgMTMuODVRMzIuMjYgMTMuMzUgMzMuMzEgMTMuMzVMMzMuMzEgMTMuMzVRMzQuNzIgMTMuMzUgMzUuNTggMTQuMTJRMzYuNDQgMTQuODkgMzYuNTggMTYuMjlMMzYuNTggMTYuMjlMMzUuMTEgMTYuMjlRMzUuMDAgMTUuMzcgMzQuNTcgMTQuOTZRMzQuMTQgMTQuNTUgMzMuMzEgMTQuNTVMMzMuMzEgMTQuNTVRMzIuMzQgMTQuNTUgMzEuODIgMTUuMjZRMzEuMzAgMTUuOTYgMzEuMjkgMTcuMzNMMzEuMjkgMTcuMzNMMzEuMjkgMTguMDlRMzEuMjkgMTkuNDcgMzEuNzkgMjAuMjBRMzIuMjggMjAuOTIgMzMuMjQgMjAuOTJMMzMuMjQgMjAuOTJRMzQuMTEgMjAuOTIgMzQuNTUgMjAuNTNRMzQuOTkgMjAuMTQgMzUuMTEgMTkuMjJMMzUuMTEgMTkuMjJMMzYuNTggMTkuMjJRMzYuNDUgMjAuNTkgMzUuNTcgMjEuMzVRMzQuNzAgMjIuMTIgMzMuMjQgMjIuMTJMMzMuMjQgMjIuMTJRMzIuMjIgMjIuMTIgMzEuNDQgMjEuNjNRMzAuNjYgMjEuMTUgMzAuMjQgMjAuMjZRMjkuODIgMTkuMzcgMjkuODAgMTguMTlaTTQ2LjQ3IDIyTDQwLjg5IDIyTDQwLjg5IDEzLjQ3TDQ2LjQzIDEzLjQ3TDQ2LjQzIDE0LjY2TDQyLjM4IDE0LjY2TDQyLjM4IDE3LjAyTDQ1Ljg4IDE3LjAyTDQ1Ljg4IDE4LjE5TDQyLjM4IDE4LjE5TDQyLjM4IDIwLjgyTDQ2LjQ3IDIwLjgyTDQ2LjQ3IDIyWk01Mi4xNSAyMkw1MC42NyAyMkw1MC42NyAxMy40N0w1Mi4xNSAxMy40N0w1NS45NyAxOS41NEw1NS45NyAxMy40N0w1Ny40NCAxMy40N0w1Ny40NCAyMkw1NS45NSAyMkw1Mi4xNSAxNS45NUw1Mi4xNSAyMlpNNjEuNzQgMTkuNDJMNjEuNzQgMTkuNDJMNjMuMjMgMTkuNDJRNjMuMjMgMjAuMTUgNjMuNzEgMjAuNTVRNjQuMTkgMjAuOTUgNjUuMDggMjAuOTVMNjUuMDggMjAuOTVRNjUuODYgMjAuOTUgNjYuMjUgMjAuNjNRNjYuNjQgMjAuMzIgNjYuNjQgMTkuODBMNjYuNjQgMTkuODBRNjYuNjQgMTkuMjQgNjYuMjQgMTguOTRRNjUuODQgMTguNjMgNjQuODEgMTguMzJRNjMuNzggMTguMDEgNjMuMTcgMTcuNjNMNjMuMTcgMTcuNjNRNjIuMDEgMTYuOTAgNjIuMDEgMTUuNzJMNjIuMDEgMTUuNzJRNjIuMDEgMTQuNjkgNjIuODUgMTQuMDJRNjMuNjkgMTMuMzUgNjUuMDMgMTMuMzVMNjUuMDMgMTMuMzVRNjUuOTIgMTMuMzUgNjYuNjIgMTMuNjhRNjcuMzEgMTQuMDEgNjcuNzEgMTQuNjFRNjguMTEgMTUuMjIgNjguMTEgMTUuOTZMNjguMTEgMTUuOTZMNjYuNjQgMTUuOTZRNjYuNjQgMTUuMjkgNjYuMjIgMTQuOTFRNjUuODAgMTQuNTQgNjUuMDIgMTQuNTRMNjUuMDIgMTQuNTRRNjQuMjkgMTQuNTQgNjMuODkgMTQuODVRNjMuNDkgMTUuMTYgNjMuNDkgMTUuNzFMNjMuNDkgMTUuNzFRNjMuNDkgMTYuMTggNjMuOTIgMTYuNTBRNjQuMzYgMTYuODEgNjUuMzUgMTcuMTBRNjYuMzUgMTcuNDAgNjYuOTUgMTcuNzhRNjcuNTYgMTguMTYgNjcuODQgMTguNjVRNjguMTIgMTkuMTMgNjguMTIgMTkuNzlMNjguMTIgMTkuNzlRNjguMTIgMjAuODYgNjcuMzAgMjEuNDlRNjYuNDggMjIuMTIgNjUuMDggMjIuMTJMNjUuMDggMjIuMTJRNjQuMTYgMjIuMTIgNjMuMzggMjEuNzdRNjIuNjAgMjEuNDMgNjIuMTcgMjAuODNRNjEuNzQgMjAuMjIgNjEuNzQgMTkuNDJaTTc3Ljk4IDIyTDcyLjQxIDIyTDcyLjQxIDEzLjQ3TDc3Ljk0IDEzLjQ3TDc3Ljk0IDE0LjY2TDczLjg5IDE0LjY2TDczLjg5IDE3LjAyTDc3LjM5IDE3LjAyTDc3LjM5IDE4LjE5TDczLjg5IDE4LjE5TDczLjg5IDIwLjgyTDc3Ljk4IDIwLjgyTDc3Ljk4IDIyWiIgZmlsbD0iI0ZGRkZGRiIvPjxwYXRoIGNsYXNzPSJzdmdfX3RleHQiIGQ9Ik0xMDYuMTUgMjJMMTAzLjk1IDIyTDEwMy45NSAxMy42MEwxMDUuOTAgMTMuNjBMMTA4Ljg2IDE4LjQ1TDExMS43NCAxMy42MEwxMTMuNjkgMTMuNjBMMTEzLjcyIDIyTDExMS41NCAyMkwxMTEuNTEgMTcuNTVMMTA5LjM1IDIxLjE3TDEwOC4zMCAyMS4xN0wxMDYuMTUgMTcuNjdMMTA2LjE1IDIyWk0xMjEuMjYgMjJMMTE4Ljg4IDIyTDExOC44OCAxMy42MEwxMjEuMjYgMTMuNjBMMTIxLjI2IDIyWk0xMjguMjIgMTUuNDhMMTI1LjY0IDE1LjQ4TDEyNS42NCAxMy42MEwxMzMuMTYgMTMuNjBMMTMzLjE2IDE1LjQ4TDEzMC42MCAxNS40OEwxMzAuNjAgMjJMMTI4LjIyIDIyTDEyOC4yMiAxNS40OFoiIGZpbGw9IiNGRkZGRkYiIHg9IjEwMi43NiIvPjwvc3ZnPg==)](https://forthebadge.com)

## What is owlOS?

**owlOS** is a free, open-source **UNIX**-like operating system made from<br>
scratch in the **Rust** Programming Language. The OS run on top of a<br>
kernel known as the **Raven Kernel**.

---
- **owlOS** tries to implement clean APIs to allow developers to easily create programs.
- **owlOS** features modern concepts inside its libraries like **fibers**.
- **owlOS** is portable.
- **owlOS** is open.

<img src="Docs/Screenshot_May_22_22.png" alt="Screenshot of Raven Kernel booting" width="640">

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
<a href="https://opensource.org/licenses/MIT">
  <img align="right" height="96" alt="MIT License" src="Docs/mit-license.png" />
</a>

owlOS, the Raven Kernel, and their core components are licensed under **the MIT License**.<br>
The full text of the license is included in the license file of this software package, which can be accessed [here](COPYING).