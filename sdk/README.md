# SDK / Toolchain

## Purpose

This directory contains the ARM64 cross-compilation SDKs used by the Raspberry Pi 5 BSP framework.

The actual SDK binaries are **not committed to Git** because they are large generated artifacts. The repository stores the SDK directory structure, documentation, and reproducibility information instead.

---

## Why Two SDKs?

This project intentionally maintains two SDKs with different purposes:

1. **Official SDK**
   - Original Bootlin SDK.
   - Kept unchanged as a reference toolchain.
   - Used to reproduce and compare the original development environment.

2. **Custom SDK**
   - Generated from Buildroot using the same base toolchain configuration.
   - Extended with the common development libraries required by this project's BSP package framework.
   - Used as the primary SDK for building project userspace packages.

The two SDKs are kept separate to prevent accidental mixing of compilers, glibc, headers, libraries, and sysroot components.

```text
                         Buildroot
                            |
              +-------------+-------------+
              |                           |
              v                           v
      Official Bootlin SDK        Custom Buildroot SDK
              |                           |
              v                           v
        Reference SDK              Project SDK
                                          |
                                          v
                              BSP Package Framework
                                          |
                         +----------------+----------------+
                         |                |                |
                         v                v                v
                      BusyBox          Dropbear          rt-tests
                                                           |
                                                           v
                                                       stress-ng
```

---

# Target Platform

The project targets:

```text
Board:              Raspberry Pi 5
Architecture:       ARM64 / AArch64
Target Userspace:   Debian GNU/Linux 13 (Trixie)
SDK:                Buildroot-generated ARM64 glibc SDK
```

The target userspace and the SDK are separate concepts.

The target system may use Debian GNU/Linux 13 userspace, while the cross-compilation SDK is generated using Buildroot.

---

# 1. Official SDK

The official SDK is:

```text
aarch64--glibc--stable-2025.08-1
```

It is provided by the Bootlin Toolchains service and was built using Buildroot.

## Toolchain Components

```text
GCC       14.3.0
Binutils  2.43.1
GDB       15.2
glibc     2.41
```

The SDK provides the base ARM64 cross-compilation environment:

```text
GCC
G++
Binutils
glibc
Linux headers
Dynamic linker
Basic sysroot
GDB
```

The official SDK is retained **unchanged** as the reference environment.

It is not modified with project-specific libraries or packages.

Official source:

https://toolchains.bootlin.com/

---

# 2. Custom SDK

The custom SDK is generated from the Buildroot configuration used by this project.

The starting point is the Bootlin Buildroot toolchain configuration:

```text
toolchains.bootlin.com-2025.08.1
```

The base configuration provides the ARM64 cross-compilation toolchain and glibc environment.

The project then enables the common development libraries required by the packages integrated by the BSP framework.

Examples may include:

```text
zlib
OpenSSL
libuuid
...
```

The exact set of libraries is determined by the dependencies of the packages supported by the framework.

The custom SDK is therefore the **primary SDK used for project package development**.

---

# Why Is the Custom SDK Required?

The original Bootlin SDK provides a valid ARM64 cross-compilation environment, but it does not contain every development library required by every userspace package.

For example, during Dropbear integration the original SDK reported:

```text
configure: error: *** zlib missing - install first or check config.log ***
```

Investigation showed that the SDK sysroot did not contain:

```text
libz.so
zlib.h
```

Instead of copying libraries from the host system or mixing libraries from unrelated distributions, the project generates a custom SDK using Buildroot.

This keeps the following components consistent:

```text
Compiler
    |
    +-- GCC
    |
    +-- Binutils
    |
    +-- glibc
          |
          v
       Sysroot
          |
          +-- headers
          +-- libraries
          +-- development files
```

---

# Why Keep the Official SDK?

The official SDK is retained as a known-good reference.

Keeping it provides the ability to:

- Compare the original and custom SDKs.
- Identify which libraries were added to the custom SDK.
- Reproduce the original Bootlin environment.
- Investigate toolchain and sysroot compatibility problems.
- Validate that custom SDK changes are intentional.
- Avoid modifying the original reference environment.

The official SDK should therefore be treated as **read-only**.

---

# SDK Responsibilities

The SDK provides the **development environment** required for cross-compilation.

It provides:

- Cross compiler
- Binutils
- glibc
- Linux headers
- Dynamic linker
- Development headers
- Common development libraries
- pkg-config environment
- GDB

The SDK is **not the target root filesystem**.

It is a development environment used to produce target binaries.

---

# Package Responsibilities

Applications integrated by this project are built separately using the custom SDK.

Current package targets include:

```text
BusyBox
Dropbear
rt-tests
stress-ng
```

These packages are intentionally built by the project's own package integration framework rather than being treated as the final Buildroot package layer.

The package integration framework performs:

```text
Package Source
      |
      v
Configuration
      |
      v
Cross Compilation
      |
      v
Package Installation / Staging
      |
      v
Runtime Dependency Analysis
      |
      v
RootFS Integration
```

This creates the following architectural boundary:

```text
                 Buildroot
                    |
                    v
              Custom SDK
                    |
                    v
        +-------------------------+
        | BSP Package Framework   |
        +-------------------------+
                    |
        +-----------+-----------+
        |           |           |
        v           v           v
     BusyBox     Dropbear    rt-tests
                                |
                                v
                            stress-ng
                    |
                    v
             Runtime Dependencies
                    |
                    v
                  RootFS
```

