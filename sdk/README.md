# SDK / Toolchain

## Purpose

This directory contains the ARM64 cross-compilation SDKs used by the project.

The actual SDK binaries are **not committed to Git** because they are large generated artifacts. The repository only stores the SDK directory structure, documentation, and reproducibility information.

---

## Why Two SDKs?

This project intentionally maintains **two SDKs with different purposes**:

1. **Official SDK** — the original Bootlin SDK used as the reference toolchain.
2. **Custom SDK** — an SDK regenerated from Buildroot with the common development libraries required by the project's BSP package framework.

The two SDKs are kept separate to avoid mixing toolchain, libc, headers, and libraries from different environments.

```text
                         Buildroot
                            │
              ┌─────────────┴─────────────┐
              │                           │
                    ▼                                         ▼
      Official Bootlin SDK         Custom Buildroot SDK
              │                           │
              │                           │
        Reference SDK              Project SDK
              │                           │
              └─────────────┬─────────────┘
                            │
                                          ▼
                  BSP Package Framework
                            │
             ┌──────────────┼──────────────┐
                   ▼                    ▼                    ▼
          BusyBox        Dropbear        rt-tests

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

## References

Toolchain used ( offical-sdk) : aarch64--glibc--stable-2025.08-1.tar.xz
```
Dowload link : https://toolchains.bootlin.com/downloads/releases/toolchains/aarch64/tarballs/
```
Additional investigation notes are available in:

```
docs/toolchain-sysroot-compatibility.md
```
