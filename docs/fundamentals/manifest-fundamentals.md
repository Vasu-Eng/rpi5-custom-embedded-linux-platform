# RootFS Manifest Architecture and Runtime Ownership

## 1. Purpose

This document explains the **manifest mechanism** used by the custom Embedded Linux root filesystem build system in this project.

The project does not treat `rpi_rootfs/` as an unstructured directory where files are copied blindly. Instead, it separates ownership into two logical domains:

1. **Package-owned files**
2. **Runtime-dependency-owned files**

This separation is necessary because the root filesystem contains both package content and ELF runtime dependencies.

The manifests allow the build system to determine:

- which files belong to packages,
- which files were installed because an ELF dependency required them,
- which files are still required,
- which files are stale,
- whether an existing file is safe to overwrite,
- and which parts of the root filesystem must not be touched by automated cleanup.

---

# 2. Why a Manifest Is Necessary

A root filesystem is not simply a collection of independent files.

For example:

```text
/usr/bin/cyclictest
        |
        +---- PT_INTERP
        |       |
        |       +---- /lib/ld-linux-aarch64.so.1
        |
        +---- DT_NEEDED
                |
                +---- libnuma.so.1
                |       |
                |       +---- libatomic.so.1
                |
                +---- libc.so.6
                |
                +---- ld-linux-aarch64.so.1
```

Some files are installed because they are explicitly present in a package. Other files are installed because an executable requires them at runtime.

Without ownership tracking:

- package rebuilds can overwrite runtime files,
- runtime cleanup can delete package files,
- stale libraries can remain forever,
- obsolete versioned `.so` files can accumulate,
- configuration files can be accidentally deleted,
- incremental builds become dependent on undocumented previous state.

The manifest mechanism makes ownership explicit.

---

# 3. The Two-Manifests Model

The project uses two manifests:

```text
rpi_rootfs/.metadata/
├── package-files.manifest
└── runtime-libs.manifest
```

They have different responsibilities.

## 3.1 Package manifest

`package-files.manifest` records files owned by package installation.

The current ownership policy covers:

```text
/bin/*
/sbin/*
/usr/bin/*
/usr/sbin/*
/usr/share/*
```

Examples:

```text
bin/busybox
bin/sh
usr/bin/cyclictest
usr/bin/oslat
usr/sbin/dropbear
usr/share/man/man8/cyclictest.8
```

The current project checkpoint contains 448 package-owned entries.

## 3.2 Runtime manifest

`runtime-libs.manifest` records files installed because they are required by the runtime dependency graph of ELF binaries.

Typical entries include:

```text
/lib/ld-linux-aarch64.so.1
/lib/libc.so.6
/lib/libm.so.6
/lib/libresolv.so.2
/lib/libatomic.so.1
/lib/libatomic.so.1.2.0
/usr/lib/libnuma.so.1
/usr/lib/libnuma.so.1.0.0
/usr/lib/libz.so.1
/usr/lib/libz.so.1.3.1
```

The runtime manifest records both library symlinks and their actual versioned target files.

---

# 4. Ownership Boundaries

The package builder and runtime resolver do not have unlimited authority over the root filesystem.

## 4.1 Package-owned namespaces

The package builder is responsible for:

```text
/bin/*
/sbin/*
/usr/bin/*
/usr/sbin/*
/usr/share/*
```

This is intentionally based on **directory namespaces**, not hardcoded filenames.

For example, the system does not assume that only:

```text
bin/busybox
bin/sh
bin/cpio
```

are package files.

Any package file installed under the supported namespaces can be tracked.

---

# 5. Why Ownership Must Not Be Hardcoded by Filename

A fragile implementation would contain:

```text
bin/busybox
bin/sh
bin/cpio
usr/bin/cyclictest
usr/bin/oslat
```

That does not scale.

A new package could install:

```text
usr/bin/my-new-tool
```

and the ownership mechanism would require source-code modification.

The project instead uses namespace-based ownership:

```text
bin/*
sbin/*
usr/bin/*
usr/sbin/*
usr/share/*
```

Package composition can therefore change without changing ownership logic.

---

# 6. Runtime Ownership Is Dependency-Based

Runtime files are different.

The project does not maintain a hardcoded list such as:

```text
libc.so.6
libm.so.6
libz.so.1
libnuma.so.1
```

Instead, runtime ownership is derived from the ELF dependency graph.

The resolver examines each ELF executable and determines:

1. its program interpreter,
2. its direct `DT_NEEDED` dependencies,
3. dependencies of those libraries,
4. and so on recursively.

The runtime manifest is therefore generated from the dependency graph.

---

# 7. ELF Program Interpreter: PT_INTERP

A dynamically linked ELF executable may contain a `PT_INTERP` program header.

For example:

```text
Requesting program interpreter:
/lib/ld-linux-aarch64.so.1
```

This identifies the dynamic loader the kernel must use to execute the ELF.

Conceptually:

```text
kernel
   |
   +-- execve("/usr/bin/cyclictest")
             |
             +-- PT_INTERP
                    |
                    +-- /lib/ld-linux-aarch64.so.1
```

The interpreter is therefore itself a runtime dependency and must exist in the root filesystem.

---

# 8. ELF Dynamic Dependencies: DT_NEEDED

ELF dynamic sections can contain `DT_NEEDED` entries.

For example:

```text
NEEDED Shared library: [libnuma.so.1]
NEEDED Shared library: [libc.so.6]
NEEDED Shared library: [ld-linux-aarch64.so.1]
```

These entries describe libraries required by the executable.

The resolver maps each library name to a physical path in the SDK/sysroot.

Example:

```text
libnuma.so.1
        |
        +-- /usr/lib/libnuma.so.1
```

That library is then inspected for its own `DT_NEEDED` entries.

---

# 9. Recursive Dependency Resolution

Runtime dependency resolution is a graph traversal problem.

Example:

```text
cyclictest
 |
 +-- libnuma.so.1
 |      |
 |      +-- libatomic.so.1
 |      |      |
 |      |      +-- libc.so.6
 |      |
 |      +-- libc.so.6
 |
 +-- libc.so.6
 |
 +-- ld-linux-aarch64.so.1
```

The resolver must not stop after one level.

If:

```text
A -> B
B -> C
C -> D
```

then the runtime rootfs requires:

```text
A
B
C
D
```

not only `A` and `B`.

This is why recursive resolution and a processed-dependency set are required.

---

# 10. Unique Dependencies

Different executables frequently depend on the same library.

For example:

```text
busybox      -> libc.so.6
cyclictest   -> libc.so.6
dropbear     -> libc.so.6
```

The root filesystem only needs one copy.

The resolver therefore maintains a unique dependency set.

Conceptually:

```text
busybox
   |
   +---- libc.so.6
   |
cyclictest
   |
   +---- libc.so.6
   |
dropbear
   |
   +---- libc.so.6
```

becomes:

```text
Runtime dependency set:

libc.so.6
```

This is why the resolver can report a unique dependency count separately from the number of ELF files scanned.

---

# 11. Shared-Library Symlinks

Linux shared libraries commonly use a symlink chain.

Example:

```text
libz.so.1
    -> libz.so.1.3.1
```

The two filesystem objects have different roles:

```text
libz.so.1
    symbolic link

libz.so.1.3.1
    actual library file
```

The runtime resolver must preserve both.

The project therefore records:

```text
/usr/lib/libz.so.1
/usr/lib/libz.so.1.3.1
```

Likewise:

```text
/usr/lib/libnuma.so.1
/usr/lib/libnuma.so.1.0.0
```

and:

```text
/lib/libatomic.so.1
/lib/libatomic.so.1.2.0
```

---

# 12. Why the Versioned Target Must Be Tracked

Suppose an older SDK contains:

```text
libz.so.1
    -> libz.so.1.3.1
```

