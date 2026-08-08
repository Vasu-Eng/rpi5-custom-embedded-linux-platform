Investigation Log 006

Cross-Compiling rt-tests for a Custom PREEMPT_RT Raspberry Pi 5 Image

Date: 2026-08-06

Objective

Cross-compile the latest rt-tests for a custom Raspberry Pi 5 EmbeddedLinux image running a PREEMPT_RT kernel and integrate the binaries intothe project's custom root filesystem.

Environment

Host

Ubuntu 24.04

Bootlin ARM64 Toolchain (GCC 14.3)

Target

Raspberry Pi 5

Custom Embedded Linux Image

PREEMPT_RT Kernel

16 KB Kernel Page Size

Completed Work

1. Debian Multiarch Header Issue

Fixed missing bits/libc-header-start.h

Added -I${SYSROOT}/usr/include/aarch64-linux-gnu

2. glibc 2.41 Compatibility

Investigated upstream rt-tests

Applied commit 30644eae4467

Guarded struct sched_attr with #ifndef SCHED_ATTR_SIZE_VER0

3. Missing CRT Startup Objects

Resolved missing: - Scrt1.o - crt1.o - crti.o - crtn.o -libc_nonshared.a

4. Linker Search Path

Verified with a Hello World application. Added: --B${SYSROOT}/usr/lib/aarch64-linux-gnu --B${SYSROOT}/lib/aarch64-linux-gnu

5. Build Automation

Created: - scripts/environment.sh - scripts/build_rt_tests.sh

Automated: - Environment setup - Cross compilation - Installation intoproject rootfs

6. Successful Build

Successfully cross-compiled the complete rt-tests suite.

Runtime Investigation

Binaries installed successfully but: - cyclictest -> Segmentationfault - oslat -> Segmentation fault - queuelat -> Segmentation fault

Dynamic loader output:

ELF load command address/offset not page-aligned

Additional findings: - Kernel page size: 16 KB - ELF LOAD segmentalignment: 0x1000

Current Status

Completed: - Bootlin toolchain integration - Debian sysrootintegration - glibc 2.41 compatibility - Linker fixes - Completert-tests cross-build - Automated installation

Current blocker: Runtime ELF loader rejection on the custom PREEMPT_RTimage. Root cause is still under investigation.

Next Steps

Inspect linker page-size configuration.

Compare ELF headers with a working binary.

Verify compatibility with a 16 KB page kernel.

Identify the exact loader incompatibility.
