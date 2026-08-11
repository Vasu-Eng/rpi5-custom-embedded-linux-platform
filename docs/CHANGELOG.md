# Changelog

All notable changes to this project will be documented in this file.

## [v1.0.0] - 2026-08-11

### Added

- Added complete Raspberry Pi 5 bootable image generation workflow.
- Added `lib/rpi5_image.sh` for independent bootable image generation.
- Added support for creating:
  - MBR partition table
  - FAT32 boot partition
  - loop-device based image mounting
  - boot filesystem population
  - automatic filesystem synchronization
  - loop-device cleanup
- Added `Bootable/rpi5_custom.img` as the generated Raspberry Pi 5 bootable image artifact.
- Added `Bootable/README.md` documenting the bootable image and flashing workflow.
- Added `lib/banner` as a source-controlled system banner.
- Added automated banner installation into the generated root filesystem.
- Added `--bootable` support to `build_rootfs_pipeline.sh`.
- Added investigation logs covering kernel/userspace boot failures and their root causes.
- Added ELF `LOAD` segment alignment validation to the rootfs build pipeline.
- Added runtime dependency resolution for dynamically linked userspace applications.
- Added `/lib:/usr/lib` runtime library search path configuration.

### Fixed

- Fixed kernel/userspace boot failure caused by incompatible 4-KB page-size configuration with the tested SDK ELF binaries.
- Verified compatibility of the tested userspace binaries with 16-KB and 64-KB page-size configurations.
- Fixed dynamic loader failures caused by runtime libraries being installed under `/usr/lib` while the runtime search path was incomplete.
- Fixed early userspace dependency issues by building BusyBox as a static binary.
- Fixed bootable image cleanup issues involving mounted loop-device partitions.
- Improved loop-device unmount and detach handling during bootable image generation.

### Improved

- Improved rootfs build process through the centralized `build_rootfs_pipeline.sh`.
- Improved separation between:
  - SDK/toolchain
  - kernel/BSP
  - packages
  - rootfs
  - boot filesystem
  - bootable image
- Improved reproducibility of the complete rootfs-to-image build flow.
- Improved BSP documentation and architecture documentation.
- Added a documented Buildroot vs custom BSP architecture comparison.
- Improved bootable image verification and cleanup workflow.

### Kernel / BSP

- Continued development using the Raspberry Pi downstream Linux kernel.
- Integrated and validated PREEMPT_RT configuration.
- Continued Device Tree and Device Tree overlay integration for Raspberry Pi 5 peripherals.
- Continued investigation and development around UART, SPI, I2C and display hardware support.
- Added kernel/userspace compatibility investigation documentation.

### Validation

- Successfully generated the Raspberry Pi 5 bootable image.
- Successfully created and mounted the FAT32 boot partition through a loop device.
- Successfully populated the boot partition from `rpi_bootfs`.
- Successfully booted the generated custom Linux image on Raspberry Pi 5.
- Verified BusyBox userspace and interactive shell.
- Verified custom boot banner.
- Verified Dropbear integration.
- Verified `rt-tests` integration.
- Verified `cyclictest` runtime dependency handling.
- Verified bootable image generation independently from the rootfs pipeline.

---

## [v0.1.3]

### Added

- Ethernet startup service
- DHCP client integration using udhcpc
- Static IP fallback mechanism
- Dropbear SSH daemon
- SSH host key generation workflow
- Public-key authentication support
- `/etc/shells` configuration
- SSH permission initialization script

### Fixed

- Missing udhcpc default script execution
- SSH authentication failures
- Invalid shell rejection by Dropbear
- Root SSH permission validation issues

### Improved

- Boot-time diagnostics
- Network configuration visibility
- Rootfs packaging process

---

## [v0.1.2] - Structured System Startup Framework

### Added

- Introduced `/etc/fstab`.
- Introduced `/etc/init.d/rcS`.
- Added a centralized filesystem mount configuration.
- Added the foundation for a service startup framework.

### Changed

- Simplified `/init`.
- Moved startup responsibilities from `/init` to `rcS`.
- Separated boot entry point, filesystem configuration, and system initialization logic.

### Benefits

- Improved maintainability.
- Cleaner boot architecture.
- Easier future integration of networking, Dropbear auto-start, application startup scripts, watchdog services, and OTA update services.

### Validation

- Verified `mount -a` behavior through `/etc/fstab`.
- Verified boot banner and uptime reporting through `rcS`.

---

## [v0.1.1] - Root Filesystem Layout Cleanup

### Added

- Created a production-oriented rootfs directory structure:
  - `/etc`
  - `/etc/dropbear`
  - `/dev`
  - `/proc`
  - `/sys`
  - `/tmp`
  - `/var`
  - `/var/log`
  - `/root`

### Improved

- Reviewed the filesystem hierarchy against embedded Linux conventions.
- Separated runtime data, configuration files, and boot assets.

### Validation

- Verified rootfs packaging and extraction during boot.
- Confirmed required runtime directories are available after initramfs extraction.

---

## [v0.1.0] - Dropbear SSH Integration

### Added

- Integrated Dropbear SSH (ARM64 cross-compiled build).
- Added the Dropbear multi-call binary (`dropbearmulti`).
- Installed `dropbear`, `dbclient`, `dropbearkey`, and `dropbearconvert` applets.
- Added ARM64 runtime libraries:
  - `libc.so.6`
  - `ld-linux-aarch64.so.1`
- Added SSH host key support through `/etc/dropbear`.

### Fixed

- Resolved the Dropbear build failure caused by unavailable `crypt()` support.
- Corrected rootfs symlink configuration for Dropbear applets.
- Fixed initramfs packaging issues affecting SSH binaries.

### Validation

- Verified ARM64 ELF binaries.
- Verified runtime library dependencies using `readelf`.
- Verified successful deployment into the initramfs root filesystem.

---

## [v0.0.1] - 2026-06-21

### Added

- Boot-time measurement using `/proc/uptime`
- Startup banner displaying platform information
- Release version display during userspace initialization

### Changed

- Updated custom `/init` process to report boot duration before launching BusyBox shell
- Improved UART console output formatting during system startup

### Example Output

```text
================================
 Raspberry Pi 5 Custom Linux
 Release : v0.0.1
 Boot Time: 0.82s
================================

~ #