and a future SDK contains:

```text
libz.so.1
    -> libz.so.1.3.2
```

The desired rootfs becomes:

```text
libz.so.1
    -> libz.so.1.3.2
```

and:

```text
libz.so.1.3.1
```

should eventually be recognized as stale.

If the manifest tracked only:

```text
/usr/lib/libz.so.1
```

ownership of:

```text
/usr/lib/libz.so.1.3.1
```

would be lost.

Therefore the project records the complete copied library chain.

---

# 13. SHA256 Conflict Detection

Existing regular files are not silently overwritten.

The resolver compares:

```text
SDK SHA256
RootFS SHA256
```

If they match:

```text
[SKIP]
```

If they differ:

```text
[WARNING] Runtime library conflict
```

and the user is asked whether the runtime file should be overwritten.

Conceptually:

```text
SDK file
    |
    +-- SHA256
          |
          +-- same as rootfs?
                  |
          +-------+-------+
          |               |
         YES              NO
          |               |
        SKIP          WARNING
                          |
                    user decision
```

This avoids silent replacement of runtime libraries.

---

# 14. Why SHA256 Is Used

File size alone is insufficient.

Two libraries can have:

```text
same filename
same size
different contents
```

SHA256 provides a strong content identity check.

The resolver therefore treats matching SHA256 values as identical content and differing values as a conflict requiring explicit handling.

---

# 15. Package/Runtime Ownership Conflict

The `/usr/lib` namespace deserves special care.

Not every file under `/usr/lib` should automatically be assumed to be runtime-owned.

The package manifest therefore acts as a protection layer.

Conceptually:

```text
runtime resolver wants:

/usr/lib/example.so
        |
        v
Is package manifest claiming it?
        |
    +---+---+
    |       |
   YES      NO
    |       |
 ERROR    runtime-owned
```

The runtime resolver must not silently overwrite a package-owned file.

The explicit package ownership check therefore has priority over runtime replacement.

---

# 16. Runtime Manifest Lifecycle

The runtime resolver does not modify the old manifest in place while resolving.

Instead it creates a new manifest:

```text
runtime-libs.manifest.new
```

The sequence is:

```text
old manifest
     |
     | resolve current dependency graph
     v
new manifest
     |
     | compare
     v
stale detection
     |
     v
final runtime-libs.manifest
```

This is important because stale detection requires the complete new dependency set first.

---

# 17. Why Stale Cleanup Must Happen Last

Stale cleanup must happen **after** dependency resolution.

At the beginning:

```text
NEW_MANIFEST = empty
```

If stale cleanup happens immediately, every file in the old manifest appears absent from the new set.

That could incorrectly classify every runtime library as stale.

Correct ordering:

```text
1. Start with old manifest
2. Scan all package ELFs
3. Resolve all dependencies
4. Populate new manifest
5. Sort/unique new manifest
6. Compare old vs new
7. Remove or keep stale files
8. Promote new manifest to current manifest
```

This ordering is fundamental.

---

# 18. Stale Runtime Detection

Suppose the old manifest contains:

```text
/lib/libc.so.6
/lib/libm.so.6
/lib/libold.so.1
```

but the current dependency graph contains:

```text
/lib/libc.so.6
/lib/libm.so.6
```

The set difference is:

```text
/lib/libold.so.1
```

Therefore:

```text
OLD_MANIFEST - NEW_MANIFEST
```

identifies stale runtime-owned files.

The resolver warns before removing them.

Example:

```text
[WARNING] Stale runtime library detected

File:
/lib/libold.so.1

Remove stale runtime file? [y/N]:
```

This prevents silent deletion.

---

# 19. Why Stale Cleanup Is Safe

The resolver only cleans files recorded as previously runtime-owned.

It does not do:

```text
rm -rf rpi_rootfs/lib/*
```

and it does not scan arbitrary configuration directories for deletion.

Deletion is based on historical ownership:

```text
old runtime manifest
        |
        +-- file no longer required
                |
                +-- candidate for removal
```

