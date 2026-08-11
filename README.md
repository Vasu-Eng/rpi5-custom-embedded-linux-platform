# Raspberry Pi 5 Custom Embedded Linux BSP

A custom Embedded Linux BSP platform for Raspberry Pi 5 built around a fixed AArch64 toolchain/sysroot and a Raspberry Pi downstream Linux kernel.

The project intentionally separates the **kernel/BSP layer**, **toolchain/sysroot**, **userspace packages**, **root filesystem**, and **boot-image generation** instead of hiding the complete platform behind a monolithic build system.

> **Project philosophy:** Do not hide the platform. Build it, understand it, debug it, and make it reproducible.

---

## 1. Motivation

A Raspberry Pi can be made to boot Linux with a few commands, or an embedded Linux image can be generated with Buildroot/Yocto. Those approaches are useful, but they can hide the relationships between:

- toolchain and sysroot
- kernel and kernel configuration
- Raspberry Pi downstream kernel changes
- Device Tree and overlays
- userspace packages
- dynamic libraries
- initramfs
- boot files
- partitioning
- final SD-card image

The goal of this project is to explicitly control those layers and build a reusable Raspberry Pi 5 BSP/platform foundation.

The project is intended to demonstrate practical BSP/platform engineering rather than simply running an application on Raspberry Pi OS.

---

## 2. Architecture

```text
                    CUSTOM EMBEDDED LINUX BSP
                               │
              ┌────────────────┴────────────────┐
              │                                 │
              ▼                                 ▼
        TOOLCHAIN / SDK                    LINUX KERNEL
              │                         (Raspberry Pi source)
              │                                 │
              │                    ┌────────────┴────────────┐
              │                    │                         │
              │                    ▼                         ▼
              │               PREEMPT_RT             Device Tree / DTB
              │                    │                    / Overlays
              │                    ▼                 (LCD / UART /
              │              Custom Kernel            SPI / I2C)
              │                    │                         │
              │                    │                         ▼
              │                    │                    DTB + Overlays
              │                    │                         │
              │                    └────────────┬────────────┘
              │                                 │
              │                                 ▼
              │                            Kernel + DTB
              │                                 │
              └────────────────┬────────────────┘
                               │
                               ▼
                        PACKAGE BUILDS
                               │
              ┌────────────────┼────────────────┐
              │                │                │
              ▼                ▼                ▼
           BusyBox          Dropbear         rt-tests
              │                │                │
              └────────────────┼────────────────┘
                               │
                               ▼
                      PACKAGE INSTALLATION
                               │
                               ▼
                   RUNTIME DEPENDENCY RESOLUTION
                               │
                               ▼
                            ROOTFS
                               │
              ┌────────────────┼────────────────┐
              │                │                │
            /bin             /sbin           /usr/bin
              │                │                │
              ├────────────────┼────────────────┤
              │                                 │
            /etc                            /usr/lib
              │                                 │
              └────────────────┬────────────────┘
                               │
                               ▼
                       INITRAMFS ROOTFS
                          rootfs.cpio.gz
                               │
                  ┌────────────┴────────────┐
                  │                         │
                  ▼                         ▼
             BOOT FILES                KERNEL + DTB
          config.txt / overlays        Kernel Image
                  │                         │
                  └────────────┬────────────┘
                               │
                               ▼
                      BOOTABLE DISK IMAGE
                               │
                               ▼
                       FAT32 + MBR PARTITION
                               │
                               ▼
                     rpi5_custom.img
```

The important separation is:

```text
Fixed SDK / Sysroot
        │
        ├──────────────► Userspace platform
        │                 ├── BusyBox
        │                 ├── Dropbear
        │                 ├── rt-tests
        │                 └── RootFS
        │
        └──────────────► Kernel / BSP
                          ├── PREEMPT_RT
                          ├── Device Tree
                          ├── DT overlays
                          └── Drivers
```

The kernel/BSP can evolve while the userspace build foundation remains stable.

---

## 3. Buildroot vs This Architecture

Buildroot is a mature system for generating complete embedded Linux systems. It can manage toolchains, kernels, packages, root filesystems and images.

