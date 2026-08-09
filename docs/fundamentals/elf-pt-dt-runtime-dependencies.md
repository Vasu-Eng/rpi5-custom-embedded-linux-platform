# ELF Fundamentals: PT, DT and Runtime Dependencies

## Overview

When building an Embedded Linux system, compiling an application is only one part of the problem.

For a dynamically linked executable, the target root filesystem must contain:

1. The executable itself
2. The ELF dynamic loader
3. All required shared libraries
4. All transitive dependencies of those libraries

For example:

```text
cyclictest
    |
    +-- Dynamic Loader
    |      |
    |      +-- /lib/ld-linux-aarch64.so.1
    |
    +-- Shared Libraries
           |
           +-- libnuma.so.1
           +-- libc.so.6
```

Two important kinds of ELF metadata are involved:

```text
PT_*  -> Program Header information
DT_*  -> Dynamic linking information
```

---

# 1. ELF File Structure

An ELF (Executable and Linkable Format) file contains information describing how an executable or shared library should be loaded and linked.

Conceptually:

```text
ELF File
│
├── ELF Header
│
├── Program Header Table
│      │
│      └── PT_*
│
├── Sections
│      │
│      ├── .text
│      ├── .data
│      ├── .rodata
│      ├── .dynamic
│      └── ...
│
└── Section Header Table
```

For runtime execution, the Program Header Table and Dynamic Section are particularly important.

---

# 2. PT — Program Header Types

`PT_*` entries are program header types.

They describe information required to load and execute an ELF program.

Inspect them with:

```bash
readelf -l <binary>
```

For an AArch64 executable:

```bash
aarch64-buildroot-linux-gnu-readelf -l cyclictest
```

You may see entries such as:

```text
Type           Offset   VirtAddr
LOAD           ...
LOAD           ...
DYNAMIC        ...
INTERP         ...
GNU_STACK      ...
```

These are `PT_*` entries.

---

# 3. PT_INTERP

One of the most important entries for dynamically linked executables is:

```text
PT_INTERP
```

It specifies the program interpreter, commonly called the dynamic loader.

Check it with:

```bash
readelf -l cyclictest
```

or:

```bash
aarch64-buildroot-linux-gnu-readelf -l cyclictest |
grep 'Requesting program interpreter'
```

Example:

```text
[Requesting program interpreter: /lib/ld-linux-aarch64.so.1]
```

This means:

```text
cyclictest
    |
    +-- PT_INTERP
            |
            v
/lib/ld-linux-aarch64.so.1
```

Therefore the target root filesystem must contain the required interpreter at the path specified by the ELF.

---

# 4. DT — Dynamic Tags

`DT_*` entries describe dynamic-linking information.

They are contained in the ELF dynamic section.

Inspect them using:

```bash
readelf -d <binary>
```

For our AArch64 target:

```bash
aarch64-buildroot-linux-gnu-readelf -d cyclictest
```

You may see entries such as:

```text
Dynamic section at offset ...

Tag        Type
NEEDED     Shared library: [libnuma.so.1]
NEEDED     Shared library: [libc.so.6]
...
```

These `NEEDED` entries correspond to:

```text
DT_NEEDED
```

---

# 5. DT_NEEDED

`DT_NEEDED` tells the dynamic loader which shared libraries are required by the executable.

For example:

```text
cyclictest
    |
    +-- DT_NEEDED
          |
          +-- libnuma.so.1
          |
          +-- libc.so.6
```

Inspect with:

```bash
aarch64-buildroot-linux-gnu-readelf -d \
    packages/rt-tests/install/usr/bin/cyclictest |
grep NEEDED
```

The exact dependencies must be obtained from the actual ELF binary rather than assumed.

---

# 6. PT vs DT

The simplest way to remember the difference is:

```text
PT -> How should the program be loaded?

DT -> What dynamic dependencies does it need?
```

| ELF information | Purpose | Inspection |
|---|---|---|
| `PT_*` | Program loading/runtime information | `readelf -l` |
| `DT_*` | Dynamic linking information | `readelf -d` |
| `PT_INTERP` | Dynamic loader path | `readelf -l` |
| `DT_NEEDED` | Required shared libraries | `readelf -d` |

---

# 7. Why Both Matter for Embedded Linux

Consider:

```text
cyclictest
```

First inspect its program interpreter:

```bash
aarch64-buildroot-linux-gnu-readelf -l \
    packages/rt-tests/install/usr/bin/cyclictest |
grep 'Requesting program interpreter'
```

Suppose it reports:

```text
/lib/ld-linux-aarch64.so.1
```

The rootfs therefore needs that interpreter at the path specified by the ELF.

Now inspect dynamic dependencies:

```bash
aarch64-buildroot-linux-gnu-readelf -d \
    packages/rt-tests/install/usr/bin/cyclictest |
grep NEEDED
```

