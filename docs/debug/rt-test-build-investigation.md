# rt-tests Build Investigation: `bld` Directory Failure

## Problem

While building `rt-tests` for the custom AArch64 Buildroot SDK,
compilation succeeded, but `make install` failed with:

``` text
mkdir bld
mkdir: cannot create directory ‘bld’: File exists
make: *** No rule to make target 'bld', needed by 'bld/cyclictest.o'. Stop.
```

The confusing behavior was that deleting `bld/` allowed a build to
start, while keeping `bld/` caused `mkdir: File exists`.

## Build environment

Package:

``` text
packages/rt-tests/
```

Source:

``` text
packages/rt-tests/source/
```

SDK:

``` text
SDK Type       : custom-sdk
Cross Compile  : aarch64-buildroot-linux-gnu-
Compiler       : aarch64-buildroot-linux-gnu-gcc
Sysroot        : /home/dev/Projects/rpi5-custom-embedded-linux-platform/sdk/custom-sdk/aarch64-sdk/aarch64-buildroot-linux-gnu/sysroot
```

Compiler verification succeeded:

``` text
aarch64-buildroot-linux-gnu-gcc.br_real
(Buildroot 2025.05-670-g83947c7bb6)
14.3.0
```

## NUMA investigation

Earlier, `rt-tests` failed with:

``` text
fatal error: numa.h: No such file or directory
```

After `libnuma` was added to the custom SDK/sysroot, the linker
successfully produced commands containing:

``` text
-lrttestnuma -lnuma
```

For example:

``` text
aarch64-buildroot-linux-gnu-gcc ... -o oslat ... -lrttestnuma -lnuma
aarch64-buildroot-linux-gnu-gcc ... -o cyclictest ... -lrttestnuma -lnuma
```

Therefore the NUMA dependency problem was resolved.

## Python installation-path investigation

The Makefile contains:

``` make
DESTDIR ?=
prefix  ?= /usr/local
bindir  ?= $(prefix)/bin
mandir  ?= $(prefix)/share/man

PYLIB ?= $(shell python3 -m get_pylib)
```

The install rules use:

``` make
$(DESTDIR)$(PYLIB)
```

If `PYLIB` resolves to a host SDK path such as:

``` text
/home/dev/.../sdk/custom-sdk/aarch64-sdk/lib/python3.13/site-packages
```

then installation creates an invalid package tree such as:

``` text
install/home/dev/.../sdk/custom-sdk/aarch64-sdk/lib/python3.13/site-packages/
```

That host path will not exist on the Raspberry Pi.

The intended approach is to pass a target-relative path, for example:

``` bash
PYLIB=/usr/lib/python3.13/site-packages
```

with:

``` bash
DESTDIR="$INSTALL_DIR"
```

so the files are staged under:

``` text
$INSTALL_DIR/usr/lib/python3.13/site-packages/
```

The Python version/layout should be verified against the target sysroot
before hardcoding it.

## `bld` investigation

The Makefile defines:

``` make
OBJDIR = bld
```

The object rule is:

``` make
$(OBJDIR)/%.o: %.c | $(OBJDIR)
    $(CC) -D VERSION=$(VERSION) -c $< $(CFLAGS) $(CPPFLAGS) -o $@
```

Therefore:

``` make
bld/%.o: %.c | bld
```

The `| bld` is an **order-only prerequisite**: the `bld` directory must
exist before the object can be built.

The `all` target also requires the directory:

``` make
all: $(TARGETS) hwlatdetect get_cyclictest_snapshot | $(OBJDIR)
```

which becomes:

``` make
all: $(TARGETS) hwlatdetect get_cyclictest_snapshot | bld
```

## Root cause found

The exact directory creation rule was found at lines 131--132:

``` make
$(OBJDIR):
    mkdir $(OBJDIR)
```

Since:

``` make
OBJDIR = bld
```

this becomes:

``` make
bld:
    mkdir bld
```

The problem is that:

``` bash
mkdir bld
```

fails when `bld/` already exists:

``` text
mkdir: cannot create directory ‘bld’: File exists
```

This explains the apparently contradictory behavior:

-   If `bld/` is removed, Make can create it and continue.
-   If `bld/` already exists, the recipe can fail when Make revisits the
    directory target.

The problem is therefore not that `bld/` should always be deleted. The
directory-creation rule itself is not idempotent.

## Correct fix

Change:

``` make
$(OBJDIR):
    mkdir $(OBJDIR)
```

to:

``` make
$(OBJDIR):
    mkdir -p $(OBJDIR)
```

`mkdir -p` is safe in both cases:

``` text
bld does not exist -> create it
bld already exists -> do nothing and return success
```

This makes repeated build/install invocations safe.

## Why `make install` triggered it

The Makefile defines:

``` make
.PHONY: install
install: all install_manpages install_hwlatdetect install_get_cyclictest_snapshot
```

Therefore:

``` bash
make install
```

first invokes:

``` text
all
```

The `all` target contains:

``` make
| $(OBJDIR)
```

so `bld` is part of the dependency chain.

This is why compilation could succeed and the subsequent installation
could still fail while revisiting the build-directory prerequisite.

## Evidence that compilation succeeded

Before the directory failure, the cross compiler successfully linked:

``` text
hackbench
pmqtest
rt-migrate-test
ptsematest
sigwaittest
oslat
pi_stress
cyclicdeadline
deadline_test
cyclictest
```

For example:

``` text
aarch64-buildroot-linux-gnu-gcc ... -o cyclictest ...
```

So the state was:

``` text
SDK                 OK
Cross compiler      OK
Sysroot             OK
NUMA headers        OK
libnuma             OK
Compilation         OK
Linking             OK
Installation        FAILED
```

The warning:

``` text
Makefile:48: libcpupower is missing, building without --deepest-idle-state support.
Makefile:49: Please install libcpupower-dev/kernel-tools-libs-devel
```

was an optional dependency warning, not the cause of the failure.

## Relevant build/install commands

Build:

``` bash
make     CROSS_COMPILE="${CROSS_COMPILE}"     PYLIB=/usr/lib/python3.13/site-packages     -j"$(nproc)"
```

Install:

``` bash
make     CROSS_COMPILE="${CROSS_COMPILE}"     DESTDIR="${INSTALL_DIR}"     prefix=/usr     PYLIB=/usr/lib/python3.13/site-packages     install
```

## Key lessons

### `OBJDIR`

``` make
OBJDIR = bld
```

defines the directory for intermediate build objects:

``` text
bld/cyclictest.o
bld/oslat.o
bld/librttest.a
```

### Order-only prerequisite

``` make
bld/%.o: %.c | bld
```

means:

> Ensure `bld` exists before building the object.

### `mkdir` vs `mkdir -p`

``` bash
mkdir bld
```

fails if `bld` already exists.

``` bash
mkdir -p bld
```

is safe whether or not it exists.

### `DESTDIR`

`DESTDIR` is the package staging root.

For example:

``` text
DESTDIR=/path/to/install
prefix=/usr
```

produces files under:

``` text
/path/to/install/usr/
```

### Target paths vs host paths

A path such as:

``` text
/home/dev/Projects/.../sdk/...
```

belongs to the development host.

A path such as:

``` text
/usr/lib/python3.13/site-packages
```

belongs inside the Raspberry Pi target filesystem.

Package build scripts must not embed host filesystem paths into the
target package.


## 13. Final Installation Verification

After fixing the build-directory and symlink handling, the staged installation was verified successfully.

The resulting installation tree is:

```text
install/
└── usr/
    ├── bin/
    │   ├── cyclicdeadline
    │   ├── cyclictest
    │   ├── deadline_test
    │   ├── determine_maximum_mpps.sh
    │   ├── get_cyclictest_snapshot -> ../lib/python3.13/site-packages/get_cyclictest_snapshot.py
    │   ├── hackbench
    │   ├── hwlatdetect -> ../lib/python3.13/site-packages/hwlatdetect.py
    │   ├── oslat
    │   ├── pi_stress
    │   ├── pip_stress
    │   ├── pmqtest
    │   ├── ptsematest
    │   ├── queuelat
    │   ├── rt-migrate-test
    │   ├── signaltest
    │   ├── sigwaittest
    │   ├── ssdd
    │   └── svsematest
    ├── lib/
    │   └── python3.13/
    │       └── site-packages/
    │           ├── get_cyclictest_snapshot.py
    │           └── hwlatdetect.py
    └── share/
        └── man/
            └── man8/
                ├── cyclicdeadline.8
                ├── cyclictest.8
                ├── deadline_test.8
                ├── determine_maximum_mpps.8
                ├── get_cyclictest_snapshot.8
                ├── hackbench.8
                ├── hwlatdetect.8
                ├── oslat.8
                ├── pi_stress.8
                ├── pip_stress.8
                ├── pmqtest.8
                ├── ptsematest.8
                ├── queuelat.8
                ├── rt-migrate-test.8
                ├── signaltest.8
                ├── sigwaittest.8
                ├── ssdd.8
                └── svsematest.8
```

### Verification results

The staging tree contains:

- 18 executable test/tools under `usr/bin`
- 2 Python helper scripts under `usr/lib/python3.13/site-packages`
- 2 target-relative Python symlinks
- 18 man pages
- no host `/home/dev/...` path embedded in the installed Python symlinks

The Python symlinks are correctly target-relative:

```text
/usr/bin/hwlatdetect
    -> ../lib/python3.13/site-packages/hwlatdetect.py

/usr/bin/get_cyclictest_snapshot
    -> ../lib/python3.13/site-packages/get_cyclictest_snapshot.py
```

This confirms that the `DESTDIR` and explicit target `PYLIB` installation approach produces a target filesystem layout suitable for inclusion in the Raspberry Pi root filesystem.

### Current status

```text
Cross compilation        PASS
NUMA support             PASS
Build directory handling PASS
Repeated symlink handling PASS
Python staging            PASS
Man-page staging          PASS
Target install tree       PASS
```

### Remaining architectural improvement

The upstream `rt-tests` Makefile still builds generated binaries and `bld/` inside the source directory. The package layout is intended to eventually separate:

```text
source/   -> upstream source only
build/    -> generated build artifacts
install/  -> target staging tree
```

This is a separate out-of-tree-build improvement and should not be confused with the already verified installation fixes.