This project is **not intended to replace Buildroot**. It is intentionally more explicit and educational at the platform/BSP layer.

### Buildroot-oriented model

```text
                 Buildroot
                    │
       ┌────────────┼────────────┐
       │            │            │
   Toolchain      Kernel       Packages
       │            │            │
       └────────────┼────────────┘
                    │
                  RootFS
                    │
              Image generation
                    │
                    ▼
                SD Image
```

### This project's model

```text
                TOOLCHAIN / SDK
                       │
        ┌──────────────┴──────────────┐
        │                             │
        ▼                             ▼
     Userspace                    Kernel / BSP
        │                             │
     Packages                    PREEMPT_RT
        │                       Device Tree
     RootFS                     Kernel config
        │                       Drivers
        │                             │
        └──────────────┬──────────────┘
                       │
                       ▼
                 Boot packaging
                       │
                       ▼
                  SD image
```

The key design choice is a **fixed target SDK/sysroot** combined with an independently developed Raspberry Pi downstream kernel/BSP.

---

## 4. Benefits

### Stable userspace foundation

Packages are built against the same:

```text
CROSS_COMPILE
SYSROOT
```

This provides a consistent userspace build environment.

### Independent kernel development

Kernel work can continue independently:

```text
Raspberry Pi kernel
       ↓
kernel configuration
       ↓
PREEMPT_RT
       ↓
Device Tree / overlays
       ↓
drivers
       ↓
Kernel + DTB
```

while the SDK, BusyBox, Dropbear and rootfs architecture remain stable.

### Explicit BSP ownership

The project explicitly owns:

- kernel configuration
- Device Tree
- DT overlays
- kernel image
- initramfs
- boot configuration
- runtime dependencies
- bootable image generation

### Debuggable build layers

```text
SDK
 ↓
Packages
 ↓
RootFS
 ↓
Initramfs
 ↓
BootFS
 ↓
Bootable image
```

Each layer can be built and investigated independently.

### Reusable platform foundation

A stable Raspberry Pi 5 platform can support different product variants:

```text
                RPI5 BSP PLATFORM
                       │
        ┌──────────────┼──────────────┐
        │              │              │
     Product A      Product B      Product C
        │              │              │
       LCD            CAN            SPI
       UART           Motor          Sensor
       SSH            Control        Camera
```

---

## 5. Repository Structure

```text
rpi5-custom-embedded-linux-platform/
│
├── Bootable/
│   └── rpi5_custom.img
│
├── docs/
│   └── investigation logs release-notes changelog fundamentals Images ..
│
├── kernel/
│   └── Raspberry Pi Linux kernel
│
├── lib/
│   ├── banner
│   └── rpi5_image.sh
│
├── packages/
│   ├── busybox/
│   │   └── build.sh
│   ├── dropbear-2026.91/
│   │   └── build.sh
│   └── rt-tests/
│       └── build.sh
│
├── rpi_bootfs/
│   ├── bcm2712-rpi-5-b.dtb
│   ├── cmdline.txt
│   ├── config.txt
│   ├── overlays/
│   ├── rootfs.cpio.gz
│   └── kernel image
│
├── rpi_rootfs/
│   ├── bin/
│   ├── dev/
│   ├── etc/
│   ├── lib/
│   ├── proc/
│   ├── root/
│   ├── sbin/
│   ├── sys/
│   ├── tmp/
│   ├── usr/
│   └── var/
│
├── scripts/
│   ├── build_rootfs_pipeline.sh
│   ├── mount_rootfs_zip.sh
│   ├── resolve-runtime-deps.sh
│   ├── rootfs-builder.sh
│   └── rootfs_safe_clean.sh
│
├── sdk/
│   |
|   |── environment-setup
|   |
|   |──  custom-sdk
|   |
|   └──  official-sdk
│
└── README.md
```

---

## 6. Build Pipeline and Shell Scripts

### `scripts/build_rootfs_pipeline.sh`

Main orchestration script.

```bash
./scripts/build_rootfs_pipeline.sh custom-sdk
```

For rootfs plus bootable image:

```bash
./scripts/build_rootfs_pipeline.sh custom-sdk --bootable
```

