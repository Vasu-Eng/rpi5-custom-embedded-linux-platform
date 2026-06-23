# Raspberry Pi 5 BSP Development and Embedded Linux Bring-Up

A hands-on Board Support Package (BSP) and Embedded Linux development project focused on understanding and building a complete Linux software stack from first principles.

This repository documents the engineering process of bringing up a Linux system on Raspberry Pi 5 without initially relying on Buildroot or Yocto. Every subsystem is integrated, debugged, and documented manually to gain a deep understanding of Linux boot architecture, platform bring-up, networking, remote access, root filesystem design, and BSP development workflows.

The long-term objective is to evolve this platform into a production-style Embedded Linux distribution using Buildroot and Yocto while documenting every engineering decision, debugging session, and architectural milestone.

---

# Project Goals

This repository is designed to demonstrate practical skills commonly required for:

* Embedded Linux Engineer
* BSP Engineer
* Firmware Engineer
* Linux Systems Engineer
* Platform Software Engineer

Target skill areas include:

* Linux Boot Process
* ARM64 Platform Bring-Up
* Device Tree
* Root Filesystem Engineering
* Networking
* Secure Remote Access
* Build Systems
* Debugging Methodology
* Production Linux BSP Workflows

---

# Current Features

## Linux Bring-Up

* ARM64 Linux Kernel Boot
* Raspberry Pi 5 Device Tree Integration
* UART Console Bring-Up
* BusyBox Userspace
* Custom Initramfs
* Custom `/init`
* Interactive Shell Access

## Root Filesystem

* BusyBox-based Root Filesystem
* Custom Directory Structure
* Initramfs Packaging
* Ownership and Permission Handling
* Root User Configuration

## Networking

* Ethernet Bring-Up
* DHCP Client Integration (`udhcpc`)
* Static IP Fallback Mechanism
* Network Diagnostics
* Interface Validation

## Remote Access

* Dropbear SSH Server
* Public Key Authentication
* Host Key Generation
* Authorized Keys Management
* SSH Permission Validation
* Headless Remote Access

---

# Engineering Topics Investigated

This project includes practical investigation and debugging of:

* Linux Boot Flow
* Initramfs Internals
* BusyBox Integration
* Device Tree Loading
* UART Routing
* Linux Permissions
* Ownership Handling inside CPIO Images
* SSH Authentication Flow
* Public / Private Key Cryptography
* DHCP Client Operation
* Embedded Linux Networking
* Filesystem Mounting
* Pseudo Filesystems

---

# Platform Roadmap

## v0.0 — Linux Bring-Up Foundation

**Status:** Complete

### Features

* ARM64 Linux kernel boot
* BusyBox userspace
* Custom root filesystem
* Custom `/init`
* Initramfs (`rootfs.cpio.gz`)
* UART console bring-up
* Device Tree integration
* Interactive shell access

### Skills Demonstrated

* Linux boot flow
* Initramfs architecture
* BusyBox integration
* Root filesystem construction
* ARM64 bring-up

---

## v0.1 — Networking and Remote Access

**Status:** Complete

### Features

* Ethernet bring-up
* DHCP client integration (`udhcpc`)
* Static IP fallback
* Dropbear SSH server
* Public-key authentication
* Headless remote access

### Skills Demonstrated

* Linux networking
* DHCP debugging
* SSH authentication
* Embedded Linux security
* System integration

---

## v0.2 — Device Tree Deep Dive

### Objectives

* Analyze Raspberry Pi 5 Device Tree hierarchy
* Enable/disable peripherals
* UART routing investigation
* Overlay development
* Custom DTS modifications

### Deliverable

```text
Hardware
   ▼
Device Tree
   ▼
Kernel
   ▼
Userspace
```

### Skills Demonstrated

* DTS
* DTB
* Overlay mechanism
* Hardware description
* BSP configuration

---

## v0.3 — U-Boot Integration

### Objectives

* Build U-Boot from source
* Boot Linux through U-Boot
* Configure boot arguments
* Environment variable management
* Boot script development

### Deliverable

```text
Firmware
   ▼
U-Boot
   ▼
Linux Kernel
   ▼
Initramfs
```

### Skills Demonstrated

* Bootloader architecture
* Linux handoff
* Embedded boot flow
* BSP bring-up

---

## v0.4 — Persistent ext4 Root Filesystem

### Objectives

* Separate boot partition
* Separate root partition
* ext4 root filesystem
* Persistent configuration
* Persistent user data

### Deliverable

```text
Boot Partition
   ▼
Kernel
   ▼
Mount ext4 RootFS
   ▼
Persistent Linux System
```

### Skills Demonstrated

* Linux storage
* Filesystems
* Partitioning
* RootFS management

---

## v0.5 — Linux Driver Development

### Objectives

* Character driver
* Sysfs interface
* GPIO control
* Device Tree integration
* Kernel module development

### Deliverable

```text
Device Tree
   ▼
Kernel Driver
   ▼
Userspace Application
```

### Skills Demonstrated

* Linux kernel development
* Driver architecture
* Kernel APIs
* Hardware abstraction

---

## v1.0 — Buildroot Migration

### Objectives

* Buildroot image generation
* Cross-compilation workflow
* Package integration
* Custom package development
* Reproducible builds

### Deliverable

Buildroot-managed Embedded Linux distribution.

### Skills Demonstrated

* Embedded build systems
* Toolchains
* Distribution generation

---

## v2.0 — Yocto BSP Development

### Objectives

* Custom Yocto layers
* BitBake recipes
* Custom images
* BSP customization
* Production workflows

### Deliverable

Production-oriented Embedded Linux BSP.

### Skills Demonstrated

* Yocto Project
* BSP engineering
* Layer architecture
* Industrial Linux workflows

---

## v3.0 — Advanced Platform Engineering

### Objectives

* OTA update framework
* Secure boot investigation
* System profiling
* Performance optimization
* Upstream contribution workflow

### Skills Demonstrated

* Production deployment
* Security
* Maintainability
* Open-source contribution

---

# Maintainer

**Vasu Kesharwani**

Focus Areas:

* Embedded Linux
* BSP Development
* ARM64 Platforms
* Linux Boot Architecture
* System Bring-Up
* Embedded Networking

GitHub:
https://github.com/Vasu-Eng

LinkedIn:
https://www.linkedin.com/in/vasudev-kesharwani-466503201/

---

# License

This repository is intended for learning, experimentation, BSP development practice, and Embedded Linux engineering research.

