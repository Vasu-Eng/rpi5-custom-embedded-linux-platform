# Toolchain

## Purpose

This directory is reserved for the ARM64 cross-compilation toolchain used by this project.

The toolchain is **not** committed to Git because it is several hundred megabytes in size. Instead, this repository documents the required toolchain version and build environment.

---

## Why a Dedicated Toolchain?

This project targets:

- **Board:** Raspberry Pi 5
- **Target Architecture:** ARM64 (AArch64)
- **Target OS:** Debian GNU/Linux 13 (Trixie)
- **Target GCC:** 14.2.0
- **Target glibc:** 2.41

Initially, the project used Ubuntu 22.04's default cross compiler:

```
gcc-aarch64-linux-gnu 11.4
glibc 2.35
```

Although the project sysroot was created from Raspberry Pi OS, the host toolchain was significantly older.

During cross-compilation of **rt-tests**, the linker reported:

```
undefined reference to

__isoc23_strtol@GLIBC_2.38
__isoc23_strtoul@GLIBC_2.38
__isoc23_strtoull@GLIBC_2.38
__isoc23_sscanf@GLIBC_2.38
```

Root cause:

```
Host Toolchain

glibc 2.35

        !=

Target Sysroot

glibc 2.41
```

The compiler, linker and target sysroot must be ABI compatible.

---

## Current Status

Current project components:

- Custom ARM64 sysroot
- Cross-compilation environment
- pkg-config configuration
- Build automation scripts

Pending:

- Replace the Ubuntu 22.04 cross toolchain with a Debian 13 (Trixie) compatible ARM64 SDK.

---

## Future Plan

A modern ARM64 SDK will be used for all userspace cross-compilation.

The SDK should provide:

- GCC
- G++
- Binutils
- glibc
- ARM64 sysroot
- pkg-config support
- GDB

Using a dedicated SDK ensures that:

- compiler
- linker
- libc
- headers
- sysroot

all target the same ABI.

---

## Repository Structure

```
toolchain/
├── README.md
└── .gitkeep
```

The actual SDK is intentionally excluded from version control.

After downloading and extracting the SDK, update:

```
scripts/environment.sh
```

to point to the installed toolchain.

---

## References

Toolchain used : aarch64--glibc--stable-2025.08-1.tar.xz
```
Dowload link : https://toolchains.bootlin.com/downloads/releases/toolchains/aarch64/tarballs/
```
Additional investigation notes are available in:

```
docs/toolchain-sysroot-compatibility.md
```
