<!--<p align="center"><a href="https://github.com/Talon396/zorroOS/tree/legacy">Looking for owlOS? You can find it here.</a><br><img align="center" height="128" src="docs/zorroOS.svg"><br></p>-->

# **zorroOS**: A hobby operating system written from scratch

<p align="center"><a href="https://raw.githubusercontent.com/TalonFox/zorroOS/main/docs/The%20History%20of%20zorroOS.svg">Celebrating 3 years of zorroOS! 🎉🦊</a></p>

**zorroOS** is a hobby operating system written in Zig, currently targeting x86_64 PCs.

## Building

Building zorroOS is simple.    
First, ensure that you have the following depenedencies:
- `zig` (At least latest stable)
- `nasm`
- `xorriso`
- `git`

Then, clone the repository
```sh
$ git clone https://github.com/TalonFox/zorroOS --recursive
$ cd zorroOS
```
After cloning it, simply run `make iso` and a ISO named `zorroOS.iso` will be generated.    
You can then run this using an virtual machine/emulator such as QEMU, Bochs, VirtualBox, or VMWare.
You can also flash this onto a USB drive and boot it onto real hardware, if you would rather do that.

## License

zorroOS is licensed under the MIT License.    
The full text of the license is included in the license file of this software package, which can be accessed [here](COPYING).
