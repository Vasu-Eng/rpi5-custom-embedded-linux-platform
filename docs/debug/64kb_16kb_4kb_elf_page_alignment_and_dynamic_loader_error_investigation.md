# Raspberry Pi 5 ELF Page-Size / Dynamic Loader Investigation

## Project

`rpi5-custom-embedded-linux-platform`

## Target

Raspberry Pi 5 / AArch64

## Kernel

Custom Linux 6.18.x kernel with PREEMPT configuration.

## Investigation Status

**Conclusion established:**

- The kernel-side ELF/page-size investigation and changes were correct.
- The generated AArch64 userspace contains ELF `LOAD` segments with large alignment, observed as `0x10000` (64 KiB).
- The same userspace was successfully executed with both:
  - 16-KB kernel page size
  - 64-KB kernel page size
- The failure was observed with the 4-KB kernel page-size configuration.
- Therefore, the problem was **not** that the userspace required exactly a 64-KB kernel page size.
- The important compatibility boundary observed in this project is **>= 16 KB**.
- The runtime dependency issue encountered with Dropbear/cyclictest was a separate issue and must not be confused with the original 4-KB ELF-loading incompatibility.

---

# 1. Purpose of the Investigation

The purpose of this investigation was to understand why the custom AArch64 userspace could not start when used with a 4-KB-page-size kernel, while the same general userspace was expected to work with larger kernel page sizes.

The investigation covered:

1. ELF program headers.
2. `PT_INTERP`.
3. `DT_NEEDED` runtime dependencies.
4. Dynamic loader placement.
5. `/lib` vs `/usr/lib`.
6. Runtime dependency resolution from the Buildroot SDK sysroot.
7. BusyBox static vs dynamic linking.
8. ELF `LOAD` segment alignment.
9. Kernel ELF-loading/page-size behavior.
10. Testing with 4-KB, 16-KB and 64-KB kernel configurations.

---

# 2. Initial Observation

The initial failure occurred while starting `/init`.

The kernel successfully reached:

```text
Run /init as init process
```

but userspace failed during execution/loading:

```text
/bin/sh: error while loading shar...
Kernel panic - not syncing: Attempted to kill init!
exitcode=0x00007f00
```

This was initially interpreted as a dynamic-loader/runtime-library problem.

That interpretation turned out to be incomplete.

---

# 3. Initial BusyBox Configuration

The initial BusyBox configuration contained:

```text
# CONFIG_STATIC is not set
# CONFIG_PIE is not set
CONFIG_STATIC_LIBGCC=y
```

Therefore the newly built BusyBox was dynamically linked.

`file` reported:

```text
ELF 64-bit LSB pie executable, ARM aarch64,
version 1 (SYSV),
dynamically linked,
interpreter /lib/ld-linux-aarch64.so.1,
for GNU/Linux 3.7.0,
stripped
```

This established that `/bin/sh -> busybox` required the dynamic loader.

---

# 4. BusyBox PT_INTERP Investigation

The interpreter was verified with:

```bash
aarch64-buildroot-linux-gnu-readelf -l rpi_rootfs/bin/busybox
```

The relevant output was:

```text
INTERP
[Requesting program interpreter: /lib/ld-linux-aarch64.so.1]
```

Therefore BusyBox required:

```text
/lib/ld-linux-aarch64.so.1
```

---

# 5. Rootfs Runtime Files

The rootfs was checked directly.

Important files were:

```text
rpi_rootfs/bin/busybox
rpi_rootfs/bin/sh -> busybox

rpi_rootfs/lib/ld-linux-aarch64.so.1
rpi_rootfs/lib/libc.so.6
rpi_rootfs/lib/libm.so.6
rpi_rootfs/lib/libresolv.so.2

rpi_rootfs/usr/lib/libnuma.so.1
rpi_rootfs/usr/lib/libz.so.1
```

The actual generated initramfs was also extracted and checked:

```bash
mkdir -p /tmp/rpi-rootfs-check
rm -rf /tmp/rpi-rootfs-check/*
cd /tmp/rpi-rootfs-check

gzip -dc \
    ~/Projects/rpi5-custom-embedded-linux-platform/rpi_bootfs/rootfs.cpio.gz |
    cpio -idm
```

The required files were confirmed inside the actual `rootfs.cpio.gz`.

---

# 6. `/lib` vs `/usr/lib`

The rootfs was found to contain:

```text
/lib
├── ld-linux-aarch64.so.1
├── libc.so.6
├── libatomic.so.1
└── ...

/usr/lib
├── libnuma.so.1
├── libz.so.1
└── ...
```

