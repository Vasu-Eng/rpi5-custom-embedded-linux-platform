# SPI0 Bring-up Investigation - Raspberry Pi 5 Custom BusyBox Linux

**Author:** Vasu
**Date:** 2026-06-28
**Project:** Raspberry Pi 5 Custom Embedded Linux (BusyBox + Dropbear)
**Branch:** `lcd-bring-up`

---

# 1. Objective

Investigate why the SPI0 controller is unavailable in a custom BusyBox-based Linux image while functioning correctly on Raspberry Pi OS.

The ultimate objective is to bring up a 3.5-inch SPI LCD on a custom Linux image built from scratch without Buildroot or Yocto.

---

# 2. Initial Problem Statement

## Raspberry Pi OS

SPI controller detected correctly.

```bash
$ ls /sys/class/spi_master

spi0
spi10
```

```bash
$ ls /sys/bus/spi/devices

spi0.0
spi0.1
spi10.0
```

Kernel modules loaded:

```bash
$ lsmod | grep spi

spidev
spi_bcm2835
spi_dw_mmio
spi_dw
```

---

## Custom BusyBox Image

SPI controller not detected.

```bash
$ ls /sys/class/spi_master

(No spi0)
```

LCD bring-up impossible.

---

# 3. Investigation Timeline

---

## Step 1 — Verify Running Device Tree

Dumped the runtime Device Tree.

```bash
dtc -I fs -O dts /proc/device-tree > running.dts
```

Found:

```dts
spi@50000 {

    compatible = "snps,dw-apb-ssi";

    status = "okay";
}
```

Device aliases:

```dts
spi0 = "/axi/pcie@1000120000/rp1/spi@50000";
```

### Observation

On Raspberry Pi 5,

SPI0 connected to the 40-pin GPIO header is implemented inside the RP1 I/O controller.

It is **not** the same controller as:

```
spi10
```

located inside BCM2712.

---

## Step 2 — Decompile Base Device Tree

Firmware selected:

```
bcm2712-rpi-5-b.dtb
```

Decompiled:

```bash
dtc -I dtb -O dts bcm2712-rpi-5-b.dtb > static.dts
```

Found:

```dts
spi@50000 {

    status = "disabled";
}
```

### Observation

Base Device Tree disables SPI0.

---

## Step 3 — Runtime vs Static DT Comparison

Runtime DT:

```dts
status = "okay";
```

Static DT:

```dts
status = "disabled";
```

### Conclusion

Some component modifies the Device Tree before Linux boots.

---

## Step 4 — Firmware Boot Investigation

Collected firmware logs.

```bash
sudo vclog -m
```

Important entries:

```
dtb_file 'bcm2712-rpi-5-b.dtb'

Loaded overlay 'bcm2712d0'

Loaded overlay 'sunfounder-pironman5.dtbo'

Loaded overlay 'vc4-kms-v3d-pi5'

Device tree loaded ...
```

### Conclusion

Firmware performs Device Tree merging before Linux starts.

Linux never sees:

* Base DTB
* Individual overlays

Instead it receives one final merged DTB.

---

## Step 5 — Overlay Investigation

Decompiled

```
sunfounder-pironman5.dtbo
```

Found:

```dts
fragment@1 {

    target = <&spi0>;

    __overlay__ {

        status = "okay";

    };

};
```

### Observation

The overlay enables SPI0.

Equivalent source:

```dts
&spi0 {

    status = "okay";
};
```

---

## Step 6 — Firmware Merge Verification

Verified:

```
Base DTB
```

↓

```
SPI0 Disabled
```

↓

```
SunFounder Overlay
```

↓

```
SPI0 Enabled
```

↓

```
Running Device Tree
```

↓

```
status = "okay"
```

Confirmed that firmware merges overlays before handing the DTB to Linux.

---

## Step 7 — Raspberry Pi Boot Sequence Investigation

Verified boot flow.

