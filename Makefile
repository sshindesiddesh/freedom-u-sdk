.SECONDARY:

RISCV ?= $(CURDIR)/toolchain
PATH := $(RISCV)/bin:$(PATH)

srcdir := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))
srcdir := $(srcdir:/=)
confdir := $(srcdir)/conf
wrkdir := $(CURDIR)/work

toolchain_srcdir := $(srcdir)/riscv-gnu-toolchain
toolchain_wrkdir := $(wrkdir)/riscv-gnu-toolchain
toolchain_dest := $(CURDIR)/toolchain

buildroot_srcdir := $(srcdir)/buildroot
buildroot_wrkdir := $(wrkdir)/buildroot
buildroot_tar := $(buildroot_wrkdir)/images/rootfs.tar

sysroot_stamp := $(wrkdir)/.sysroot
sysroot := $(wrkdir)/sysroot

linux_srcdir := $(srcdir)/linux
linux_wrkdir := $(wrkdir)/linux
linux_defconfig := $(confdir)/linux_defconfig

vmlinux := $(linux_wrkdir)/vmlinux
vmlinux_stripped := $(linux_wrkdir)/vmlinux-stripped

pk_srcdir := $(srcdir)/riscv-pk
pk_wrkdir := $(wrkdir)/riscv-pk
spike_bbl := $(pk_wrkdir)/spike/bbl
spike_bin := $(pk_wrkdir)/spike/bbl.bin
spike_hex := $(pk_wrkdir)/spike/bbl.hex
vc707_bbl := $(pk_wrkdir)/sifive-vc707-devkit/bbl
vc707_bin := $(pk_wrkdir)/sifive-vc707-devkit/bbl.bin
vc707_hex := $(pk_wrkdir)/sifive-vc707-devkit/bbl.hex

fesvr_srcdir := $(srcdir)/riscv-fesvr
fesvr_wrkdir := $(wrkdir)/riscv-fesvr
libfesvr := $(fesvr_wrkdir)/prefix/lib/libfesvr.so

spike_srcdir := $(srcdir)/riscv-isa-sim
spike_wrkdir := $(wrkdir)/riscv-isa-sim
spike := $(spike_wrkdir)/prefix/bin/spike

target := riscv64-unknown-linux-gnu

.PHONY: all
all: $(vc707_bin)
	@echo
	@echo Find the SD-card image in $<
	@echo Program it with: dd if=$< of=/dev/sd-your-card bs=1M
	@echo

$(toolchain_dest)/bin/$(target)-gcc: $(toolchain_srcdir)
	mkdir -p $(toolchain_wrkdir)
	cd $(toolchain_wrkdir); $(toolchain_srcdir)/configure --prefix=$(toolchain_dest)
	$(MAKE) -C $(toolchain_wrkdir) linux

$(buildroot_tar): $(buildroot_srcdir) $(RISCV)/bin/$(target)-gcc
	$(MAKE) -C $< RISCV=$(RISCV) PATH=$(PATH) O=$(buildroot_wrkdir) riscv64_defconfig
	$(MAKE) -C $< RISCV=$(RISCV) PATH=$(PATH) O=$(buildroot_wrkdir)

.PHONY: buildroot-menuconfig
buildroot-menuconfig: $(buildroot_srcdir)
	$(MAKE) -C $< O=$(buildroot_wrkdir) menuconfig

$(sysroot_stamp): $(buildroot_tar)
	mkdir -p $(sysroot)
	tar -xpf $< -C $(sysroot) --exclude ./dev --exclude ./usr/share/locale
	date > $@

$(linux_wrkdir)/.config: $(linux_defconfig) $(linux_srcdir)
	mkdir -p $(dir $@)
	cp -p $< $@
	$(MAKE) -C $(linux_srcdir) O=$(linux_wrkdir) ARCH=riscv olddefconfig
	touch -c $@

$(vmlinux): $(linux_srcdir) $(linux_wrkdir)/.config $(sysroot_stamp)
	$(MAKE) -C $< O=$(linux_wrkdir) \
		CROSS_COMPILE=$(target)- \
		CONFIG_INITRAMFS_SOURCE="$(confdir)/initramfs.txt $(sysroot)" \
		CONFIG_INITRAMFS_ROOT_UID=$(shell id -u) \
		CONFIG_INITRAMFS_ROOT_GID=$(shell id -g) \
		ARCH=riscv \
		vmlinux
	touch -c $@

$(vmlinux_stripped): $(vmlinux)
	$(target)-strip -o $@ $<
	touch -c $@

.PHONY: linux-menuconfig
linux-menuconfig: $(linux_wrkdir)/.config
	$(MAKE) -C $(linux_srcdir) O=$(dir $<) ARCH=riscv menuconfig savedefconfig

%/bbl: $(pk_srcdir) $(vmlinux_stripped)
	rm -rf $(dir $@)
	mkdir -p $(dir $@)
	cd $(dir $@) && $</configure \
		--host=$(target) \
		--with-payload=$(vmlinux_stripped) \
		--with-platform=$(lastword $(subst /, ,$(dir $@))) \
		--enable-logo \
		--enable-print-device-tree
	$(MAKE) -C $(dir $@)
	touch -c $@

%/bbl.bin: %/bbl
	$(target)-objcopy -S -O binary --change-addresses -0x80000000 $< $@
	touch -c $@

%/bbl.hex: %/bbl.bin
	xxd -c1 -p $< > $@
	touch -c $@

$(libfesvr): $(fesvr_srcdir)
	rm -rf $(fesvr_wrkdir)
	mkdir -p $(fesvr_wrkdir)
	mkdir -p $(dir $@)
	cd $(fesvr_wrkdir) && $</configure \
		--prefix=$(dir $(abspath $(dir $@)))
	$(MAKE) -C $(fesvr_wrkdir)
	$(MAKE) -C $(fesvr_wrkdir) install
	touch -c $@

$(spike): $(spike_srcdir) $(libfesvr)
	rm -rf $(spike_wrkdir)
	mkdir -p $(spike_wrkdir)
	mkdir -p $(dir $@)
	cd $(spike_wrkdir) && $</configure \
		--prefix=$(dir $(abspath $(dir $@))) \
		--with-fesvr=$(dir $(abspath $(dir $(libfesvr))))
	$(MAKE) -C $(spike_wrkdir)
	$(MAKE) -C $(spike_wrkdir) install
	touch -c $@

.PHONY: sysroot vmlinux bbl spike
sysroot: $(sysroot)
vmlinux: $(vmlinux)
bbl: $(spike_bbl) $(vc707_bbl)
spike: $(spike)

.PHONY: clean
clean:
	rm -rf -- $(wrkdir) $(toolchain_dest)

.PHONY: sim
sim: $(spike) $(spike_bbl)
	$(spike) -p4 $(spike_bbl)
