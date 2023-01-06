<!--<p align="center"><a href="https://github.com/Talon396/zorroOS/tree/legacy">Looking for owlOS? You can find it here.</a><br><img align="center" height="128" src="docs/zorroOS.svg"><br></p>-->

# **zorroOS**: An elegant, microkernel-based operating system

**zorroOS** is a hobby operating system written in ANSI C (with the GNU Extensions), currently targeting AMD64 and plans to also target RISC-V boards.

## Building

Ensure that you have a cross compiler installed before attempting to build.

On Arch Linux you can get it using yay:
```sh
$ yay -S x86_64-elf-gcc
```

On macOS you can use brew to install it:
```sh
$ brew install x86_64-elf-gcc
```

Afterwards clone the repository:
```sh
$ git clone --recursive https://github.com/Talon396/zorroOS
```

Finally enter the directory and run `make iso`:
```sh
$ cd zorroOS
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