```
EEPROM Bootloader

↓

Firmware

↓

Read config.txt

↓

Select bcm2712-rpi-5-b.dtb

↓

Load bcm2712d0.dtbo

↓

Load sunfounder-pironman5.dtbo

↓

Load vc4-kms-v3d-pi5.dtbo

↓

Merge DTB

↓

Load kernel_2712.img

↓

Start Linux
```

---

## Step 8 — Kernel Image Investigation

Verified:

```
config.txt
```

contains no

```
kernel=
```

entry.

Firmware therefore selects

```
kernel_2712.img
```

automatically.

Running kernel:

```bash
uname -r
```

```
6.18.34+rpt-rpi-2712
```

Boot partition:

```
kernel_2712.img

kernel8.img
```

Conclusion:

Firmware automatically selects `kernel_2712.img` on Raspberry Pi 5.

---

## Step 9 — Investigating SunFounder Installer

Examined:

```
install.sh
```

Installer flow:

```
install.sh

↓

DTOVERLAY_ADD()

↓

installer.sh

↓

config_txt_manager.sh
```

Observation:

Installer does not directly modify Device Tree.

Overlay registration is handled through helper functions.

Further investigation is required to determine how firmware loads:

```
sunfounder-pironman5.dtbo
```

even though no corresponding entry exists inside the visible `config.txt`.

Possible mechanisms:

* Generated boot configuration
* Firmware configuration manager
* HAT EEPROM auto-loading

---

## Step 10 — SPI Driver Investigation

Loaded SPI modules:

```bash
lsmod | grep spi
```

Output:

```
spidev

spi_bcm2835

spi_dw_mmio

spi_dw
```

### Observation

DesignWare SPI driver is currently loaded as a kernel module.

Since `lsmod` only lists loadable modules:

```
spi_dw_mmio

spi_dw

spidev
```

are all modular drivers.

---

## Step 11 — Custom BusyBox Investigation

Initial assumption:

Changing

```dts
status = "disabled";
```

↓

```dts
status = "okay";
```

should make SPI0 available.

Observed:

Driver still did not probe.

Possible reasons investigated:

* Missing DesignWare SPI driver
* Driver built as module
* Module unavailable in BusyBox rootfs
* Missing module auto-loading
* Missing dependencies

Current hypothesis:

BusyBox image should build the following directly into the kernel:

```
CONFIG_SPI=y

CONFIG_SPI_DW=y

CONFIG_SPI_DW_MMIO=y

CONFIG_SPI_SPIDEV=y
```

instead of relying on loadable modules.

---

# 4. Key Technical Learnings

* Raspberry Pi firmware performs Device Tree merging before Linux starts.
* Linux never knows which overlays were loaded.
* Runtime Device Tree is always the merged result.
* SPI0 on Raspberry Pi 5 belongs to RP1.
* SPI10 belongs to BCM2712.
* Overlays can completely change hardware availability.
* Device Tree status alone does not guarantee driver probing.
* Kernel configuration is equally important.
* Raspberry Pi firmware automatically selects `kernel_2712.img` on Pi 5 when `kernel=` is absent.

---

# 5. Current Root Cause

Current evidence suggests that the failure is no longer related to the Device Tree.

The Device Tree correctly enables SPI0.

The remaining investigation focuses on kernel driver availability and module loading in the custom BusyBox image.

---

# 6. Next Investigation

* Build SPI drivers directly into the kernel.
* Rebuild `kernel_2712.img`.
* Boot custom BusyBox image.
* Verify:

```bash
ls /sys/class/spi_master
```

```bash
dmesg | grep spi
```

```bash
ls /dev/spidev*
```

* Begin SPI LCD bring-up.

---

# Investigation Status

**Status:** In Progress

**Current Phase:** SPI Controller Bring-up

**Next Milestone:** Enable SPI0 on custom BusyBox image and initialize the LCD framebuffer.