Suppose the output contains:

```text
libnuma.so.1
libc.so.6
```

Then those runtime libraries must also be available in the target root filesystem.

---

# 8. Runtime Dependencies Are Recursive

This is extremely important.

Suppose:

```text
cyclictest
    |
    +-- libnuma.so.1
```

We cannot assume that `libnuma.so.1` has no dependencies.

`libnuma.so.1` is itself an ELF shared library.

We therefore inspect it:

```bash
aarch64-buildroot-linux-gnu-readelf -d \
    libnuma.so.1 |
grep NEEDED
```

It may have:

```text
DT_NEEDED
    libc.so.6
```

Therefore:

```text
cyclictest
    |
    +-- libnuma.so.1
            |
            +-- libc.so.6
```

This is a transitive runtime dependency.

A proper dependency resolver must continue recursively until all required dependencies have been resolved.

---

# 9. Dependency Resolution in Our Embedded Linux Project

Our project uses a Buildroot-generated AArch64 SDK.

The target sysroot is under the SDK, for example:

```text
sdk/custom-sdk/
└── aarch64-sdk/
    └── aarch64-buildroot-linux-gnu/
        └── sysroot/
```

Runtime libraries should be resolved against the target SDK sysroot, not the host Debian system.

Do not use:

```bash
ldd cyclictest
```

as the primary dependency resolver on the x86-64 development machine.

Instead, inspect the target ELF using the cross-toolchain:

```bash
aarch64-buildroot-linux-gnu-readelf
```

---

# 10. Example: rt-tests

The `rt-tests` package produces binaries such as:

```text
cyclictest
cyclicdeadline
oslat
hackbench
pi_stress
signaltest
...
```

For example:

```bash
aarch64-buildroot-linux-gnu-readelf -d \
    packages/rt-tests/install/usr/bin/cyclictest |
grep NEEDED
```

and:

```bash
aarch64-buildroot-linux-gnu-readelf -l \
    packages/rt-tests/install/usr/bin/cyclictest |
grep 'Requesting program interpreter'
```

These commands tell us:

```text
cyclictest
    |
    +-- PT_INTERP
    |      |
    |      +-- dynamic loader
    |
    +-- DT_NEEDED
           |
           +-- shared library 1
           +-- shared library 2
           +-- ...
```

---

# 11. Runtime Dependency Resolution Flow

Our runtime dependency resolver should eventually implement:

```text
Package install/
        |
        v
Find ELF files
        |
        v
Inspect PT_INTERP
        |
        v
Find dynamic loader
        |
        v
Inspect DT_NEEDED
        |
        v
Find libraries in target SDK sysroot
        |
        v
Inspect each library's DT_NEEDED
        |
        v
Resolve recursively
        |
        v
Copy required runtime files
        |
        v
rootfs/
```

Conceptually:

```text
              cyclictest
                  |
          +-------+-------+
          |               |
      PT_INTERP        DT_NEEDED
          |               |
          v               v
   ld-linux...       libnuma.so.1
                          |
                      DT_NEEDED
                          |
                          v
                       libc.so.6
```

---

# 12. Useful Commands

### Show program headers

```bash
aarch64-buildroot-linux-gnu-readelf -l <binary>
```

### Show dynamic section

```bash
aarch64-buildroot-linux-gnu-readelf -d <binary>
```

### Show only required libraries

```bash
aarch64-buildroot-linux-gnu-readelf -d <binary> |
grep NEEDED
```

### Show dynamic loader

```bash
aarch64-buildroot-linux-gnu-readelf -l <binary> |
grep 'Requesting program interpreter'
```

### Find a library in the SDK

```bash
find "$SYSROOT" -name 'libnuma.so*'
```

---

# 13. Key Mental Model

Remember these three questions:

### Question 1

**What loads my program?**

Look at:

```text
PT_INTERP
```

### Question 2

**What shared libraries does my program require?**

Look at:

```text
DT_NEEDED
```

### Question 3

**What does each required library require?**

Inspect the library's own:

```text
DT_NEEDED
```

This produces the complete runtime dependency graph.

---

# 14. Relation to Rootfs Construction

The ultimate goal is not simply to make the binary compile.

The goal is:

```text
AArch64 binary
      |
      v
runtime dependency analysis
      |
      v
required loader + libraries
      |
      v
rootfs
      |
      v
bootable Raspberry Pi Linux system
```

For this project, the final build pipeline will eventually become:

```text
SDK
 |
 +-- compile packages
 |
 +-- install packages
 |
 +-- resolve runtime dependencies
 |
 +-- assemble rootfs
 |
 +-- build filesystem/image
 |
 +-- generate final Raspberry Pi .img
```

The runtime dependency resolver therefore sits directly between package installation and rootfs construction.