---

# SDK vs Target RootFS

The SDK contains development files needed to compile applications.

For example:

```text
SDK
|
+-- bin/
+-- lib/
+-- usr/include/
+-- usr/lib/
+-- compiler
+-- linker
```

The final target root filesystem contains only the runtime files required by the target system.

For example:

```text
Target RootFS
|
+-- bin/
+-- sbin/
+-- usr/bin/
+-- usr/sbin/
+-- lib/
+-- usr/lib/
+-- etc/
+-- var/
```

The SDK should **not** simply be copied into the target root filesystem.

Instead, package runtime dependencies are identified and integrated into the root filesystem.

Example:

```text
Dropbear executable
        |
        v
ELF dependency analysis
        |
        v
Required runtime libraries
        |
        v
Target RootFS
```

---

# SDK Compatibility Rule

The compiler, linker, libc, headers and sysroot must come from the same SDK generation.

Do not mix:

```text
Compiler from Official SDK
        +
Sysroot from Custom SDK
```

or:

```text
Compiler from Custom SDK
        +
Libraries copied from Debian
```

The purpose of maintaining the custom SDK is to provide a controlled and consistent cross-compilation environment.

Mixing incompatible libc or sysroot components can result in linker or runtime failures.

A previous project investigation involved errors caused by an older host toolchain being used against a newer target sysroot.

That investigation is documented separately in:

```text
docs/toolchain-sysroot-compatibility.md
```

The historical investigation should not be confused with the current two-SDK architecture.

---

# Repository Structure

```text
sdk/
|
+-- README.md
|
+-- official-sdk/
|   |
|   +-- README.md
|   +-- .gitkeep
|
+-- custom-sdk/
    |
    +-- README.md
    +-- .gitkeep
```

The actual SDK contents are intentionally excluded from Git.

## official-sdk/

Contains the extracted original Bootlin SDK:

```text
aarch64--glibc--stable-2025.08-1/
```

This is the reference SDK.

## custom-sdk/

Contains the SDK generated from the project's Buildroot configuration.

This is the primary SDK used by the BSP package framework.

## README.md

Documents the overall SDK architecture and explains why both SDKs exist.

---

# Reproducing the Base Toolchain

The official Bootlin SDK can be reproduced using the Bootlin Buildroot toolchain repository.

```bash
git clone https://github.com/bootlin/buildroot-toolchains.git buildroot

cd buildroot

git checkout toolchains.bootlin.com-2025.08.1

curl http://toolchains.bootlin.com/downloads/releases/toolchains/aarch64/build_fragments/aarch64--glibc--stable-2025.08-1.defconfig > .config

make olddefconfig

make

make sdk
```

This reproduces the base ARM64 glibc SDK.

---

# Generating the Custom SDK

The custom SDK starts from the same Buildroot configuration.

After loading the base configuration:

```bash
make olddefconfig
```

open the Buildroot configuration:

```bash
make menuconfig
```

Enable the common development libraries required by the project.

For example:

```text
zlib
OpenSSL
libuuid
...
```

The exact set should be based on the dependencies of the packages supported by the BSP framework.

The following applications are intentionally built outside the Buildroot package layer by the project's own package framework:

```text
BusyBox
Dropbear
rt-tests
stress-ng
```

After configuring the SDK:

```bash
make
make sdk
```

The generated SDK is then extracted into:

```text
sdk/custom-sdk/
```

---

# Using the Custom SDK

After extracting the SDK, source its environment setup script:

```bash
source sdk/custom-sdk/environment-setup
```

Verify the compiler:

```bash
echo "$CC"
```

Verify the sysroot:

```bash
echo "$SYSROOT"
```

Verify the compiler version:

```bash
${CC} --version
```

The package build scripts use this environment for cross-compilation.

---

# Development Flow

The intended development flow is:

```text
             Buildroot
                 |
                 v
        Custom ARM64 SDK
                 |
                 v
        Environment Setup
                 |
                 v
        Package Compilation
                 |
        +--------+--------+
        |        |        |
        v        v        v
     BusyBox  Dropbear  rt-tests
                          |
                          v
                      stress-ng
        |
        v
 Runtime Dependency Analysis
        |
        v
      RootFS
        |
        v
 Raspberry Pi 5 Boot Image
        |
        v
 PREEMPT_RT Validation
```

---

# Design Boundary

This project does not attempt to replace Buildroot completely.

Buildroot is used where it provides mature infrastructure:

```text
Toolchain generation
Sysroot generation
Common development libraries
SDK generation
```

The project focuses on the BSP and package integration stages above the SDK:

```text
Package integration
Package compilation
Package installation
Runtime dependency handling
RootFS assembly
Kernel integration
Device Tree integration
Boot image integration
PREEMPT_RT validation
```

This separation keeps the project focused on understanding and implementing the BSP integration workflow rather than reimplementing GCC, glibc, or Buildroot itself.

---

# References

## Bootlin Toolchains

https://toolchains.bootlin.com/

## Bootlin Buildroot Toolchain Repository

https://github.com/bootlin/buildroot-toolchains

## Toolchain

```text
aarch64--glibc--stable-2025.08-1
```

## Toolchain Compatibility Investigation

```text
docs/toolchain-sysroot-compatibility.md
```
