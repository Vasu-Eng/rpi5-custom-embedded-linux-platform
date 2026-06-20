# Changelog

All notable changes to this project will be documented in this file.

---

## [v0.0.1] - 2026-06-21

### Added

* Boot-time measurement using `/proc/uptime`
* Startup banner displaying platform information
* Release version display during userspace initialization

### Changed

* Updated custom `/init` process to report boot duration before launching BusyBox shell
* Improved UART console output formatting during system startup

### Example Output

```text
================================
 Raspberry Pi 5 Custom Linux
 Release : v0.0.1
 Boot Time: 0.82s
================================

~ #
```

---

## [v0.0] - 2026-06-20

### Added

* ARM64 Linux kernel boot on Raspberry Pi 5
* BusyBox userspace
* Custom root filesystem
* Custom `/init` process
* Initramfs (`rootfs.cpio.gz`)
* Device Tree integration
* UART console bring-up
* Interactive BusyBox shell
