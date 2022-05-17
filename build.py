import sys, os, subprocess
from xml.etree.ElementTree import TreeBuilder

args = sys.argv.copy()
del args[0]

termsize = os.get_terminal_size()

if len(args) == 0:
    args.append(input("Action (build, image, run): "))
if len(args) == 1 and args[0] != "pane":
    args.append(input("Architecture: "))
if len(args) == 2 and args[1] != "AMD64" and args[1] != "i686":
    args.append(input("Environment: "))
elif len(args) == 2:
    args.append("pc")

def attempt_build(name,relpath,cmd):
    print("\x1b[1m\x1b[32m🔨Building\x1b[0m\x1b[1m ->\x1b[0m", name, "[\x1b[s\x1b[7\x1b[1m\x1b[5m\x1b[33mWAIT\x1b[0m]",end="")
    sys.stdout.flush()
    path = os.getcwd()
    os.chdir(path+"/"+relpath)
    output = subprocess.run(["/bin/bash","-c","( "+cmd+" ) 2>&1 >/dev/null | python3 "+path+"/build.py pane ; ( exit ${PIPESTATUS[0]} )"])
    #if output.returncode == 0:
    #    os.system("cargo clean 2>/dev/null")
    os.chdir(path)
    if output.returncode != 0:
        print("\x1b[u\x1b[8\x1b[1m\x1b[31mFAIL\x1b[0m]",output.returncode)
        sys.exit(output.returncode)
    else:
        print("\x1b[u\x1b[8\x1b[1m\x1b[32m OK \x1b[0m")
        print("\x1b[s\x1b[7",end="")
        setup_term()
        print("\x1b[u\x1b[8",end="")
        sys.stdout.flush()

def attempt_package(name,relpath,cmds):
    print("\x1b[1m\x1b[32m📦Packaging\x1b[0m\x1b[1m ->\x1b[0m", name, "[\x1b[s\x1b[7\x1b[1m\x1b[5m\x1b[33mWAIT\x1b[0m]",end="")
    sys.stdout.flush()
    path = os.getcwd()
    os.chdir(path+"/"+relpath)
    for i in cmds:
        output = subprocess.run(["/bin/bash","-c","( "+i+" ) 2>&1 >/dev/null | python3 "+path+"/build.py pane ; ( exit ${PIPESTATUS[0]} )"])
        if output.returncode != 0:
            print("\x1b[u\x1b[8\x1b[1m\x1b[31mFAIL\x1b[0m]",output.returncode)
            sys.exit(output.returncode)
    os.chdir(path)
    print("\x1b[u\x1b[8\x1b[1m\x1b[32m OK \x1b[0m")
    print("\x1b[s\x1b[7",end="")
    setup_term()
    print("\x1b[u\x1b[8",end="")
    sys.stdout.flush()

def setup_term():
    half = int(termsize.lines/2)
    print("\x1b["+str(half)+";1H\x1b[1m\x1b[36m"+('▄'*termsize.columns),end="")
    for i in range(half+1,termsize.lines+1):
        print("\x1b["+str(i)+";1H\x1b[0m\x1b[40m\x1b[2K",end="")
    print("\x1b[1;1H\x1b[0m",end="")
    sys.stdout.flush()
def pane_scroll(arr):
    index = 1
    for i in range(int(termsize.lines/2)+1,termsize.lines):
        print("\x1b["+str(i)+";1H\x1b[40m\x1b[2K",end="")
        line = arr[index]
        print(arr[index],end="")
        arr[index-1] = line
        index += 1
    print("\x1b[40m\x1b["+str(termsize.lines)+";1H\x1b[2K",end="")
    arr[len(arr)-1] = ""
    sys.stdout.flush()
def close_pane():
    print("\x1b[s\x1b[7",end="")
    for i in range(int(termsize.lines/2),termsize.lines+1):
        print("\x1b["+str(i)+";1H\x1b[0m\x1b[2K",end="")
    print("\x1b[u\x1b[8",end="")
    sys.stdout.flush()

if args[0] == "build":
    print("\x1b[1;1H\x1b[0J",end="")
    setup_term()
    attempt_build("Raven Kernel","Raven Kernel","cargo build -Z unstable-options --target targets/"+args[1]+".json --color never --out-dir ../out/")
    #attempt_build("Userspace","Userspace","cargo build -Z unstable-options --target .cargo/"+args[1]+".json --color never --out-dir ../out/")
    #path = os.getcwd()
    #servers = os.listdir(path+"/Userspace/owlOS Flock/")
    #for i in range(0,len(servers)):
    #    servers[i] = "\"out/"+servers[i]+"\""
    #attempt_package("InitRD","",(
    #    "mkdir -p /tmp/.owlos_initrd",
    #    "cp -f "+' '.join(servers)+" /tmp/.owlos_initrd/",
    #    "mv /tmp/.owlos_initrd/Alpha /tmp/.owlos_initrd/alpha.rks",
    #    "cd /tmp/.owlos_initrd; tar --format=v7 -cf "+path+"/out/initrd.tar *;cd "+path,
    #    "rm -r -f /tmp/.owlos_initrd"
    #))
    close_pane()

elif args[0] == "image":
    os.system("git clone --branch v3.0-branch-binary --depth 1 https://github.com/limine-bootloader/limine /tmp/limine"),
    os.system("mkdir /tmp/owlos_iso")
    os.system("cp --force /tmp/limine/BOOTX64.EFI /tmp/limine/limine-cd-efi.bin /tmp/limine/limine-cd.bin /tmp/limine/limine.sys out/ravenkernel Boot/AMD64/limine.cfg /tmp/owlos_iso")
    os.system("rm -r --force /tmp/limine")
    os.system("xorriso -as mkisofs -b limine-cd.bin -no-emul-boot -boot-load-size 4 -boot-info-table --efi-boot limine-cd-efi.bin -efi-boot-part --efi-boot-image --protective-msdos-label /tmp/owlos_iso -o owlOS.iso")
    os.system("rm -r --force /tmp/owlos_iso")
elif args[0] == "run":
    if args[1] == "AMD64":
        os.system("clear")
        os.system("(udisksctl unmount --block-device /dev/sdb1) 2>/dev/null >/dev/null")
        os.system("qemu-system-x86_64 \
        -cdrom owlOS.iso \
        -m 128M \
        -smp 4 \
        -no-reboot \
        -cpu host \
        -serial stdio \
        -device qemu-xhci \
        -d cpu_reset \
        -enable-kvm")
elif args[0] == "pane":
    setup_term()
    cursor = int(termsize.lines/2)+1
    column = 1
    print("\x1b["+str(cursor)+";1H",end="")
    sys.stdout.flush()
    c = sys.stdin.read(1)
    arr = [""]
    while c != "":
        if c > '\x1f':
            print("\x1b["+str(cursor)+";"+str(column)+"H",end="")
            print("\x1B[40m"+c,end="")
            sys.stdout.flush()
            column += 1
            if column >= termsize.columns+1:
                column = 1
                if cursor < termsize.lines:
                    cursor += 1
                    arr.append("")
                else:
                    pane_scroll(arr)
            arr[len(arr)-1] = arr[len(arr)-1]+c
        elif c == '\n':
            if cursor < termsize.lines:
                cursor += 1
                column = 1
                arr.append("")
            else:
                column = 1
                pane_scroll(arr)
        c = sys.stdin.read(1)
sys.exit(0)