This is much safer than deleting everything not present in the current SDK.

---

# 20. Configuration Preservation

The root filesystem contains configuration and system state that must not be treated as disposable generated content.

Examples include:

```text
/etc/*
/root/*
/home/*
/var/*
/dev/*
/proc/*
/sys/*
/tmp/*
```

The ownership architecture intentionally avoids treating these paths as package/runtime namespaces.

The package builder does not use an unrestricted "replace everything" strategy.

The runtime resolver similarly works from its dependency graph and runtime manifest.

Configuration therefore remains outside the automated runtime-library ownership mechanism.

---

# 21. Package Manifest Generation

The package builder scans each package's `install` directory.

Conceptually:

```text
packages/
├── busybox/
│   └── install/
├── dropbear/
│   └── install/
└── rt-tests/
    └── install/
```

Each installed file is examined.

For supported package-owned namespaces, its relative path is recorded:

```text
bin/busybox
bin/sh
usr/bin/cyclictest
usr/bin/oslat
usr/sbin/dropbear
```

The manifest is therefore generated from actual package contents.

---

# 22. Why Package Manifest Generation Is Better Than Hardcoding

Hardcoding would require changing the rootfs builder whenever a package adds or removes a file.

Manifest generation instead follows the installation tree.

For example, if `rt-tests` adds:

```text
usr/bin/new-rt-test
```

the builder automatically records:

```text
usr/bin/new-rt-test
```

without requiring an ownership-code change.

---

# 23. RootFS Assembly Model

The overall rootfs assembly now has distinct phases:

```text
Package build
      |
      v
package/install/
      |
      v
Package rootfs installation
      |
      +---- package-files.manifest
      |
      v
ELF scanning
      |
      v
PT_INTERP + DT_NEEDED
      |
      v
Runtime dependency resolution
      |
      +---- runtime-libs.manifest
      |
      v
Stale runtime cleanup
      |
      v
RootFS validation
      |
      v
Filesystem/image generation
```

This separation is important for reproducibility.

---

# 24. Current Runtime Set

At the current project checkpoint, the runtime manifest contains:

```text
/lib/ld-linux-aarch64.so.1
/lib/libatomic.so.1
/lib/libatomic.so.1.2.0
/lib/libc.so.6
/lib/libm.so.6
/lib/libresolv.so.2
/usr/lib/libnuma.so.1
/usr/lib/libnuma.so.1.0.0
/usr/lib/libz.so.1
/usr/lib/libz.so.1.3.1
```

This represents the physical runtime files discovered from the package ELF dependency graph.

The project verified:

```text
libnuma.so.1 -> libnuma.so.1.0.0
libz.so.1    -> libz.so.1.3.1
```

and that the versioned targets exist in the rootfs.

---

# 25. Example: Dropbear

A Dropbear executable can report:

```text
PT_INTERP:
/lib/ld-linux-aarch64.so.1

DT_NEEDED:
libz.so.1
libc.so.6
ld-linux-aarch64.so.1
```

The resolver maps:

```text
libz.so.1
    ->
/usr/lib/libz.so.1
```

and follows its symlink:

```text
/usr/lib/libz.so.1
    ->
/usr/lib/libz.so.1.3.1
```

The runtime manifest therefore records both objects.

---

# 26. Example: BusyBox

BusyBox can report dependencies such as:

```text
DT_NEEDED:
libm.so.6
libresolv.so.2
libc.so.6
ld-linux-aarch64.so.1
```

The resolver maps them into:

```text
/lib/libm.so.6
/lib/libresolv.so.2
/lib/libc.so.6
/lib/ld-linux-aarch64.so.1
```

If another executable requires the same libraries, only one rootfs copy is needed.

---

# 27. Build Reproducibility

The manifests document build state.

Without a manifest, the builder only knows:

```text
"these files happen to exist"
```

With a manifest, it knows:

```text
"these files belong to this build subsystem"
```

That distinction is essential for incremental builds.

