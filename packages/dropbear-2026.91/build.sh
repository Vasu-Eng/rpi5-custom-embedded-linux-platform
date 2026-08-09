#!/usr/bin/env bash

set -e


# ============================================================
# Dropbear Build Script
#
# Usage:
#
#   ./build.sh custom-sdk
#   ./build.sh official-sdk
#
# Clean:
#
#   ./build.sh custom-sdk clean
#   ./build.sh official-sdk clean
#
# ============================================================


# ============================================================
# Project Paths
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"


# ============================================================
# Arguments
# ============================================================

SDK_TYPE="${1:-}"
ACTION="${2:-build}"


# ============================================================
# Validate SDK Argument
# ============================================================

if [ -z "$SDK_TYPE" ]; then

    echo
    echo "[ERROR] SDK not specified."
    echo
    echo "Usage:"
    echo
    echo "  ./build.sh custom-sdk"
    echo "  ./build.sh official-sdk"
    echo
    echo "Clean:"
    echo
    echo "  ./build.sh custom-sdk clean"
    echo "  ./build.sh official-sdk clean"
    echo

    exit 1

fi


# ============================================================
# SDK Selection
# ============================================================

case "$SDK_TYPE" in

    custom-sdk)
         
        SDK_ROOT="${PROJECT_ROOT}/sdk/custom-sdk"

        SDK_TARBALL="${SDK_ROOT}/buildroot-toolchains/output/images/aarch64-buildroot-linux-gnu_sdk-buildroot.tar.gz"
      
        ;;

    official-sdk)

        SDK_ROOT="${PROJECT_ROOT}/sdk/official-sdk"

        SDK_TARBALL="${SDK_ROOT}/aarch64-buildroot-linux-gnu_sdk-buildroot.tar.gz"

        ;;

    *)

        echo
        echo "[ERROR] Invalid SDK: $SDK_TYPE"
        echo
        echo "Valid SDK options:"
        echo
        echo "  custom-sdk"
        echo "  official-sdk"
        echo

        exit 1

        ;;

esac


# ============================================================
# SDK Paths
# ============================================================

SDK_DIR="${SDK_ROOT}/aarch64-sdk"

SDK_SHA="${SDK_DIR}/.sdk-sha256"


# ============================================================
# Package Paths
# ============================================================

SOURCE_DIR="${SCRIPT_DIR}/source"

BUILD_DIR="${SCRIPT_DIR}/build"

INSTALL_DIR="${SCRIPT_DIR}/install"


# ============================================================
# Clean
# ============================================================

if [ "$ACTION" = "clean" ]; then

    echo
    echo "============================================================"
    echo " Cleaning Dropbear"
    echo "============================================================"
    echo

    rm -rf "$BUILD_DIR"
    rm -rf "$INSTALL_DIR"

    echo "[OK] Build directory removed:"
    echo "     $BUILD_DIR"

    echo
    echo "[OK] Install directory removed:"
    echo "     $INSTALL_DIR"

    echo
    echo "[INFO] SDK was NOT removed."
    echo

    exit 0

fi


# ============================================================
# Validate Action
# ============================================================

if [ "$ACTION" != "build" ]; then

    echo
    echo "[ERROR] Invalid action: $ACTION"
    echo
    echo "Valid actions:"
    echo
    echo "  build"
    echo "  clean"
    echo

    exit 1

fi

# ============================================================
# Check for latest sdk 
# ============================================================

if [ "$SDK_TYPE" = "custom-sdk" ]; then
       
  source   "$PROJECT_ROOT/scripts/prepare-sdk.sh"     
  prepare_sdk
  
fi

# ============================================================
# Load Common Project Environment
# ============================================================

echo
echo "============================================================"
echo " Loading Project Environment"
echo "============================================================"
echo


source "$PROJECT_ROOT/sdk/environment-setup" "$SDK_TYPE"


# ============================================================
# Display Toolchain Information
# ============================================================

echo
echo "============================================================"
echo " Toolchain"
echo "============================================================"
echo
echo " SDK Type      : $SDK_TYPE"
echo " SDK Root      : $SDK_ROOT"
echo " CC            : $CC"
echo " SYSROOT       : $SYSROOT"
echo " CROSS_COMPILE : $CROSS_COMPILE"
echo
echo "============================================================"
echo


# ============================================================
# Verify Compiler
# ============================================================

if ! command -v "$CC" >/dev/null 2>&1; then

    echo
    echo "[ERROR] Cross compiler not found:"
    echo
    echo "  $CC"
    echo

    exit 1

fi


# ============================================================
# Verify Target
# ============================================================

echo "[INFO] Target architecture:"

"$CC" -dumpmachine

echo


# ============================================================
# Verify Sysroot
# ============================================================

if [ ! -d "$SYSROOT" ]; then

    echo
    echo "[ERROR] SYSROOT does not exist:"
    echo
    echo "  $SYSROOT"
    echo

    exit 1

fi


echo "[OK] SYSROOT exists:"
echo "     $SYSROOT"
echo


# ============================================================
# Check Zlib
# ============================================================

echo "[INFO] Checking zlib in SDK..."


if [ -f "$SYSROOT/usr/include/zlib.h" ]; then

    echo "[OK] zlib.h found:"
    echo "     $SYSROOT/usr/include/zlib.h"

else

    echo "[INFO] zlib.h not found."

fi


if [ -f "$SYSROOT/usr/lib/libz.so" ]; then

    echo "[OK] libz.so found:"
    echo "     $SYSROOT/usr/lib/libz.so"

else

    echo "[INFO] libz.so not found."

fi


echo


# ============================================================
# Create Package Directories
# ============================================================

mkdir -p "$BUILD_DIR"
mkdir -p "$INSTALL_DIR"


# ============================================================
# Configure Dropbear
# ============================================================

cd "$BUILD_DIR"


echo
echo "============================================================"
echo " Configuring Dropbear"
echo "============================================================"
echo


"$SOURCE_DIR/configure" \
    --host=aarch64-buildroot-linux-gnu \
    --prefix=/usr


# ============================================================
# Build Dropbear
# ============================================================

PROGRAMS="dropbear dbclient dropbearkey dropbearconvert"
MULTI="1"
SCPPROGRESS="1"


echo
echo "============================================================"
echo " Building Dropbear"
echo "============================================================"
echo




make -B \
    PROGRAMS="${PROGRAMS}" \
    MULTI="${MULTI}" \
    SCPPROGRESS="${SCPPROGRESS}" \
    -j"$(nproc)"


# ============================================================
# Install Dropbear
# ============================================================

echo
echo "============================================================"
echo " Installing Dropbear"
echo "============================================================"
echo


make \
    PROGRAMS="${PROGRAMS}"  \
    MULTI="${MULTI}" \
    SCPPROGRESS="${SCPPROGRESS}" \
    DESTDIR="${INSTALL_DIR}" \
    install


# ============================================================
# Build Complete
# ============================================================

echo
echo "============================================================"
echo " Dropbear Build Completed"
echo "============================================================"
echo
echo " SDK       : $SDK_TYPE"
echo " SYSROOT   : $SYSROOT"
echo " OUTPUT    : $INSTALL_DIR"
echo
echo "============================================================"
echo