The pipeline performs:

```text
SDK setup
   ↓
BusyBox build
   ↓
ELF / page-size validation
   ↓
Dropbear build
   ↓
rt-tests build
   ↓
Safe rootfs cleanup
   ↓
RootFS construction
   ↓
Runtime dependency resolution
   ↓
Banner installation
   ↓
rpi_bootfs generation
   ↓
Optional bootable image
```

### `packages/busybox/build.sh`

Builds BusyBox for the target architecture.

BusyBox is built statically because it provides the early userspace shell/init environment and should not depend on the dynamic loader during early boot.

### `packages/dropbear-2026.91/build.sh`

Cross-compiles and prepares Dropbear for lightweight SSH access.

### `packages/rt-tests/build.sh`

Builds the Linux real-time test utilities used for PREEMPT_RT validation.

### `scripts/rootfs_safe_clean.sh`

Safely cleans generated rootfs content before rebuilding.

### `scripts/rootfs-builder.sh`

Installs/builds the package contents and constructs the target root filesystem hierarchy.

### `scripts/resolve-runtime-deps.sh`

Resolves dynamic shared-library dependencies required by dynamically linked userspace applications and copies the required runtime libraries into the target rootfs.

### `scripts/mount_rootfs_zip.sh`

Packages the root filesystem into the initramfs artifact:

```text
rootfs.cpio.gz
```

and prepares the Raspberry Pi boot filesystem.

### `lib/banner`

Source-controlled login/system banner.

It is installed into:

```text
/usr/bin/banner
```

so regenerating the rootfs does not permanently delete the customization.

### `lib/rpi5_image.sh`

Independent bootable image generator.

If `rpi_bootfs` already exists:

```bash
./lib/rpi5_image.sh
```

creates:

```text
Bootable/rpi5_custom.img
```

---

## 7. SDK / Sysroot

The SDK is loaded through:

```text
sdk/environment-setup
```

The pipeline obtains:

```text
SYSROOT
CROSS_COMPILE
```

Example target toolchain:

```text
aarch64-buildroot-linux-gnu-gcc
```

The important design rule is:

```text
SDK / Sysroot = stable userspace build foundation
Kernel / BSP  = independently evolving platform layer
```

---

## 8. Runtime Dependency Investigation

Dynamically linked applications require shared libraries.

For example:

```text
cyclictest
    │
    └── libnuma.so.1
```

If the library exists under:

```text
/usr/lib/libnuma.so.1
```

but the runtime loader does not search `/usr/lib`, the application fails with:

```text
error while loading shared libraries:
libnuma.so.1: cannot open shared object file
```

The current minimal runtime environment therefore includes:

```sh
export LD_LIBRARY_PATH=/lib:/usr/lib
```

The dependency resolver also places required libraries into the generated rootfs.

---

## 9. ELF Page-Size Investigation

The project investigated a kernel/userspace compatibility problem related to ELF `LOAD` segment alignment.

The SDK is inspected using:

```bash
readelf -l "$SYSROOT/lib/libc.so.6"
```

Relevant values:

```text
0x1000   = 4 KB
0x4000   = 16 KB
0x10000  = 64 KB
```

The investigation established that the tested SDK binaries were compatible with page sizes of **16 KB and larger**, while the tested 4-KB configuration was incompatible.

The project therefore checks the actual ELF `LOAD` alignment rather than depending only on target header macros.

Detailed investigation logs are kept under:

```text
docs/
```

---

## 10. RootFS

The generated root filesystem contains:

```text
/bin
/sbin
/usr/bin
/usr/sbin
/etc
/lib
/usr/lib
/dev
/proc
/sys
/tmp
/root
/var
```

It includes:

- BusyBox
- Dropbear
- rt-tests
- runtime shared libraries
- startup scripts
- login configuration
- system banner
- required runtime files

The final initramfs is:

```text
rootfs.cpio.gz
```

---

## 11. Init / Startup

The target uses BusyBox init.

Example `inittab`:

