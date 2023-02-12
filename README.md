<!--<p align="center"><a href="https://github.com/Talon396/zorroOS/tree/legacy">Looking for owlOS? You can find it here.</a><br><img align="center" height="128" src="docs/zorroOS.svg"><br></p>-->

# **zorroOS**: An elegant, microkernel-based operating system

**zorroOS** is a hobby operating system written in ANSI C (with the GNU Extensions), currently targeting x86_64 and 64-bit RISC-V boards.

## Building

First, clone the repository
```sh
$ git clone --recursive https://github.com/TalonFox/zorroOS
```
Then, enter the directory and follow the instructions for the architecture you want to target.

## RiscV64

First, modify the constant `ARCH` in `kernel/Makefile` to be set to `RiscV64`.

Ensure that you have a RISC-V toolchain installed.
If you don't, you can get one here: [https://github.com/riscv-collab/riscv-gnu-toolchain](https://github.com/riscv-collab/riscv-gnu-toolchain).

Then run `make build-rv64`:
```sh
$ make build-rv64
```

You can then run the kernel using `qemu-system-riscv64`:
```sh
$ qemu-system-riscv64 -kernel [Path to Kernel] -serial stdio
```

> Note: The build system for RISC-V will be improved in the future.

## x86_64

First, modify the constant `ARCH` in `kernel/Makefile` to be set to `x86_64`.

Then, ensure that you have a x86_64 cross-compiler.

On Arch Linux you can get it using yay:
```sh
$ yay -S x86_64-elf-gcc
```

On macOS you can use brew to install it:
```sh
$ brew install x86_64-elf-gcc
```

Finally run `make iso`:
```sh
$ make iso
```

It will then generate an ISO named, `zorroOS.iso`. 

You can then run it using `qemu-system-x86_64`:
```sh
$ qemu-system-x86_64 -cdrom zorroOS.iso -M q35 -enable-kvm -serial stdio
```

### Note that zorroOS is currently a WIP and many features are not complete yet.

## License

zorroOS is licensed under the MIT License.    
The full text of the license is included in the license file of this software package, which can be accessed [here](COPYING).
