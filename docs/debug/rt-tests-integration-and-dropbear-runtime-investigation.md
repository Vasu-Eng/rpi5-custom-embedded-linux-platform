# Investigation Log: rt-tests Integration & Dropbear Runtime Failure

**Date:** 2026-08-07

---

# Objective

Integrate the `rt-tests` benchmarking suite into the custom Raspberry Pi 5 Embedded Linux image for PREEMPT_RT latency benchmarking.

---

# Phase 1 - Building rt-tests

## Initial Problems

Compilation failed with multiple missing header errors.

```
fatal error: rt-utils.h: No such file or directory
fatal error: rt-error.h: No such file or directory
fatal error: pi_stress.h: No such file or directory
```

### Root Cause

Only the sysroot include directory was passed to the compiler.

The project-local include directory:

```
src/include
```

was not being added.

### Resolution

Updated build flags so that both include paths are used.

```
-I${SYSROOT}/usr/include/aarch64-linux-gnu
-Isrc/include
```

---

# Phase 2 - 16 KB Page Size Crash

After successful compilation every executable immediately crashed.

Examples:

```
Segmentation fault
```

Affected binaries

- cyclictest
- oslat
- queuelat

---

## Investigation

The binaries executed correctly on Raspberry Pi OS but crashed on the custom image.

Running the dynamic loader manually produced

```
ELF load command address/offset not page-aligned
```

---

## ELF Analysis

Using

```
readelf -lW
```

showed

Old binary

```
LOAD
Offset : 0x000000
Align  : 0x1000

LOAD
Offset : 0x00c9b0
Align  : 0x1000
```

The custom kernel was built with

```
CONFIG_ARM64_16K_PAGES=y
```

which requires

```
0x10000
```

alignment.

---

## Validation

A small hello world application was compiled.

Default binary

```
Align = 0x1000
```

Modified linker

```
-Wl,-z,max-page-size=0x10000
```

Result

```
Align = 0x10000
```

Testing

```
hello
```

↓

```
Segmentation fault
```

Testing

```
hello_64k
```

↓

```
Hello
```

This confirmed that the issue was page alignment.

---

## Resolution

Updated linker flags

```
-Wl,-z,max-page-size=0x10000
```

inside

```
environment.sh
```

Result

```
readelf

LOAD Align = 0x10000
```

rt-tests binaries no longer crashed because of page alignment.

---

# Phase 3 - Runtime Dependency

Executing

```
cyclictest
```

produced

```
error while loading shared libraries:
libnuma.so.1
```

---

## Investigation

Used

```
readelf -d
```

to inspect every executable.

Dependencies discovered

```
libnuma.so.1
libc.so.6
ld-linux-aarch64.so.1
```

---

## Improvement

The build system was enhanced.

Instead of manually copying runtime libraries,

the script now

- installs executables
- scans ELF dependencies
- searches the sysroot
- copies runtime libraries
- reports missing dependencies

This automated runtime dependency installation.

---

# Phase 4 - SSH Suddenly Failed

After rebuilding the image

```
ssh
```

returned

```
Connection refused
```

---

## Investigation

Verified

```
ps | grep dropbear
```

Result

```
Dropbear was not running.
```

Manual execution

```
dropbear -E
```

produced

```
symbol lookup error

__tunable_is_initialized

GLIBC_PRIVATE
```

---

# Phase 5 - GLIBC Runtime Investigation

Initially it appeared that copying runtime libraries had broken Dropbear.

Investigation compared

```
ROOTFS
```

vs

```
SYSROOT
```

### libc

```
cmp

ROOTFS libc.so.6

SYSROOT libc.so.6
```

Result

```
Identical
```

---

### Dynamic Loader

```
cmp

ROOTFS ld-linux-aarch64.so.1

SYSROOT ld-linux-aarch64.so.1
```

Result

```
Different
```

SHA256 comparison confirmed

```
Different binaries
```

---

# Root Cause

Dropbear was **not built using the Buildroot toolchain**.

It had previously been copied manually from another Linux system.

Therefore

```
Dropbear
```

expected one glibc runtime

while

```
ROOTFS
```

contained a different runtime.

This resulted in

```
GLIBC_PRIVATE
```

symbol lookup failures.

The failure was **not caused by rt-tests**.

The rt-tests work simply exposed an existing runtime inconsistency.

---

# Lessons Learned

## 1.

All user-space applications must be built using the same toolchain.

Never mix binaries originating from different distributions.

---

## 2.

glibc is a complete runtime.

Components such as

- libc.so.6
- ld-linux-aarch64.so.1
- libpthread.so.0
- librt.so.1
- libm.so.6

must originate from the same build.

Mixing versions results in runtime failures.

---

## 3.

Automatically copying runtime libraries is useful,

but glibc requires special handling.

The dependency installer should avoid blindly replacing the C runtime.

---

## 4.

Every third-party package should become part of the BSP build system.

Recommended workflow

```
Source

↓

Cross Compile

↓

Install

↓

Resolve Runtime Dependencies

↓

Copy to RootFS

↓

Package RootFS

↓

Boot & Validate
```

---

# Next Action

Remove the manually copied Dropbear.

Cross-compile Dropbear using the Buildroot cross-toolchain.

Install the resulting binaries into the custom root filesystem.

Resolve runtime dependencies from the same sysroot to ensure a consistent runtime environment.