This led to an investigation into whether runtime libraries were being copied to incorrect locations.

The distinction was established:

```text
SDK sysroot
        ↓
source of runtime libraries

rpi_rootfs/lib
        ↓
target /lib

rpi_rootfs/usr/lib
        ↓
target /usr/lib
```

For example:

```text
SYSROOT/lib/libc.so.6
        ↓
rpi_rootfs/lib/libc.so.6
```

and:

```text
SYSROOT/usr/lib/libz.so.1
        ↓
rpi_rootfs/usr/lib/libz.so.1
```

The resolver was modified/used to preserve this target filesystem layout.

---

# 7. Runtime Dependency Resolver

A project-wide runtime dependency resolver was developed.

Its intended operation is:

```text
package install directories
        ↓
scan ELF files
        ↓
read PT_INTERP
        ↓
read DT_NEEDED
        ↓
resolve libraries against SDK SYSROOT
        ↓
deduplicate
        ↓
preserve symlink chains
        ↓
copy runtime files into rpi_rootfs
```

The resolver receives:

```text
packages/
rpi_rootfs/
```

and uses the SDK environment already prepared with:

```bash
source sdk/environment-setup custom-sdk
```

The SDK provides:

```text
CROSS_COMPILE=aarch64-buildroot-linux-gnu-
SYSROOT=.../aarch64-buildroot-linux-gnu/sysroot
```

---

# 8. Dynamic Loader Failure — `/lib` vs `/usr/lib`

A separate runtime-loader problem was identified while testing dynamically linked applications.

Some required shared libraries were installed in:

```text
/usr/lib
```

For example:

```text
/usr/lib/libz.so.1
/usr/lib/libnuma.so.1
```

but the minimal userspace runtime search path was not automatically finding those libraries.

This produced errors such as:

```text
dropbear:
error while loading shared libraries:
libz.so.1: cannot open shared object file
```

and:

```text
cyclictest:
error while loading shared libraries:
libnuma.so.1: cannot open shared object file
```

The important observation was that the libraries **did exist**:

```text
/usr/lib/libz.so.1
/usr/lib/libnuma.so.1
```

Therefore this was not a dependency-discovery/copying failure.

The problem was:

```text
dynamic loader
      ↓
search path
      ↓
/lib
      ↓
library is actually in /usr/lib
      ↓
library not found
```

The fix was added to `startup.sh`:

```bash
export LD_LIBRARY_PATH=/lib:/usr/lib
```

After setting this environment variable, dynamically linked applications such as Dropbear were able to locate their libraries.

Therefore the final runtime layout intentionally keeps:

```text
/lib
    ├── ld-linux-aarch64.so.1
    ├── libc.so.6
    ├── libm.so.6
    └── ...

/usr/lib
    ├── libz.so.1
    ├── libnuma.so.1
    └── ...
```

and the runtime environment explicitly provides:

```bash
LD_LIBRARY_PATH=/lib:/usr/lib
```

This is a **separate issue from the kernel page-size/ELF compatibility problem**.

---

# 9. BusyBox Static Build

BusyBox required special treatment because it is the program providing the shell and many of the basic commands used by the system.

Examples include:

```text
/bin/sh
ls
cp
mv
mount
mkdir
echo
cat
ps
...
```

With dynamically linked BusyBox, the early userspace path is:

```text
/init
   ↓
/bin/sh
   ↓
/bin/busybox
   ↓
/lib/ld-linux-aarch64.so.1
   ↓
libc + other runtime dependencies
```

This makes BusyBox part of the earliest and most fundamental userspace execution path.

To avoid making the shell/command environment itself dependent on dynamic library loading, BusyBox was rebuilt as a static binary.

The BusyBox configuration was changed to:

```text
CONFIG_STATIC=y

# CONFIG_PIE is not set

CONFIG_STATIC_LIBGCC=y
```

After rebuilding:

```bash
file busybox
```

reported:

```text
ELF 64-bit LSB executable, ARM aarch64,
version 1 (GNU/Linux),
statically linked,
for GNU/Linux 3.7.0,
stripped
```

The resulting execution path is:

```text
kernel
   ↓
/init
   ↓
/bin/sh -> busybox
   ↓
STATIC BusyBox
   ↓
shell and BusyBox commands
```

BusyBox therefore does not need the dynamic loader just to start the shell and provide the basic command environment.

Other applications such as:

```text
dropbear
cyclictest
other rt-tests
```

can remain dynamically linked and use the runtime dependency resolver plus:

```bash
export LD_LIBRARY_PATH=/lib:/usr/lib
```

