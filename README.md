# Raspberry Pi 5 Custom Linux Image

Custom Embedded Linux image for Raspberry Pi 5 built from first principles without Buildroot or Yocto.

This project focuses on platform bring-up, Linux boot flow analysis, root filesystem construction, userspace initialization, and BSP-level system integration. The objective is to develop a practical understanding of the complete software stack that transforms a powered-off board into a functional Linux system.

---

## Overview

The repository follows a staged development approach, progressing from a minimal RAM-based Linux image to a production-style Embedded Linux platform.

Key focus areas include:

* Linux boot architecture
* Raspberry Pi 5 platform bring-up
* BusyBox integration
* Initramfs development
* Root filesystem design
* Device Tree integration
* UART-based debugging
* Networking and remote access
* Embedded Linux BSP workflows

---

## Key Accomplishments

### Platform Bring-Up

* Cross-compiled BusyBox for ARM64
* Constructed a custom root filesystem from scratch
* Implemented a custom `/init` process
* Generated and integrated an initramfs image
* Integrated Raspberry Pi 5 kernel, DTB, and overlays
* Configured firmware boot flow using `config.txt` and `cmdline.txt`
* Validated complete boot sequence through UART
* Achieved successful boot to an interactive BusyBox shell

---

## System Architecture

```text
Power On
   │
   ▼
Boot ROM
   │
   ▼
EEPROM Bootloader
   │
   ▼
Raspberry Pi Firmware
   │
   ├── config.txt
   ├── cmdline.txt
   ├── Device Tree Blob (DTB)
   ├── Device Tree Overlays
   └── Linux Kernel Image
   │
   ▼
Linux Kernel
   │
   ▼
Initramfs / Root Filesystem
   │
   ▼
Custom Init Process
   │
   ▼
BusyBox Userspace
```

---

## Branch Strategy

### initramfs

RAM-based Linux image used for early platform validation and bring-up.

Characteristics:

* Single FAT32 boot partition
* BusyBox userspace
* Custom `/init`
* Initramfs (`rootfs.cpio.gz`)
* UART-first debug workflow

Primary objectives:

* Kernel validation
* Device Tree validation
* Root filesystem construction
* Early userspace bring-up
* Service integration

### ext4-rootfs

Persistent storage-based Linux image.

Characteristics:

* Dedicated boot partition
* Dedicated ext4 root filesystem
* Persistent configuration and logs
* Production-style deployment model

Primary objectives:

* Root filesystem mounting
* Storage management
* Service persistence
* System integration

---

## Engineering Decisions

### Why BusyBox

BusyBox provides a compact and predictable userspace suitable for early bring-up and embedded deployments. It minimizes dependency complexity while still providing the essential Linux utilities required for system validation.

### Why Initramfs First

Initramfs removes storage-mount dependencies during initial development. This simplifies debugging and accelerates platform bring-up by allowing the complete root filesystem to be loaded directly into memory.

### Why UART-First Debugging

UART remains available even when networking, display, or storage subsystems are not operational. It provides the most reliable interface for observing kernel and early userspace behavior.

### Why Separate Branches

The initramfs and ext4-rootfs implementations target different development goals.

Keeping them isolated allows experimentation with early bring-up workflows while maintaining a clean path toward a production-style root filesystem architecture.

---

## Current Status

| Item            | Status          |
| --------------- | --------------- |
| Active Release  | v0.0            |
| Active Branch   | initramfs       |
| Platform Status | Bootable        |
| Next Milestone  | v0.1 Networking |

Current boot sequence:

```text
Power On
   ▼
Firmware
   ▼
Linux Kernel
   ▼
Initramfs
   ▼
Custom /init
   ▼
BusyBox Shell
```

---

## Platform Roadmap

### v0.0 — BusyBox + Initramfs

Status: Complete

Features:

* ARM64 Linux kernel boot
* BusyBox userspace
* Custom root filesystem
* Custom `/init`
* Initramfs (`rootfs.cpio.gz`)
* Device Tree integration
* UART console bring-up
* Interactive shell access

---

### v0.1 — Networking

Objectives:

* Ethernet bring-up
* DHCP client integration
* Network diagnostics
* IP connectivity validation

Deliverable:

```text
Linux Boot
   ▼
Network Initialization
   ▼
DHCP
   ▼
IP Connectivity
```

---

### v0.2 — Dropbear

Objectives:

* Dropbear SSH integration
* Remote shell access
* Headless system management

Deliverable:

```text
Linux Boot
   ▼
Network Online
   ▼
Dropbear
   ▼
SSH Login
```

---

### v0.3 — ext4 RootFS

Objectives:

* Separate boot and root partitions
* ext4 root filesystem
* Persistent configuration
* Persistent user data

Deliverable:

```text
Boot Partition
   ▼
Kernel
   ▼
Mount ext4 RootFS
   ▼
Persistent Linux System
```

---

### v1.0 — Stable Platform

Objectives:

* Stable software architecture
* Automated image generation
* Reproducible builds
* Release workflow
* Platform documentation

Deliverable:

Stable Embedded Linux platform suitable for continued BSP development.

---

### v2.0 — Buildroot Integration

Objectives:

* Buildroot-based image generation
* Automated root filesystem creation
* Package integration
* Build reproducibility

Deliverable:

Buildroot-managed Embedded Linux distribution for Raspberry Pi 5.

---

### v3.0 — Yocto Integration

Objectives:

* Yocto-based BSP workflow
* Custom layers and recipes
* Production-oriented Linux distribution generation
* Advanced platform customization

Deliverable:

Production-grade Embedded Linux platform built using Yocto Project.

---

## Technologies

* Embedded Linux
* Linux Kernel
* BusyBox
* Initramfs
* Device Tree
* ARM64 (AArch64)
* UART Debugging
* Cross Compilation
* Raspberry Pi 5
* BSP Development

---

## Repository Layout

Release-specific artifacts, SD card layouts, boot instructions, and deployment notes are documented alongside their corresponding releases.

This repository serves as the primary source tree and development history for the platform.

---

## Maintainer

**Vasu Kesharwani**

Focus Areas:

- Embedded Linux
- BSP Development
- Platform Bring-Up
- ARM64 Systems
- Linux Boot Architecture

LinkedIn: https://www.linkedin.com/in/vasudev-kesharwani-466503201/

GitHub: https://github.com/Vasu-Eng