```text
::sysinit:/etc/init.d/rcS
::once:/usr/bin/banner
console::askfirst:/bin/cttyhack /bin/login
::ctrlaltdel:/sbin/poweroff
::shutdown:/bin/umount -a -r
::shutdown:/sbin/swapoff -a
```

The boot userspace flow is:

```text
Linux kernel
     ↓
initramfs
     ↓
BusyBox init
     ↓
/etc/init.d/rcS
     ↓
/usr/bin/banner
     ↓
/bin/login
```

---

## 12. Kernel / BSP Modifications

The kernel side is based on the Raspberry Pi downstream Linux kernel rather than treating the target as a generic upstream ARM64 board.

The BSP layer contains:

```text
Raspberry Pi kernel source
        │
        ├── Kernel configuration
        │
        ├── PREEMPT_RT
        │
        ├── Device Tree
        │
        ├── Device Tree overlays
        │
        └── Hardware-specific drivers/configuration
```

### PREEMPT_RT

PREEMPT_RT is used for real-time Linux evaluation.

The validation stack is:

```text
PREEMPT_RT
     +
rt-tests
     +
cyclictest
```

The focus is:

- kernel preemption
- scheduling latency
- interrupt/thread behavior
- cyclictest latency
- real-time workload evaluation

### Device Tree

The platform uses:

```text
bcm2712-rpi-5-b.dtb
overlays/
```

for hardware configuration such as:

```text
UART
SPI
I2C
LCD / display
```

### I2C / Driver Development

I2C is treated as a kernel/BSP concern:

```text
Hardware
   ↓
Device Tree
   ↓
I2C controller/device description
   ↓
Kernel driver
   ↓
Linux I2C subsystem
   ↓
Userspace interface
```

The same architecture can be extended to SPI, UART, GPIO, CAN, display, touchscreen and sensor drivers.

Where a driver is not yet implemented in this repository, it is treated as future kernel/BSP development rather than claiming completed driver work.

---

## 13. `rpi_bootfs`

The boot filesystem contains:

```text
rpi_bootfs/
├── bcm2712-rpi-5-b.dtb
├── cmdline.txt
├── config.txt
├── overlays/
├── rootfs.cpio.gz
└── kernel image
```

This directory represents the content placed onto the FAT32 Raspberry Pi boot partition.

---

## 14. Bootable Image Generation

`lib/rpi5_image.sh` creates:

```text
Bootable/rpi5_custom.img
```

The process is:

```text
Create image
     ↓
Create MBR partition table
     ↓
Create FAT32 partition
     ↓
Attach image through loop device
     ↓
Format FAT32
     ↓
Mount partition
     ↓
Copy rpi_bootfs
     ↓
sync
     ↓
Verify
     ↓
Unmount
     ↓
Detach loop device
```

The resulting raw image can be flashed to an SD card using Raspberry Pi Imager or another raw-image flasher.

> **Warning:** Always verify the target device before writing a raw disk image. Selecting the wrong block device can destroy existing data.

---

## 15. User Manual

### Build rootfs

```bash
./scripts/build_rootfs_pipeline.sh custom-sdk
```

### Build rootfs + bootable image

```bash
./scripts/build_rootfs_pipeline.sh custom-sdk --bootable
```

Output:

```text
Bootable/rpi5_custom.img
```

### Build only the bootable image

If `rpi_bootfs` already exists:

```bash
./lib/rpi5_image.sh
```

### Flash

Flash:

```text
Bootable/rpi5_custom.img
```

to an SD card using a raw image flashing utility.

### Boot

Insert the SD card into the Raspberry Pi 5 and connect the configured serial console if required.

Expected flow:

```text
Kernel
  ↓
initramfs
  ↓
BusyBox init
  ↓
startup
  ↓
banner
  ↓
login
```

---

## 16. Target Verification

After boot:

```bash
uname -a
```

```bash
uname -r
```

```bash
ps
```

Check runtime libraries:

```bash
ls -l /lib
ls -l /usr/lib
```

Check Dropbear:

```bash
dropbear
```

Run real-time tests:

```bash
cyclictest
```

---

## 17. Troubleshooting

### `cyclictest` cannot find `libnuma.so.1`

Check:

```bash
ls -l /usr/lib/libnuma.so.1
```

