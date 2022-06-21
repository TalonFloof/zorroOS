#!/usr/bin/env python3

import sys, os, subprocess
from xml.etree.ElementTree import TreeBuilder

args = sys.argv.copy()
del args[0]

if len(args) == 0:
    args.append(input("Action (build, run): "))
if len(args) == 1:
    args.append(input("Architecture: "))
if len(args) == 2 and args[1] != "AMD64" and args[1] != "i686":
    args.append(input("Environment: "))
elif len(args) == 2:
    args.append("NewWorldPC")

def attempt_build(name,relpath,cmd):
    print("\x1b[1m\x1b[32m🔨Building\x1b[0m\x1b[1m ->\x1b[0m", name)
    sys.stdout.flush()
    path = os.getcwd()
    os.chdir(path+"/"+relpath)
    output = subprocess.run(["/bin/bash","-c",cmd])
    #if output.returncode == 0:
    #    os.system("cargo clean 2>/dev/null")
    os.chdir(path)
    if output.returncode != 0:
        print("\x1b[1m\x1b[31mFailed\x1b[0m---",output.returncode)
        sys.exit(output.returncode)

def attempt_package(name,relpath,cmds):
    print("\x1b[1m\x1b[32m📦Packaging\x1b[0m\x1b[1m ->\x1b[0m", name)
    sys.stdout.flush()
    path = os.getcwd()
    os.chdir(path+"/"+relpath)
    for i in cmds:
        output = subprocess.run(["/bin/bash","-c",i])
        if output.returncode != 0:
            print("\x1b[1m\x1b[31mFailed\x1b[0m---",output.returncode)
            sys.exit(output.returncode)
    os.chdir(path)

if args[0] == "build":
    attempt_build("Fox Kernel","Fox Kernel","cargo build -Z unstable-options --target targets/"+args[1]+".json --out-dir ../out/")
    attempt_build("Userspace","Userspace","cargo build -Z unstable-options --target .cargo/"+args[1]+".json --out-dir ../out/bin")
    os.system("rm out/bin/*.rlib")
    ##################################################################
    with open("out/root.cpio", "wb") as rootcpio:
        attempt_package("Create InitRD","",("",))
        subprocess.run(["rm","-f","out/root.cpio.gz"])
        output = subprocess.run(["cp","-r","out/bin","Meta/bin"])
        if output.returncode != 0:
            print("\x1b[1m\x1b[31mFailed\x1b[0m---",output.returncode)
            sys.exit(output.returncode)
        output = subprocess.run(["find",".","-type","f"],cwd="Meta/",stdout=subprocess.PIPE)
        if output.returncode != 0:
            print("\x1b[1m\x1b[31mFailed\x1b[0m---",output.returncode)
            sys.exit(output.returncode)
        find = []
        for i in output.stdout.splitlines():
            find.append(i[2:])
        output = subprocess.run(["cpio","-o","-v","--block-size=1"],
                                cwd="Meta/",
                                stdout=rootcpio,
                                input=b'\n'.join(find))
        if output.returncode != 0:
            print("\x1b[1m\x1b[31mFailed\x1b[0m---",output.returncode)
            sys.exit(output.returncode)
    output = subprocess.run(["gzip","-9","out/root.cpio"])
    if output.returncode != 0:
        print("\x1b[1m\x1b[31mFailed\x1b[0m---",output.returncode)
        sys.exit(output.returncode)
    output = subprocess.run(["rm","-r","Meta/bin"])
    if output.returncode != 0:
        print("\x1b[1m\x1b[31mFailed\x1b[0m---",output.returncode)
        sys.exit(output.returncode)
    ##################################################################
    if args[1] == "AMD64":
        attempt_package("Create ISO", "", (
            "git clone --branch v3.6-binary --depth 1 https://github.com/limine-bootloader/limine /tmp/limine",
            "mkdir -p /tmp/owlos_iso/EFI/BOOT",
            "cp --force /tmp/limine/BOOTX64.EFI /tmp/limine/limine-cd-efi.bin /tmp/limine/limine-cd.bin /tmp/limine/limine.sys out/foxkernel out/root.cpio.gz Boot/AMD64/limine.cfg /tmp/owlos_iso",
            "mv /tmp/owlos_iso/BOOTX64.EFI /tmp/owlos_iso/EFI/BOOT/BOOTX64.EFI",
            "xorriso -as mkisofs \
            -b limine-cd.bin \
            -no-emul-boot \
            -boot-load-size 4 \
            -boot-info-table \
            --efi-boot limine-cd-efi.bin \
            -efi-boot-part \
            --efi-boot-image \
            --protective-msdos-label \
            /tmp/owlos_iso -o owlOS.iso",
            "clang /tmp/limine/limine-deploy.c -o /tmp/limine/limine-deploy",
            "/tmp/limine/limine-deploy owlOS.iso",
            "rm -r --force /tmp/limine",
            "rm -r --force /tmp/owlos_iso",    
        ))
elif args[0] == "run":
    if args[1] == "AMD64":
        os.system("clear")
        os.system("qemu-system-x86_64 \
        -cdrom owlOS.iso \
        -m 128M \
        -smp 4 \
        -no-reboot \
        -cpu host \
        -serial stdio \
        -device qemu-xhci \
        -enable-kvm")
sys.exit(0)