A reproducible build should be able to answer:

- What did the package stage install?
- What runtime libraries were required?
- Which runtime files belong to the current dependency graph?
- Which old runtime files can be removed?
- Which existing files were intentionally preserved?

---

# 28. Manifest Is Not the Dependency Database

The runtime manifest should not be confused with the dependency graph.

The dependency graph answers:

```text
Why is this library required?
```

The runtime manifest answers:

```text
Which physical files were installed/owned by runtime resolution?
```

For example:

```text
cyclictest
    |
    +-- libnuma.so.1
           |
           +-- libatomic.so.1
```

is dependency information.

The manifest:

```text
/usr/lib/libnuma.so.1
/usr/lib/libnuma.so.1.0.0
/lib/libatomic.so.1
/lib/libatomic.so.1.2.0
```

is filesystem ownership information.

Both are needed.

---

# 29. Manifest Is Not a General Filesystem Inventory

The manifests do not mean:

```text
"every file in rpi_rootfs is listed here"
```

They mean:

```text
"files belonging to this specific automated ownership domain are listed here"
```

Therefore many rootfs files are expected to be absent from both manifests.

For example:

```text
/etc/inittab
/etc/passwd
/etc/fstab
/dev/*
/proc/*
/sys/*
```

do not need to be package/runtime entries simply because they exist in the root filesystem.

---

# 30. Why This Architecture Matters for the Final `.img`

The eventual goal is a bootable Raspberry Pi image.

The final image should not be assembled by blindly copying the host's root filesystem.

Instead:

```text
SDK
 |
 +-- toolchain
 +-- sysroot
 |
packages
 |
 +-- install trees
 |
 v
rootfs-builder
 |
 +-- package ownership
 +-- runtime dependency resolution
 +-- stale cleanup
 |
 v
rpi_rootfs
 |
 v
rootfs validation
 |
 v
filesystem/archive/partition
 |
 v
bootable .img
```

The manifest mechanism belongs in the reproducible rootfs construction stage, before image creation.

---

# 31. Recommended Metadata Layout

Current:

```text
rpi_rootfs/.metadata/
├── package-files.manifest
└── runtime-libs.manifest
```

Future metadata can be added only when it has clear reproducibility value.

For example:

```text
rpi_rootfs/.metadata/
├── package-files.manifest
├── runtime-libs.manifest
├── build-info
└── rootfs-version
```

Do not turn `.metadata` into a general dumping ground.

---

# 32. Recommended Invariants

The rootfs build system should maintain these invariants.

### Invariant 1

A package-owned file must not be silently overwritten by runtime dependency resolution.

### Invariant 2

A runtime-owned file must be represented in `runtime-libs.manifest`.

### Invariant 3

A versioned library target copied through a symlink must also be tracked.

### Invariant 4

Stale runtime deletion must happen only after the complete new dependency graph has been resolved.

### Invariant 5

A changed existing runtime file must trigger SHA256 comparison and explicit user confirmation.

### Invariant 6

Configuration directories must not be treated as disposable generated content.

### Invariant 7

The current runtime manifest must represent the complete current runtime file set, not only direct dependencies.

---

# 33. Debugging the Manifest

## Package manifest

```bash
cat rpi_rootfs/.metadata/package-files.manifest
```

Count:

```bash
wc -l rpi_rootfs/.metadata/package-files.manifest
```

Verify runtime libraries did not leak into package ownership:

```bash
grep -E '^(lib/|usr/lib/)'     rpi_rootfs/.metadata/package-files.manifest
```

Expected:

```text
no output
```

## Runtime manifest

```bash
cat rpi_rootfs/.metadata/runtime-libs.manifest
```

Count:

```bash
wc -l rpi_rootfs/.metadata/runtime-libs.manifest
```

Find a library:

```bash
grep -Fx '/usr/lib/libz.so.1'     rpi_rootfs/.metadata/runtime-libs.manifest
```

---

# 34. Verifying a Symlink Chain

