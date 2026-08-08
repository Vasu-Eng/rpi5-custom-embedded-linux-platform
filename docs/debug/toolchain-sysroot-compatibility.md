# Toolchain and Sysroot Compatibility Investigation

## Objective

Cross-compile `rt-tests` for Raspberry Pi 5 using:

- Ubuntu 22.04 ARM64 cross compiler
- Raspberry Pi OS (64-bit) sysroot
- Custom Embedded Linux project environment

---

## Environment

### Host

| Component | Version |
|----------|---------|
| OS | Ubuntu 22.04 |
| Compiler | gcc-aarch64-linux-gnu 11.4 |
| Architecture | x86_64 |

### Target

| Component | Version |
|----------|---------|
| Board | Raspberry Pi 5 |
| OS | Raspberry Pi OS (64-bit) |
| Architecture | ARM64 |

---

## Project Layout

```
toolchain/
sysroot/
benchmark-tools/
scripts/
docs/
```

---

## Sysroot Creation

The sysroot was created from the Raspberry Pi OS root filesystem.

Additional development files were imported manually.

Example:

- libnuma-dev
- ARM64 headers
- pkg-config files

---

## Build Environment

The project uses a reusable environment script.

```
scripts/environment.sh
```

Key variables:

```
PROJECT_ROOT
SYSROOT
CROSS_COMPILE
PKG_CONFIG_SYSROOT_DIR
PKG_CONFIG_LIBDIR
```

---

## Initial Build Failure

The first build failed with:

```
fatal error:

rt-utils.h: No such file or directory
```

### Root Cause

The build script overwrote `CPPFLAGS`.

This removed:

```
-Isrc/include
```

from the compiler command.

### Resolution

Do not overwrite the upstream `CPPFLAGS`.

Instead, preserve the include path provided by the upstream Makefile.

---

## Second Build Failure

Compilation completed successfully.

The linker failed with:

```
undefined reference to

__isoc23_strtol@GLIBC_2.38
__isoc23_strtoul@GLIBC_2.38
__isoc23_sscanf@GLIBC_2.38
```

---

## Investigation

The ARM64 sysroot exports:

```
GLIBC_2.38
GLIBC_2.39
GLIBC_2.41
```

The Ubuntu 22.04 cross compiler provides an older glibc implementation.

As a result,

```
libnuma.so
```

was compiled against a newer libc ABI than the toolchain can link against.

---

## Root Cause

Toolchain ABI != Sysroot ABI

```
Ubuntu Toolchain

glibc 2.35

        ×

Raspberry Pi OS Sysroot

glibc 2.41
```

The compiler, linker and runtime libraries must target the same libc ABI.

---

## Lessons Learned

A sysroot alone is not sufficient.

A complete cross-compilation SDK consists of:

- Compiler
- Binutils
- C Library
- Headers
- Sysroot
- pkg-config metadata

All components must be compatible.

---

## Future Work

Replace the Ubuntu cross toolchain with a modern SDK.

Possible options:

- Bootlin Toolchain
- Buildroot SDK
- Yocto SDK

This will provide:

- matching compiler
- matching glibc
- matching sysroot
- reproducible builds

without ABI mismatches.

---

## Status

Current status:

✅ Custom ARM64 sysroot

✅ Cross compilation environment

✅ Dependency management

❌ Toolchain / glibc ABI compatibility

Next milestone:

Replace the host cross toolchain with a compatible SDK and rebuild `rt-tests`.
