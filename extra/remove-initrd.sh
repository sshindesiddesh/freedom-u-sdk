#! /bin/sh
../toolchain/bin/riscv64-unknown-linux-gnu-gcc -Wall -O2 quit.c  -o quit -nostartfiles -static
../toolchain/bin/riscv64-unknown-linux-gnu-strip -S quit
rm -rf ../work/sysroot
mkdir -p ../work/sysroot/bin
cp quit ../work/sysroot/bin/busybox
