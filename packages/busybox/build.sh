#!/usr/bin/env bash

set -e


# ============================================================
# BusyBox Build Script
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
# ============================================================


# ============================================================
# Paths
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

SOURCE_DIR="${SCRIPT_DIR}/source"
BUILD_DIR="${SCRIPT_DIR}/build"
INSTALL_DIR="${SCRIPT_DIR}/install"


# ============================================================
# Arguments
# ============================================================

SDK_TYPE="${1:-}"
ACTION="${2:-build}"


# ============================================================
# Validate SDK
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


case "$SDK_TYPE" in

    custom-sdk|official-sdk)
        ;;

    *)
        echo
        echo "[ERROR] Invalid SDK: $SDK_TYPE"
        echo
        echo "Valid options:"
        echo "  custom-sdk"
        echo "  official-sdk"
        echo

        exit 1
        ;;

esac


# ============================================================
# Clean
# ============================================================

if [ "$ACTION" = "clean" ]; then

    echo
    echo "============================================================"
    echo " Cleaning BusyBox"
    echo "============================================================"
    echo

    rm -rf "$BUILD_DIR"
    rm -rf "$INSTALL_DIR"

    echo "[OK] Build and install directories removed."
    echo

    exit 0

fi


if [ "$ACTION" != "build" ]; then

    echo
    echo "[ERROR] Invalid action: $ACTION"
    echo
    echo "Valid actions:"
    echo "  build"
    echo "  clean"
    echo

    exit 1

fi


# ============================================================
# Load SDK Environment
# ============================================================

echo
echo "============================================================"
echo " Loading SDK"
echo "============================================================"
echo

source "$PROJECT_ROOT/sdk/environment-setup" "$SDK_TYPE"


echo "SDK       : $SDK_TYPE"
echo "CC        : $CC"
echo "SYSROOT   : $SYSROOT"
echo "CROSS     : $CROSS_COMPILE"
echo


# ============================================================
# Verify Compiler
# ============================================================

if ! command -v "$CC" >/dev/null 2>&1; then

    echo
    echo "[ERROR] Cross compiler not found:"
    echo "        $CC"
    echo

    exit 1

fi


echo "[OK] Compiler:"
"$CC" --version | head -1
echo


# ============================================================
# Verify Source
# ============================================================

if [ ! -f "$SOURCE_DIR/Makefile" ]; then

    echo
    echo "[ERROR] BusyBox source not found:"
    echo "        $SOURCE_DIR"
    echo

    exit 1

fi


# ============================================================
# Create Build / Install Directories
# ============================================================

mkdir -p "$BUILD_DIR"
mkdir -p "$INSTALL_DIR"


# ============================================================
# Configure / Prepare BusyBox
# ============================================================

echo
echo "============================================================"
echo " Preparing BusyBox"
echo "============================================================"
echo


cd "$SOURCE_DIR"


# ------------------------------------------------------------
# Use existing BusyBox configuration
# ------------------------------------------------------------

if [ -f ".config" ]; then

    echo "[INFO] Existing BusyBox .config found."

else

    echo "[ERROR] BusyBox .config not found."
    echo
    echo "Create/configure BusyBox first using:"
    echo
    echo "  make menuconfig"
    echo
    echo "or provide a defconfig."
    echo

    exit 1

fi


# ============================================================
# Apply SDK Toolchain
# ============================================================

echo
echo "============================================================"
echo " Configuring Toolchain"
echo "============================================================"
echo


make defconfig


# ============================================================
# Build BusyBox
# ============================================================

echo
echo "============================================================"
echo " Building BusyBox"
echo "============================================================"
echo

make \
    ARCH=arm64 \
    CROSS_COMPILE="${CROSS_COMPILE}" \
    -j"$(nproc)"


# ============================================================
# Install BusyBox
# ============================================================

echo
echo "============================================================"
echo " Installing BusyBox"
echo "============================================================"
echo

rm -rf "$INSTALL_DIR"

mkdir -p "$INSTALL_DIR"

make \
    ARCH=arm64 \
    CROSS_COMPILE="${CROSS_COMPILE}" \
    CONFIG_PREFIX="$INSTALL_DIR" \
    install


# ============================================================
# Build Complete
# ============================================================

echo
echo "============================================================"
echo " BusyBox Build Completed"
echo "============================================================"
echo
echo " SDK       : $SDK_TYPE"
echo " SYSROOT   : $SYSROOT"
echo " OUTPUT    : $INSTALL_DIR"
echo
echo "============================================================"