and:

```bash
echo "$LD_LIBRARY_PATH"
```

The minimal environment should contain:

```sh
export LD_LIBRARY_PATH=/lib:/usr/lib
```

### Dropbear cannot find `libz.so.1`

Check:

```bash
ls -l /usr/lib/libz.so.1
```

and:

```bash
echo "$LD_LIBRARY_PATH"
```

### Kernel fails during early boot

Investigate:

```text
kernel configuration
Device Tree
DT overlays
ELF LOAD alignment
dynamic loader
initramfs contents
```

Detailed investigation records are stored under:

```text
docs/
```

---

## 18. Demo

### Raspberry Pi 5 Boot Demo

The demo video shows the generated custom Linux platform booting on a Raspberry Pi 5, including the custom kernel and minimal BusyBox-based userspace.

**Demo video:**

[Watch the Raspberry Pi 5 Custom Embedded Linux BSP Demo](https://drive.google.com/file/d/1l_-_ZbR9FfEfSW3biwSwsIvMav2swrbX/view?usp=sharing)

---

## 19. Future Scope

### Kernel

- Additional kernel configuration
- Kernel driver development
- I2C device drivers
- SPI device drivers
- GPIO drivers
- UART development
- CAN support
- Sensor integration
- Display/touchscreen support

### Device Tree

- Custom board-level DT nodes
- Additional overlays
- LCD integration
- Touch controller integration
- Camera integration
- Peripheral bring-up

### Real-Time Linux

- PREEMPT_RT tuning
- cyclictest benchmarking
- IRQ affinity
- CPU isolation
- scheduler tuning
- latency comparison
- real-time workload testing

### Build Infrastructure

- Better dependency tracking
- Build caching
- Reproducible builds
- Automated image validation
- CI pipeline
- Automated boot testing
- Artifact versioning

### Platform Evolution

```text
Stable BSP Platform
        │
        ├── Platform SDK
        ├── Kernel
        ├── Device Tree
        ├── RootFS
        ├── Package layer
        └── Image generation
                │
                ▼
          Product variants
```

---

## 20. Current Status

### Working

- [x] Raspberry Pi 5 boot
- [x] ARM64 cross-compilation
- [x] Fixed SDK/sysroot integration
- [x] Custom Linux kernel
- [x] Raspberry Pi downstream kernel
- [x] Device Tree / DTB
- [x] Device Tree overlays
- [x] PREEMPT_RT configuration
- [x] BusyBox userspace
- [x] Static BusyBox
- [x] Custom initramfs
- [x] Dropbear
- [x] rt-tests
- [x] Runtime dependency resolution
- [x] Custom system banner
- [x] RootFS build pipeline
- [x] Boot filesystem generation
- [x] FAT32 boot partition generation
- [x] Bootable SD-card image generation
- [x] ELF page-size / LOAD-alignment investigation

### In Progress

- [ ] Additional kernel drivers
- [ ] I2C device-driver development
- [ ] More Device Tree integrations
- [ ] Real-time latency optimization
- [ ] Automated validation
- [ ] CI-based image generation
- [ ] Product-specific BSP variants

---

## 21. Final Architecture

```text
                  FIXED SDK / SYSROOT
                           │
              ┌────────────┴────────────┐
              │                         │
              ▼                         ▼
        USERSPACE PLATFORM          KERNEL BSP
              │                         │
        ┌─────┼─────┐             ┌─────┼─────┐
        │     │     │             │     │     │
     BusyBox Dropbear rt-tests   RT    DT    Drivers
        │     │     │             │     │     │
        └─────┼─────┘             └─────┼─────┘
              │                         │
              ▼                         ▼
            ROOTFS                 Kernel + DTB
              │                         │
              └──────────┬──────────────┘
                         │
                         ▼
                  BOOT FILESYSTEM
                         │
                         ▼
                  FAT32 + MBR IMAGE
                         │
                         ▼
               rpi5_custom.img
                         │
                         ▼
                   Raspberry Pi 5
```

The focus is not simply running Linux on Raspberry Pi.

The focus is understanding and controlling the platform that makes Linux run on the target hardware.
