# Changelog

All notable changes to this project will be documented in this file.


## [v0.1.3]

### Added

* Ethernet startup service
* DHCP client integration using udhcpc
* Static IP fallback mechanism
* Dropbear SSH daemon
* SSH host key generation workflow
* Public-key authentication support
* `/etc/shells` configuration
* SSH permission initialization script

### Fixed

* Missing udhcpc default script execution
* SSH authentication failures
* Invalid shell rejection by Dropbear
* Root SSH permission validation issues

### Improved

* Boot-time diagnostics
* Network configuration visibility
* Rootfs packaging process


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
