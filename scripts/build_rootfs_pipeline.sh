#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK_NAME="${SDK_NAME:-custom-sdk}"
SDK_SETUP="$PROJECT_ROOT/sdk/environment-setup"

ROOTFS="$PROJECT_ROOT/rpi_rootfs"
PACKAGES="$PROJECT_ROOT/packages"

step() {
    echo
    echo "============================================================"
    echo " $*"
    echo "============================================================"
    echo
}

die() {
    echo "[ERROR] $*" >&2
    exit 1
}

run() {
    echo "+ $*"
    "$@"
}

# ============================================================
# Required project files
# ============================================================

[[ -f "$SDK_SETUP" ]] ||
    die "SDK environment setup not found: $SDK_SETUP"

[[ -x "$PACKAGES/busybox/build.sh" ]] ||
    die "BusyBox build.sh not found/executable"

[[ -x "$PACKAGES/dropbear-2026.91/build.sh" ]] ||
    die "Dropbear build.sh not found/executable"

[[ -x "$PACKAGES/rt-tests/build.sh" ]] ||
    die "rt-tests build.sh not found/executable"

[[ -x "$PROJECT_ROOT/scripts/rootfs_safe_clean.sh" ]] ||
    die "rootfs_safe_clean.sh not found/executable"

[[ -x "$PROJECT_ROOT/scripts/rootfs-builder.sh" ]] ||
    die "rootfs-builder.sh not found/executable"

[[ -x "$PROJECT_ROOT/scripts/resolve-runtime-deps.sh" ]] ||
    die "resolve-runtime-deps.sh not found/executable"

[[ -x "$PROJECT_ROOT/scripts/mount_rootfs_zip.sh" ]] ||
    die "mount_rootfs_zip.sh not found/executable"

mkdir -p "$ROOTFS"
cd "$PROJECT_ROOT"

# ============================================================
# 1. Prepare SDK FIRST
# ============================================================

step "[1/9] Preparing SDK environment"

# shellcheck disable=SC1090
source "$SDK_SETUP" "$SDK_NAME"

: "${SYSROOT:?SYSROOT was not exported by environment-setup}"
: "${CROSS_COMPILE:?CROSS_COMPILE was not exported by environment-setup}"

[[ -d "$SYSROOT" ]] ||
    die "SYSROOT does not exist: $SYSROOT"

echo "SDK Name       : $SDK_NAME"
echo "SYSROOT        : $SYSROOT"
echo "CROSS_COMPILE  : $CROSS_COMPILE"


# ============================================================
# 2. Build BusyBox
# ============================================================

step "[2/9] Building BusyBox"

run "$PACKAGES/busybox/build.sh" "$SDK_NAME"

# ============================================================
# 3. Check target SDK page-size information BEFORE builds
# ============================================================

step "[3/9] Checking target SDK page-size configuration"
echo "Target compiler:"
"${CROSS_COMPILE}gcc" --version | head -n 1

echo
echo "============================================================"
echo " SDK ELF Page-Size / LOAD Alignment"
echo "============================================================"

LIBC="$SYSROOT/lib/libc.so.6"
LD="$SYSROOT/lib/ld-linux-aarch64.so.1"

if [[ ! -f "$LIBC" ]]; then
    echo "[ERROR] SDK libc not found:"
    echo "        $LIBC"
    exit 1
fi

if [[ ! -f "$LD" ]]; then
    echo "[ERROR] SDK dynamic loader not found:"
    echo "        $LD"
    exit 1
fi

echo
echo "[libc]"
echo "$LIBC"

"${CROSS_COMPILE}readelf" -l "$LIBC" |
    grep -A1 'LOAD'

echo
echo "[dynamic loader]"
echo "$LD"

"${CROSS_COMPILE}readelf" -l "$LD" |
    grep -A1 'LOAD'

echo
echo "Interpretation:"
echo "  0x1000   = 4 KB"
echo "  0x4000   = 16 KB"
echo "  0x10000  = 64 KB"

echo
echo "[INFO] SDK page-size compatibility is determined from ELF LOAD alignment."



# ============================================================
# 4. Build Dropbear
# ============================================================

step "[4/9] Building Dropbear"

run "$PACKAGES/dropbear-2026.91/build.sh" "$SDK_NAME"

# ============================================================
# 5. Build rt-tests
# ============================================================

step "[5/9] Building rt-tests"

run "$PACKAGES/rt-tests/build.sh" "$SDK_NAME"

# ============================================================
# 6. Safe rootfs cleanup
# ============================================================
ROOTFS="$PROJECT_ROOT/rpi_rootfs"

step "[6/9] Safe rootfs cleanup"

run "$PROJECT_ROOT/scripts/rootfs_safe_clean.sh" "$ROOTFS"

# Remove stale linuxrc exactly as requested.
echo
echo "[REMOVE] $ROOTFS/linuxrc"
rm -f "$ROOTFS/linuxrc"

# ============================================================
# 7. Build rootfs
# ============================================================

step "[7/9] Building rootfs"

run "$PROJECT_ROOT/scripts/rootfs-builder.sh" \
    "$PACKAGES" \
    "$ROOTFS"

# ============================================================
# 8. Resolve runtime dependencies
# ============================================================

step "[8/9] Resolving runtime dependencies"

# SDK environment is already sourced above.
# Resolver receives PACKAGES + ROOTFS only.
run "$PROJECT_ROOT/scripts/resolve-runtime-deps.sh" \
    "$PACKAGES" \
    "$ROOTFS"

# ============================================================
# 9. Create rpi_bootfs / rootfs.cpio.gz
# ============================================================

step "[9/9] Creating rpi_bootfs"

run "$PROJECT_ROOT/scripts/mount_rootfs_zip.sh"

# ============================================================
# Final summary
# ============================================================

echo
echo "============================================================"
echo " PIPELINE COMPLETE"
echo "============================================================"
echo
echo "Rootfs:"
echo "  $ROOTFS"
echo
echo "Bootfs:"
echo "  $PROJECT_ROOT/rpi_bootfs"
echo

if [[ -f "$PROJECT_ROOT/rpi_bootfs/rootfs.cpio.gz" ]]; then
    ls -lh "$PROJECT_ROOT/rpi_bootfs/rootfs.cpio.gz"
fi

echo
echo "All requested steps completed successfully."