where required.

This was a deliberate design decision for the minimal initramfs.

---

# 26. Runtime Dependency Problem vs Page-Size Problem

These two problems must be kept separate.

## A. Dynamic loader/runtime search-path problem

```text
dropbear
    ↓
DT_NEEDED: libz.so.1
    ↓
/usr/lib/libz.so.1 exists
    ↓
runtime search path did not include /usr/lib
    ↓
loading failure
```

Fix:

```bash
export LD_LIBRARY_PATH=/lib:/usr/lib
```

Similarly:

```text
cyclictest
    ↓
DT_NEEDED: libnuma.so.1
    ↓
/usr/lib/libnuma.so.1
    ↓
LD_LIBRARY_PATH
    ↓
works
```

## B. Kernel ELF/page-size compatibility problem

Separately:

```text
large-alignment AArch64 ELF
        +
4-KB kernel
        ↓
ELF loading failure
```

while:

```text
large-alignment AArch64 ELF
        +
16-KB kernel
        ↓
WORKS
```

and:

```text
large-alignment AArch64 ELF
        +
64-KB kernel
        ↓
WORKS
```

The runtime dependency fix does **not** explain the page-size compatibility result.

Conversely, the page-size result does **not** remove the need to correctly resolve runtime libraries for dynamically linked applications.

The project therefore contains two independent fixes:

```text
Fix 1:
LD_LIBRARY_PATH=/lib:/usr/lib
        ↓
dynamic application runtime libraries

Fix 2:
kernel ELF/page-size compatibility
        ↓
4-KB vs >=16-KB behavior
```

---

# 26. Historical Backup Binary

An older BusyBox binary was found under:

```text
packages/busybox/source/
```

Its ELF headers showed:

```text
Elf file type is EXEC (Executable file)
```

with:

```text
LOAD ... Align 0x10000
LOAD ... Align 0x10000
```

The important additional fact was that this old binary was:

```text
statically linked
```

and the old test environment was based on the Raspberry Pi OS / Raspbian kernel environment.

Therefore the old binary was **not a valid proof by itself** of the current custom kernel/userspace compatibility.

The useful lesson was:

> ELF alignment must be investigated together with the actual kernel configuration and actual userspace being tested.

---

# 26. ELF Alignment Observation

The current dynamically linked BusyBox was inspected with:

```bash
aarch64-buildroot-linux-gnu-readelf -l \
    rpi_rootfs/bin/busybox
```

The 64-KB experiment showed:

```text
LOAD ... R E ... 0x10000
LOAD ... RW  ... 0x10000
```

The dynamic loader was also inspected:

```bash
aarch64-buildroot-linux-gnu-readelf -l \
    rpi_rootfs/lib/ld-linux-aarch64.so.1
```

and showed:

```text
LOAD ... R E ... 0x10000
LOAD ... RW  ... 0x10000
```

The value:

```text
0x10000
```

is:

```text
65536 bytes
64 KiB
```

This is ELF `LOAD` segment alignment (`p_align`), not a direct kernel `PAGE_SIZE` query.

It is nevertheless the relevant ELF property for this compatibility investigation.

---

# 26. SDK Investigation

The SDK was prepared with:

```bash
source sdk/environment-setup custom-sdk
```

The compiler was:

```text
aarch64-buildroot-linux-gnu-gcc.br_real
Buildroot 2025.05-670-g83947c7bb6
14.3.0
```

The SDK libc was:

```text
.../aarch64-buildroot-linux-gnu/sysroot/lib/libc.so.6
```

The ELF program headers of SDK libc showed large `LOAD` alignment.

The SDK was also searched for obvious page-size headers:

```bash
find "$SYSROOT/usr/include" \
    \( -name 'pagesize.h' -o -name 'page.h' \) \
    -print
```

No matching files were returned.

The compiler predefined macros were also checked:

```bash
"${CROSS_COMPILE}gcc" -dM -E -x c /dev/null |
grep -E 'PAGE_SIZE|PAGESIZE'
```

No output was returned.

This does not mean that the SDK lacks a page-size configuration.

Those checks simply were not the correct way to determine the ELF compatibility boundary.

The relevant observation is the ELF alignment of the actual SDK binaries.

---

# 26. Kernel-Side Investigation

The investigation then moved into the kernel ELF-loading code.

The important question was not:

> "Does the kernel page size have to exactly equal the ELF alignment?"

The actual compatibility behavior involves the ELF segment alignment and the kernel's supported page-size constraints.

The relevant behavior is that the required alignment is handled/rounded relative to the kernel page-size environment.

This explains the observed result:

```text
large ELF alignment
        ↓
kernel with 4-KB pages
        ↓
insufficient/incompatible alignment environment
        ↓
ELF loading failure
```

while:

```text
large ELF alignment
        ↓
kernel with >=16-KB pages
        ↓
compatible
        ↓
ELF loads
```

The kernel-side changes made during the investigation were therefore correct.

---

# 26. Controlled Page-Size Matrix

The decisive result was obtained by testing the same general userspace against different kernel page-size configurations.

## 4-KB

```text
4-KB kernel
    +
current AArch64 userspace
    ↓
ELF loading failure
```

Observed boot failure:

```text
Run /init as init process
/bin/sh: error while loading shared libraries: ...
Kernel panic - not syncing:
Attempted to kill init!
```

## 16-KB

```text
16-KB kernel
    +
same general userspace
    ↓
WORKING
```

## 64-KB

```text
64-KB kernel
    +
same general userspace
    ↓
WORKING
```

Therefore:

| Kernel page size | Current ELF/userspace | Result |
|---:|---|---|
| 4 KB | large-alignment AArch64 ELF | ❌ Incompatible |
| 16 KB | large-alignment AArch64 ELF | ✅ Works |
| 64 KB | large-alignment AArch64 ELF | ✅ Works |

This is the central result of the investigation.

---

# 26. Correct Root Cause

The root cause was **not**:

```text
"Dynamic libraries are missing."
```

That was a separate problem encountered while running applications.

The relevant compatibility issue was:

```text
AArch64 ELF LOAD alignment
        +
kernel page-size constraints
```

The generated ELF uses large alignment:

```text
0x10000 = 64 KiB
```

The kernel ELF-loading behavior is compatible with the resulting requirement when the kernel page-size environment is at least 16 KB in the tested configurations.

Therefore:

```text
4 KB
    ↓
not compatible with the generated ELF layout
```

while:

```text
16 KB
    ↓
compatible

64 KB
    ↓
compatible
```

---

# 26. Why the 64-KB Test Was Misinterpreted

During the investigation, the 64-KB kernel was incorrectly treated as a failing configuration.

That was an error in interpretation.

The correct observation is:

> **Both 16-KB and 64-KB configurations work.**

The failure that matters is the original 4-KB configuration.

The investigation therefore demonstrates compatibility with a range of kernel page sizes rather than requiring an exact 64-KB page size.

---

# 26. Why the Old Static BusyBox Was Misleading

The old binary showed:

```text
Align 0x10000
```

but was statically linked.

The current dynamic userspace contains:

```text
BusyBox
    ↓
PT_INTERP
    ↓
ld-linux-aarch64.so.1
    ↓
libc.so.6
    ↓
other DT_NEEDED libraries
```

Therefore static and dynamic tests cannot be treated as identical.

The static binary was useful as a historical reference, but not as proof of the complete dynamic-loader behavior.

---

# 26. Runtime Dependency Issue vs Page-Size Issue

These are two different layers.

## Layer 1 — ELF/kernel page-size compatibility

```text
4-KB kernel
+
large-alignment ELF
=
failure

16-KB kernel
+
large-alignment ELF
=
works

64-KB kernel
+
large-alignment ELF
=
works
```

## Layer 2 — dynamic library resolution

For example:

```text
dropbear
    ↓
DT_NEEDED: libz.so.1
    ↓
/usr/lib/libz.so.1
```

and:

```text
cyclictest
    ↓
DT_NEEDED: libnuma.so.1
    ↓
/usr/lib/libnuma.so.1
```

The second layer required correct runtime library search-path handling.

It does not invalidate the first conclusion.

---

# 26. Current Rootfs Architecture

The current initramfs contains:

```text
/
├── bin/
│   ├── busybox
│   └── sh -> busybox
├── etc/
├── lib/
│   ├── ld-linux-aarch64.so.1
│   ├── libc.so.6
│   ├── libm.so.6
│   └── libresolv.so.2
├── usr/
│   ├── bin/
│   │   ├── dropbearmulti
│   │   ├── cyclictest
│   │   └── other rt-tests
│   └── lib/
│       ├── libnuma.so.1
│       └── libz.so.1
└── init
```

This is a valid dynamic-userspace layout provided that the loader can resolve the required libraries.

---

# 26. Current Build Pipeline

The project build pipeline is now organized as:

```text
source SDK environment
        ↓
inspect SDK ELF alignment
        ↓
build BusyBox
        ↓
build Dropbear
        ↓
build rt-tests
        ↓
safe rootfs cleanup
        ↓
remove stale linuxrc
        ↓
rootfs-builder
        ↓
runtime dependency resolver
        ↓
rootfs.cpio.gz
        ↓
rpi_bootfs
        ↓
bootable SD-card image
```

