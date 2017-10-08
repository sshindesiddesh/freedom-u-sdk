RISCV ?= $(CURDIR)/toolchain
PATH := $(RISCV)/bin:$(PATH)

srcdir := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))
srcdir := $(srcdir:/=)
wrkdir := $(CURDIR)/work

toolchain_srcdir := $(srcdir)/riscv-gnu-toolchain
toolchain_wrkdir := $(wrkdir)/riscv-gnu-toolchain
toolchain_dest := $(CURDIR)/toolchain

pk_srcdir := $(srcdir)/riscv-pk
pk_wrkdir := $(wrkdir)/riscv-pk
bbl := $(pk_wrkdir)/bbl
bin := $(wrkdir)/bbl.bin
hex := $(wrkdir)/bbl.hex

target := riscv64-unknown-linux-gnu

.PHONY: all
all: $(hex)
	@echo
	@echo Find the SD-card image in work/bbl.bin
	@echo Program it with: dd if=work/bbl.bin of=/dev/sd-your-card bs=1M
	@echo

$(toolchain_dest)/bin/$(target)-gcc: $(toolchain_srcdir)
	mkdir -p $(toolchain_wrkdir)
	cd $(toolchain_wrkdir); $(toolchain_srcdir)/configure --prefix=$(toolchain_dest)
	$(MAKE) -C $(toolchain_wrkdir) linux

$(bbl): $(pk_srcdir) $(toolchain_dest)/bin/$(target)-gcc
	rm -rf $(pk_wrkdir)
	mkdir -p $(pk_wrkdir)
	cd $(pk_wrkdir) && $</configure \
		--host=$(target)
		#--with-payload=$(vmlinux_stripped)
	$(MAKE) -C $(pk_wrkdir)

$(bin): $(bbl)
	$(target)-objcopy -S -O binary --change-addresses -0x80000000 $< $@

$(hex):	$(bin)
	xxd -c1 -p $< > $@

.PHONY: vmlinux bbl
bbl: $(bbl)

.PHONY: clean
clean:
	rm -rf -- $(wrkdir) $(toolchain_dest)