For:

```text
/usr/lib/libz.so.1
```

check:

```bash
ls -l rpi_rootfs/usr/lib/libz.so.1
```

Then:

```bash
readlink rpi_rootfs/usr/lib/libz.so.1
```

Expected:

```text
libz.so.1.3.1
```

Then:

```bash
test -f rpi_rootfs/usr/lib/libz.so.1.3.1     && echo "libz target OK"
```

The same method applies to `libnuma`.

---

# 35. Verifying ELF Runtime Requirements

After sourcing the project SDK:

```bash
source sdk/environment-setup custom-sdk
```

Check the interpreter:

```bash
aarch64-buildroot-linux-gnu-readelf -l     rpi_rootfs/bin/busybox |
    grep 'Requesting program interpreter'
```

Check direct dependencies:

```bash
aarch64-buildroot-linux-gnu-readelf -d     rpi_rootfs/bin/busybox |
    grep NEEDED
```

The manifest should ultimately contain the physical runtime files needed by these dependencies.

---

# 36. Important Limitation

The manifest proves **filesystem ownership and dependency resolution**.

It does not by itself prove that an ELF binary is executable on the target kernel.

An ARM64 system can have:

```text
correct ELF architecture
correct interpreter path
all libraries present
```

and still fail to execute if the userspace ELF layout is incompatible with the kernel configuration.

Therefore rootfs validation must eventually test:

```text
ELF architecture
PT_INTERP
DT_NEEDED
library presence
library hashes
ELF segment alignment
kernel/userspace page-size compatibility
```

This is particularly important for this project because the target kernel uses a 16 KiB page configuration.

---

# 37. Manifest and RootFS Validation Are Different Stages

The manifest stage answers:

```text
"What files should exist and who owns them?"
```

Rootfs validation answers:

```text
"Can the target system actually use them?"
```

Keep these stages separate:

```text
Manifest correctness
        ↓
RootFS filesystem correctness
        ↓
ELF/runtime compatibility
        ↓
Boot validation
        ↓
Image generation
```

---

# 38. Final Mental Model

```text
                    PACKAGES
                       |
                       v
              package/install trees
                       |
                       v
             +-------------------+
             | rootfs-builder.sh |
             +-------------------+
                       |
                       +----------------------+
                       |                      |
                       v                      v
             package-files.manifest      ELF files
                                              |
                                              v
                                  +-------------------------+
                                  | resolve-runtime-deps.sh |
                                  +-------------------------+
                                              |
                                +-------------+-------------+
                                |                           |
                                v                           v
                           PT_INTERP                    DT_NEEDED
                                |                           |
                                +-------------+-------------+
                                              |
                                              v
                                      recursive graph
                                              |
                                              v
                                    SDK/sysroot lookup
                                              |
                                              v
                                     runtime libraries
                                              |
                                              v
                                  runtime-libs.manifest
                                              |
                                              v
                                     stale detection
                                              |
                                              v
                                        rpi_rootfs
                                              |
                                              v
                                    rootfs validation
                                              |
                                              v
                                        .img file
```

The key idea is:

> **The manifest is the ownership boundary between reproducible generated content and the rest of the root filesystem.**

---

# 39. Current Project Checkpoint

At the current project checkpoint:

```text
Package manifest
    ✓ generated
    ✓ namespace based
    ✓ 448 package-owned entries
    ✓ no lib/ or usr/lib/ runtime entries

Runtime manifest
    ✓ generated
    ✓ recursive dependency resolution
    ✓ PT_INTERP handling
    ✓ DT_NEEDED handling
    ✓ symlink tracking
    ✓ versioned target tracking
    ✓ SHA256 conflict detection
    ✓ stale runtime detection
    ✓ stale runtime confirmation before removal

RootFS
    ✓ package binaries installed
    ✓ runtime libraries installed
    ✓ symlink targets verified
```

The next engineering stage is **rootfs validation and bootability**, followed by filesystem/image generation.
