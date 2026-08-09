#!/usr/bin/env bash

set -e


# ============================================================
# rt-tests Build Script
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
    echo " Cleaning rt-tests"
    echo "============================================================"
    echo

    rm -rf "$BUILD_DIR"
    rm -rf "$INSTALL_DIR"

    echo "[OK] Build and install directories removed."
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

echo
echo "SDK       : $SDK_TYPE"
echo "CC        : $CC"
echo "AR        : $AR"
echo "CROSS     : $CROSS_COMPILE"
echo "SYSROOT   : $SYSROOT"
echo


# ============================================================
# Verify Cross Compiler
# ============================================================

if ! command -v "${CROSS_COMPILE}gcc" >/dev/null 2>&1; then

    echo
    echo "[ERROR] Cross compiler not found:"
    echo "        ${CROSS_COMPILE}gcc"
    echo

    exit 1
fi


if ! command -v "${CROSS_COMPILE}ar" >/dev/null 2>&1; then

    echo
    echo "[ERROR] Cross archiver not found:"
    echo "        ${CROSS_COMPILE}ar"
    echo

    exit 1
fi


echo "[OK] Cross compiler:"
"${CROSS_COMPILE}gcc" --version | head -1

echo


# ============================================================
# Validate Source
# ============================================================

if [ ! -f "$SOURCE_DIR/Makefile" ]; then

    echo
    echo "[ERROR] rt-tests Makefile not found:"
    echo "        $SOURCE_DIR/Makefile"
    echo

    exit 1
fi


# ============================================================
# Prepare Directories
# ============================================================

mkdir -p "$BUILD_DIR"
mkdir -p "$INSTALL_DIR"


# ============================================================
# Build rt-tests
# ============================================================

echo
echo "============================================================"
echo " Building rt-tests"
echo "============================================================"
echo

cd "$SOURCE_DIR"

make \
    CROSS_COMPILE="${CROSS_COMPILE}" \
    -j"$(nproc)"


# ============================================================
# Install rt-tests
# ============================================================

echo
echo "============================================================"
echo " Installing rt-tests"
echo "============================================================"
echo

rm -rf "$INSTALL_DIR"

mkdir -p "$INSTALL_DIR"

make \
    CROSS_COMPILE="${CROSS_COMPILE}" \
    DESTDIR="${INSTALL_DIR}" \
    prefix=/usr \
    install


# ============================================================
# Build Complete
# ============================================================

echo
echo "============================================================"
echo " rt-tests Build Completed"
echo "============================================================"
echo
echo " SDK       : $SDK_TYPE"
echo " SYSROOT   : $SYSROOT"
echo " OUTPUT    : $INSTALL_DIR"
echo
echo "============================================================"