The SDK setup happens before package builds:

```bash
source sdk/environment-setup custom-sdk
```

The pipeline can accept an optional SDK argument:

```bash
SDK_NAME="${1:-custom-sdk}"
```

Therefore:

```bash
./scripts/build_rootfs_pipeline.sh
```

uses:

```text
custom-sdk
```

while:

```bash
./scripts/build_rootfs_pipeline.sh another-sdk
```

uses:

```text
another-sdk
```

---

# 26. Page-Size Check in the Build Pipeline

The useful build-time check is based on actual SDK ELF files.

For example:

```bash
LIBC="$SYSROOT/lib/libc.so.6"

"${CROSS_COMPILE}readelf" -l "$LIBC" |
    grep -A1 'LOAD'
```

and:

```bash
LD="$SYSROOT/lib/ld-linux-aarch64.so.1"

"${CROSS_COMPILE}readelf" -l "$LD" |
    grep -A1 'LOAD'
```

The interpretation is:

```text
0x1000   = 4 KB
0x4000   = 16 KB
0x10000  = 64 KB
```

This is an ELF segment-alignment check.

It should not be described as a direct kernel `PAGE_SIZE` query.

---

# 26. Correct Final Investigation Conclusion

The investigation establishes the following:

1. The custom AArch64 userspace contains ELF `LOAD` segments with large alignment, observed as `0x10000` / 64 KiB.

2. The generated ELF is not restricted to an exactly 64-KB kernel page size.

3. The same userspace works with a 16-KB kernel.

4. The same userspace works with a 64-KB kernel.

5. The failure occurred with a 4-KB kernel configuration.

6. Therefore the tested compatibility boundary is:

```text
>= 16 KB
```

7. The kernel-side changes made for the ELF/page-size handling were correct and should be retained.

8. The runtime dependency problems involving:

```text
libz.so.1
libnuma.so.1
```

were real but separate issues.

9. The runtime dependency resolver remains useful and should remain part of the project because dynamically linked applications still require correct library placement and search-path handling.

10. The old statically linked BusyBox binary from the backup cannot be used as proof of dynamic-loader compatibility.

---

# 26. Final Compatibility Matrix

```text
                    ELF alignment ≈ 64 KB

                     Kernel page size

                 4 KB       16 KB       64 KB
                ───────    ───────      ───────
Userspace         FAIL       PASS         PASS
```

This is the result that should be preserved in the project documentation.

---

# 26. What Should Be Preserved in Git

Before committing:

```bash
git status --short
git diff --stat
```

Inspect the actual changes:

```bash
git diff -- scripts/resolve-runtime-deps.sh
git diff -- scripts/build_rootfs_pipeline.sh
```

Do not blindly stage generated files.

The investigation document can be committed with:

```bash
git add \
    docs/investigations/64kb-16kb-4kb-elf-page-alignment-investigation.md
```

If the resolver/pipeline modifications are also intended:

```bash
git add \
    docs/investigations/64kb-16kb-4kb-elf-page-alignment-investigation.md \
    scripts/resolve-runtime-deps.sh \
    scripts/build_rootfs_pipeline.sh
```

Then:

```bash
git commit -m "bsp: document ELF page-size compatibility investigation"
```

Verify:

```bash
git log -1 --oneline
git status
```

Generated files such as:

```text
rpi_rootfs/
rpi_bootfs/
*.img
temporary extraction directories
build artifacts
```

should only be committed if the project's Git policy explicitly tracks them.

---

# 26. Investigation Status

## Confirmed

- 4-KB configuration: **fails**
- 16-KB configuration: **works**
- 64-KB configuration: **works**
- ELF `LOAD` alignment: approximately 64 KB (`0x10000`)
- Dynamic loader exists
- libc exists
- runtime dependencies can be resolved
- Dropbear can run when its runtime library search path is correctly configured
- kernel-side ELF/page-size changes were correct

## Final Engineering Conclusion

The generated AArch64 userspace has an ELF alignment requirement that is compatible with the tested **16-KB and 64-KB kernel page-size configurations**, but not with the **4-KB configuration**.

The investigation therefore demonstrates a **minimum compatible page-size boundary of 16 KB for this generated userspace/kernel combination**, rather than a requirement for exactly 64 KB.

The project should retain the kernel changes and use the 16-KB configuration as the currently convenient working baseline, while 64 KB remains a valid working configuration.
