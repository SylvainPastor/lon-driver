# Top-level build driver for the EnOcean/Echelon LON driver.
#
# Targets:
#   make            -> build the u61 kernel module + the lonifd daemon (default)
#   make u61        -> build only the u61 (parallel/UMIP, FTDI/ttyUSB) kernel module
#   make u50        -> build only the u50 (serial/SMIP, CDC-ACM/ttyACM) kernel module
#   make modules    -> build both kernel modules
#   make lonifd     -> build only the user-space lonifd daemon
#   make install    -> (sudo) load the u61.ko kernel module
#   make start      -> (sudo) start the lonifd daemon on $(DEV)
#   make clean      -> remove all build artifacts
#
# Override the kernel tree or device if needed, e.g.:
#   make KDIR=/lib/modules/6.17.0-35-generic/build
#   make start DEV=/dev/ttyUSB1

KDIR    ?= /lib/modules/$(shell uname -r)/build
PWD     := $(CURDIR)
MODDIRS := u61 u50

# Runtime parameters for the u61 dongle (line discipline 27, FTDI/ttyUSB).
DEV     ?= /dev/ttyUSB0
LDISC   ?= 27

# lonifd needs libsystemd (sd_notify / sd-daemon.h).
LONIFD_CFLAGS := $(shell pkg-config --cflags libsystemd 2>/dev/null)
LONIFD_LIBS   := $(shell pkg-config --libs libsystemd 2>/dev/null)
LONIFD_LIBS   := $(if $(LONIFD_LIBS),$(LONIFD_LIBS),-lsystemd)

.PHONY: all modules u61 u50 lonifd install start clean

all: u61 lonifd

modules: u61 u50

u61:
	$(MAKE) -C $(KDIR) M=$(PWD)/u61 modules

u50:
	$(MAKE) -C $(KDIR) M=$(PWD)/u50 modules

lonifd: lonifd/lonifd

lonifd/lonifd: lonifd/lonifd.c
	$(CC) $(LONIFD_CFLAGS) -O2 -Wall -o $@ $< $(LONIFD_LIBS)

# Load the u61 kernel module (reloads it if already inserted).
install: u61
	@if lsmod | grep -q '^u61[[:space:]]'; then \
	  echo "  RMMOD   u61 (already loaded)"; sudo rmmod u61; \
	fi
	@echo "  INSMOD  u61/u61.ko"
	sudo insmod u61/u61.ko

# Start the lonifd daemon on the dongle (creates the lonX interface).
# Requires the u61 module to be loaded first (make install).
start: lonifd
	sudo ./lonifd/lonifd -d $(DEV) -l $(LDISC)

clean:
	rm -f lonifd/lonifd
	@for d in $(MODDIRS); do \
	  echo "  CLEAN   $$d"; \
	  rm -f $$d/*.o $$d/*.ko $$d/*.mod $$d/*.mod.c $$d/*.mod.o \
	        $$d/*.symvers $$d/Module.symvers $$d/modules.order $$d/*.order; \
	  rm -f $$d/.*.cmd; \
	  rm -rf $$d/.tmp_versions; \
	done
