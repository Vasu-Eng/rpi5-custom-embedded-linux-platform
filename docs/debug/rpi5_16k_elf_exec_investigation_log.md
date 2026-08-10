# Raspberry Pi 5 Embedded Linux BSP — 16-KiB Page Size / ELF Execution Investigation

> **Investigation status:** ELF loader path traced; root cause not yet conclusively proven.
>
> This document records the investigation into the userspace startup failure on the custom Raspberry Pi 5 BSP. It is intentionally written as an engineering investigation log: observations, source-level evidence, proven facts, hypotheses, and the next controlled experiment are separated.

Raspberry Pi 5 Embedded Linux BSP
16-KiB Page Size / ELF Execution Investigation
Investigation Log — Kernel ELF Loader, PT_LOAD Alignment, glibc Runtime and Buildroot Toolchain
## 1. Executive Summary
This investigation started from a boot failure on a custom Raspberry Pi 5 Linux image. The 16-KiB ARM64 kernel successfully initialized major hardware and reached userspace, but /init ultimately failed while /bin/sh was being loaded, after which PID 1 exited and the kernel panicked. The initial hypothesis was that a 16-KiB kernel could not execute a BusyBox ELF whose PT_LOAD segments advertised 4-KiB alignment.
Rather than changing the ELF immediately, the Linux ELF loader was traced from architecture definitions through fs/binfmt_elf.c. The investigation established that ARM64 defines ELF_EXEC_PAGESIZE as PAGE_SIZE; the generic ELF loader derives ELF_MIN_ALIGN from that value, normalizes PT_LOAD alignment through ELF_PAGEALIGN(), and aligns the ET_DYN load_bias accordingly. Therefore BusyBox p_align=0x1000 alone is not proof of incompatibility.
A second, stronger system-level finding was then made: the kernel is configured for 16-KiB pages, while the Buildroot AArch64/glibc toolchain is configured for BR2_ARM64_PAGE_SIZE_4K. Buildroot explicitly supports BR2_ARM64_PAGE_SIZE_16K. A controlled rebuild of the toolchain/sysroot and all ELF packages for 16 KiB is therefore the next engineering experiment.
| Item | Value |
|---|---|
| Target | Raspberry Pi 5 Model B Rev 1.1 |
| Architecture | AArch64 / ARM64 |
| Kernel | Linux 6.18.36-v8-16k+ |
| Kernel page size | 16 KiB |
| Userspace shell | /bin/sh -> BusyBox |
| Toolchain | Buildroot internal AArch64 toolchain, glibc |
| Current Buildroot page size | 4 KiB |
| Failure | /bin/sh dynamic-loading error; PID 1 exits; kernel panics |

