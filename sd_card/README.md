# Raspberry Pi 5 Custom Linux Image

A minimal Embedded Linux image for Raspberry Pi 5 built using:

* BusyBox (ARM64)
* Custom Initramfs
* Raspberry Pi Linux Kernel
* Device Tree and Overlays

## Project Structure

```text
.
├── README.md
└── boot
    ├── bcm2712-rpi-5-b.dtb
    ├── cmdline.txt
    ├── config.txt
    ├── kernel_2712.img
    ├── overlays
    │   ├── README
    │   └── bcm2712d0.dtbo
    └── rootfs.cpio.gz
```

## SD Card Layout

This image uses an Initramfs-based root filesystem.

Only a single FAT32 boot partition is required.

### Partition Table

| Partition | Type | Filesystem | Size          |
| --------- | ---- | ---------- | ------------- |
| p1        | Boot | FAT32      | 64 MB minimum |

### Recommended Size

Current boot files occupy approximately:

```text
11.7 MB
```

Recommended FAT32 partition sizes:

| Usage       | Size   |
| ----------- | ------ |
| Minimum     | 32 MB  |
| Practical   | 64 MB  |
| Recommended | 128 MB |

For development and future kernel updates, a 128 MB FAT32 partition is recommended.

## Boot Configuration

### config.txt

```text
arm_64bit=1
enable_uart=1
uart_2ndstage=1

kernel=kernel_2712.img
device_tree=bcm2712-rpi-5-b.dtb

initramfs rootfs.cpio.gz followkernel
```

### cmdline.txt

```text
console=ttyAMA0,115200 rdinit=/init
```

## Boot Flow

```text
Power On
    ↓
Raspberry Pi5 EEPROM Firmware
    ↓
config.txt / cmdline.txt
    ↓
kernel_2712.img
    ↓
bcm2712-rpi-5-b.dtb
    ↓
rootfs.cpio.gz
    ↓
/init
    ↓
BusyBox Shell
```

## Serial Console

UART:

```text
ttyAMA0
```

Baud Rate:

```text
115200
```

Example:

```bash
minicom -D /dev/ttyUSB0 -b 115200
```