## 2. Platform and Failure Context
## 3. Original Boot Evidence
```text
[    0.702409] ... ttyAMA0 ...
[    0.702454] printk: console [ttyAMA0] enabled
[    0.711708] [drm] Initialized ili9341 1.0.0 for spi0.0 on minor 0
[    6.021881] ili9341 spi0.0: [drm] fb0: ili9341drmfb frame buffer device
[    6.046058] Run /init as init process
/bin/sh: error while loading shar...
[    6.054218] Kernel panic - not syncing: Attempted to kill ini0
...
[    6.130949] SMP: stopping secondary CPUs
[    7.193881] SMP: failed to stop secondary CPUs 0
[    7.211619] ---[ end Kernel panic - not syncing: Attempted to kill init! exitcode=0x00007f00 ]---
```
The sequencing matters. Hardware initialization completed and the kernel reached the point of invoking /init. The visible userspace error is associated with /bin/sh/dynamic loading. The final panic is the consequence of PID 1 exiting; the SMP stop messages occur during panic handling and are not evidence of the original fault.
## 4. RootFS ELF and Runtime Evidence
```text
$ ls -l rpi_rootfs/bin/sh
lrwxrwxrwx ... rpi_rootfs/bin/sh -> busybox

$ readlink -f rpi_rootfs/bin/sh
.../rpi_rootfs/bin/busybox
$ aarch64-buildroot-linux-gnu-readelf -l rpi_rootfs/bin/busybox |
    grep 'Requesting program interpreter'
[Requesting program interpreter: /lib/ld-linux-aarch64.so.1]
$ aarch64-buildroot-linux-gnu-readelf -d rpi_rootfs/bin/busybox | grep NEEDED
NEEDED  Shared library: [libm.so.6]
NEEDED  Shared library: [libresolv.so.2]
NEEDED  Shared library: [libc.so.6]
NEEDED  Shared library: [ld-linux-aarch64.so.1]
```
The requested dynamic linker and libraries existed in the rootfs. However, file existence is not enough to prove ABI compatibility; provenance and build configuration also matter.
## 5. BusyBox ELF Program Headers
```text
Elf file type is DYN (Position-Independent Executable file)
Entry point 0xff40
There are 9 program headers
INTERP
[Requesting program interpreter: /lib/ld-linux-aarch64.so.1]

LOAD
VirtAddr 0x0000000000000000
FileSiz  0x0000000000110d64
MemSiz   0x0000000000110d64
Flags    R E
Align    0x1000

LOAD
VirtAddr 0x00000000001110a0
FileSiz  0x00000000000041c9
MemSiz   0x0000000000004898
Flags    RW
Align    0x1000
```
The ELF is ET_DYN/PIE, contains PT_INTERP, and both PT_LOAD segments advertise p_align=0x1000. This is the key ELF-level observation, but it must be interpreted through the kernel loader.
## 6. Kernel Page-Size Configuration
```text
$ grep -E 'CONFIG_ARM64_(4K|16K|64K)_PAGES' .config
# CONFIG_ARM64_4K_PAGES is not set
CONFIG_ARM64_16K_PAGES=y
# CONFIG_ARM64_64K_PAGES is not set

$ grep -R "PAGE_SIZE" .config
CONFIG_HAVE_PAGE_SIZE_16KB=y
CONFIG_PAGE_SIZE_16KB=y
CONFIG_PAGE_SIZE_LESS_THAN_64KB=y
CONFIG_PAGE_SIZE_LESS_THAN_256KB=y
```
The target kernel is therefore unambiguously a 16-KiB-page ARM64 kernel.
## 7. Architecture ELF Definition
arch/arm64/include/asm/elf.h

#define ELF_EXEC_PAGESIZE PAGE_SIZE
This directly connects the ARM64 ELF execution page size to the kernel PAGE_SIZE. For this build, PAGE_SIZE is 0x4000.
## 8. Generic ELF Loader: Minimum Alignment
fs/binfmt_elf.c

#if ELF_EXEC_PAGESIZE > PAGE_SIZE
#define ELF_MIN_ALIGN ELF_EXEC_PAGESIZE
#else
#define ELF_MIN_ALIGN PAGE_SIZE
#endif

#define ELF_PAGESTART(_v) ((_v) & ~(int)(ELF_MIN_ALIGN-1))
#define ELF_PAGEOFFSET(_v) ((_v) & (ELF_MIN_ALIGN-1))
#define ELF_PAGEALIGN(_v) (((_v) + ELF_MIN_ALIGN - 1) & ~(ELF_MIN_ALIGN - 1))
For this kernel ELF_MIN_ALIGN is effectively 0x4000. Thus ELF_PAGESTART, ELF_PAGEOFFSET and ELF_PAGEALIGN operate at 16-KiB granularity.
## 9. PT_LOAD Mapping
```text
static unsigned long elf_map(...)
{
    unsigned long size =
        eppnt->p_filesz + ELF_PAGEOFFSET(eppnt->p_vaddr);
    unsigned long off =
        eppnt->p_offset - ELF_PAGEOFFSET(eppnt->p_vaddr);

    addr = ELF_PAGESTART(addr);
    size = ELF_PAGEALIGN(size);

    ...
    map_addr = vm_mmap(...);
}
```
This shows that segment mapping is normalized through the kernel's page-alignment macros rather than blindly using the raw p_align field as the mapping granularity.
## 10. maximum_alignment(): The 4K-to-16K Normalization
```text
static unsigned long maximum_alignment(struct elf_phdr *cmds, int nr)
{
    unsigned long alignment = 0;
    int i;

    for (i = 0; i < nr; i++) {
        if (cmds[i].p_type == PT_LOAD) {
            unsigned long p_align = cmds[i].p_align;

            if (!is_power_of_2(p_align))
                continue;

            alignment = max(alignment, p_align);
        }
    }

    return ELF_PAGEALIGN(alignment);
}
BusyBox:
    PT_LOAD p_align = 0x1000

Kernel:
    ELF_MIN_ALIGN = 0x4000

maximum_alignment():
    max p_align = 0x1000
             -> ELF_PAGEALIGN()
             -> 0x4000
```
This is a critical finding. The kernel takes the maximum PT_LOAD p_align but then rounds it through ELF_PAGEALIGN(). On the investigated kernel, the minimum result is 16 KiB.
## 11. ET_DYN / PIE Load-Bias Handling
fs/binfmt_elf.c around the ET_DYN path:

total_size = total_mapping_size(elf_phdata, elf_ex->e_phnum);
alignment = maximum_alignment(elf_phdata, elf_ex->e_phnum);

if (interpreter) {
    load_bias = ELF_ET_DYN_BASE;

    if (current->flags & PF_RANDOMIZE)
        load_bias += arch_mmap_rnd();

    if (alignment)
        load_bias &= ~(alignment - 1);

    elf_flags |= MAP_FIXED_NOREPLACE;
}
Because BusyBox is ET_DYN and has PT_INTERP, this branch applies. With alignment normalized to 0x4000, load_bias is explicitly rounded to a 16-KiB boundary.
```text
load_bias = ELF_PAGESTART(load_bias - vaddr);

error = elf_load(bprm->file,
                 load_bias + vaddr,
                 elf_ppnt,
                 elf_prot,
                 elf_flags,
                 total_size);
```
The resulting load_bias is then page-aligned again before elf_load(). The source path continues through elf_load(), elf_map() and ultimately vm_mmap().
## 12. Source-Level Execution Path
```text
BusyBox
  |
  | ET_DYN + PT_INTERP
  | PT_LOAD p_align = 0x1000
  v
maximum_alignment()
  |
  | ELF_PAGEALIGN()
  v
alignment = 0x4000
  |
  v
ET_DYN ASLR / load_bias
  |
  | round down to alignment
  v
ELF_PAGESTART()
  |
  v
elf_load()
  |
  v
elf_map()
  |
  v
vm_mmap()
```
## 13. Proven Facts vs. Hypotheses
PROVEN:
- The kernel is configured for 16-KiB pages.
- BusyBox is ET_DYN/PIE with PT_INTERP.
- BusyBox requests /lib/ld-linux-aarch64.so.1.
- BusyBox PT_LOAD p_align is 0x1000.
- ARM64 defines ELF_EXEC_PAGESIZE as PAGE_SIZE.
- fs/binfmt_elf.c derives ELF_MIN_ALIGN from the kernel page size.
- maximum_alignment() normalizes PT_LOAD alignment through ELF_PAGEALIGN().
- ET_DYN load_bias is explicitly aligned using the computed alignment.
- PID 1 exits and the kernel panics because init exits.
NOT PROVEN:
- That p_align=0x1000 is the root cause.
- That libc.so.6 is incompatible with the 16-KiB kernel.
- That the dynamic linker was built for a 4-KiB-only runtime.
- That any particular DT_NEEDED library caused the failure.
- That rebuilding BusyBox alone will fix the boot failure.
## 14. Buildroot Toolchain Investigation
Buildroot configuration:

BR2_ARCH="aarch64"
BR2_USE_MMU=y
BR2_TOOLCHAIN_BUILDROOT=y
BR2_TOOLCHAIN_BUILDROOT_GLIBC=y
BR2_TOOLCHAIN_BUILDROOT_LIBC="glibc"
BR2_TOOLCHAIN_SUPPORTS_PIE=y
The Buildroot source tree contains explicit AArch64 page-size options in arch/Config.in.arm:
```text
BR2_ARM64_PAGE_SIZE_4K
BR2_ARM64_PAGE_SIZE_16K
BR2_ARM64_PAGE_SIZE_64K
```
The current Buildroot configuration is:
```text
BR2_ARM64_PAGE_SIZE_4K=y
BR2_ARM64_PAGE_SIZE="4K"
```
This creates a concrete configuration mismatch: kernel PAGE_SIZE=16K versus Buildroot toolchain page-size selection=4K. It does not, by itself, prove the original crash, but it is a legitimate platform-consistency issue and a strong candidate for controlled investigation.
## 15. Runtime Dependency / RootFS Architecture
```text
rpi_rootfs/.metadata/runtime-libs.manifest

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
The custom build system separates package-owned files from runtime libraries discovered through ELF PT_INTERP and DT_NEEDED. This is valuable for BSP reproducibility because runtime files can be reconciled from manifests while configuration directories are preserved. Runtime library existence and ownership are tracked independently from package binaries.
## 16. Why the Next Experiment Should Be a 16-KiB Toolchain
The technically clean experiment is to use Buildroot's native AArch64 page-size option instead of manually editing ELF binaries or replacing individual libraries. Configure:
Kernel:
    CONFIG_ARM64_16K_PAGES=y
    CONFIG_PAGE_SIZE_16KB=y

Buildroot:
    BR2_ARM64_PAGE_SIZE_16K=y
    BR2_ARM64_PAGE_SIZE="16K"

Then rebuild:
    Buildroot toolchain / glibc / sysroot
    BusyBox
    Dropbear
    rt-tests
    other dynamically linked packages
The goal is a single provenance chain: compiler + headers + glibc + dynamic linker + libraries + applications are generated as one consistent 16-KiB target userspace.
## 17. Controlled Validation Plan
1. Save the current Buildroot .config and record the toolchain/glibc versions.
1. Switch only BR2_ARM64_PAGE_SIZE from 4K to 16K.
1. Perform an appropriate clean toolchain rebuild so stale 4K artifacts cannot survive.
1. Regenerate the SDK/sysroot.
1. Rebuild every custom ELF package against the new sysroot.
1. Clear/reconcile only package-owned and runtime-owned rootfs areas; preserve configuration directories.
1. Rebuild rpi_rootfs and the bootable cpio archive.
1. Verify PT_INTERP for every dynamic ELF.
1. Verify DT_NEEDED dependencies resolve against the new rootfs.
1. Compare hashes/provenance of loader and libc between sysroot and rootfs.
1. Boot and capture the complete /bin/sh error without truncation.
1. If the failure remains, investigate the dynamic loader, libc runtime behavior, mmap failures and individual dependencies.
## 18. Engineering Significance
For a product-based BSP/platform team, the important evidence is not merely the symptom. The investigation demonstrates a reproducible chain from hardware/kernel configuration to ELF metadata, kernel source behavior, toolchain configuration and runtime assembly.
- Symptom was captured before modification.
- Kernel panic was separated from the preceding userspace failure.
- ELF type, PT_INTERP, PT_LOAD and DT_NEEDED were inspected.
- Kernel source was traced to the actual ELF loader implementation.
- Architecture-specific ELF_EXEC_PAGESIZE was identified.
- PT_LOAD alignment handling was traced through maximum_alignment().
- ET_DYN load_bias handling was traced to the mapping path.
- Toolchain page-size configuration was compared against kernel configuration.
- Facts were explicitly separated from hypotheses.
- The next experiment changes the platform configuration systematically instead of applying an ad-hoc binary patch.
## 19. Current Conclusion
The current evidence does not support claiming that a 4-KiB PT_LOAD p_align is inherently incompatible with a 16-KiB ARM64 kernel. The Linux source inspected here explicitly normalizes ELF alignment to the kernel's minimum alignment and aligns ET_DYN load_bias accordingly.
However, the Buildroot configuration reveals a concrete mismatch: the running kernel uses 16-KiB pages while the AArch64/glibc Buildroot toolchain is configured for 4 KiB. Because Buildroot explicitly supports BR2_ARM64_PAGE_SIZE_16K, rebuilding the toolchain, sysroot and packages as a coherent 16-KiB userspace is the correct next controlled experiment.
Importantly, the root cause should be considered unresolved until that experiment is performed and the complete dynamic-loader error is captured. The investigation should continue from evidence rather than assuming that the first visible ELF difference is the cause.
## Appendix — Reproduction Commands
# Kernel configuration
grep -E 'CONFIG_ARM64_(4K|16K|64K)_PAGES' .config
grep -R "PAGE_SIZE" .config

# BusyBox ELF
aarch64-buildroot-linux-gnu-readelf -l rpi_rootfs/bin/busybox
aarch64-buildroot-linux-gnu-readelf -d rpi_rootfs/bin/busybox

# Kernel source
grep -nE 'ELF_EXEC_PAGESIZE|p_align|ELF_PAGE|PAGE_ALIGN' fs/binfmt_elf.c
sed -n '70,110p' fs/binfmt_elf.c
sed -n '350,465p' fs/binfmt_elf.c
sed -n '465,515p' fs/binfmt_elf.c
grep -n "maximum_alignment(" fs/binfmt_elf.c
sed -n '1070,1140p' fs/binfmt_elf.c
sed -n '1135,1235p' fs/binfmt_elf.c

# Buildroot page-size configuration
grep -RniE '16.?KB|16.?K|PAGE_SIZE|pagesize|page size' Config.in arch package toolchain 2>/dev/null | head -100
grep -E '^BR2_ARM64_PAGE_SIZE' .config
Investigation status: ELF loader path traced; root cause not yet conclusively proven.