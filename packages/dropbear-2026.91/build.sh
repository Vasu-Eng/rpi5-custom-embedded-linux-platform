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
# SDK Preparation
# ============================================================

prepare_sdk()
{
    echo
    echo "============================================================"
    echo " SDK Manager"
    echo "============================================================"
    echo
    echo " SDK       : $SDK_TYPE"
    echo " SDK Root  : $SDK_ROOT"
    echo " SDK Dir   : $SDK_DIR"
    echo
    echo "============================================================"
    echo


    # --------------------------------------------------------
    # Check SDK Tarball
    # --------------------------------------------------------

    if [ ! -f "$SDK_TARBALL" ]; then

        echo
        echo "[ERROR] SDK tarball not found:"
        echo
        echo "  $SDK_TARBALL"
        echo
        echo "Please provide/build the SDK tarball first."
        echo

        exit 1

    fi


    echo "[INFO] SDK tarball:"
    echo "       $SDK_TARBALL"
    echo


    # --------------------------------------------------------
    # Calculate Current Tarball SHA256
    # --------------------------------------------------------

    CURRENT_SHA="$(sha256sum "$SDK_TARBALL" | awk '{print $1}')"


    echo "[INFO] Current SDK tarball SHA256:"
    echo "       $CURRENT_SHA"
    echo


    # ========================================================
    # Existing SDK
    # ========================================================

    if [ -d "$SDK_DIR" ]; then

        echo "[INFO] Existing SDK detected:"
        echo "       $SDK_DIR"
        echo


        # ----------------------------------------------------
        # Existing SDK has SHA signature
        # ----------------------------------------------------

        if [ -f "$SDK_SHA" ]; then

            STORED_SHA="$(cat "$SDK_SHA")"


            echo "[INFO] Stored SDK SHA256:"
            echo "       $STORED_SHA"
            echo


            # ------------------------------------------------
            # SHA Match
            # ------------------------------------------------

            if [ "$STORED_SHA" = "$CURRENT_SHA" ]; then

                echo "[OK] SDK SHA256 matches."
                echo "[OK] Existing SDK is up to date."
                echo "[OK] Existing SDK will be used."
                echo

                return

            fi


            # ------------------------------------------------
            # SHA Mismatch
            # ------------------------------------------------

            echo
            echo "[WARNING] SDK SHA256 mismatch!"
            echo
            echo "Existing SDK SHA256:"
            echo "  $STORED_SHA"
            echo
            echo "Current tarball SHA256:"
            echo "  $CURRENT_SHA"
            echo

            read -r -p "Overwrite existing SDK? [y/N]: " ANSWER


            case "$ANSWER" in

                y|Y)

                    echo
                    echo "[INFO] User selected overwrite."
                    echo "[INFO] Removing existing SDK..."

                    rm -rf "$SDK_DIR"

                    ;;

                *)

                    echo
                    echo "[INFO] Existing SDK kept."
                    echo "[INFO] Build cancelled."
                    echo

                    exit 0

                    ;;

            esac

        else

            # ------------------------------------------------
            # Existing SDK has no SHA
            # ------------------------------------------------

            echo
            echo "[WARNING] Existing SDK has no SHA256 signature."
            echo
            echo "SDK:"
            echo "  $SDK_DIR"
            echo

            read -r -p "Overwrite existing SDK? [y/N]: " ANSWER


            case "$ANSWER" in

                y|Y)

                    echo
                    echo "[INFO] User selected overwrite."
                    echo "[INFO] Removing unsigned SDK..."

                    rm -rf "$SDK_DIR"

                    ;;

                *)

                    echo
                    echo "[INFO] Existing SDK kept."
                    echo "[INFO] Build cancelled."
                    echo

                    exit 0

                    ;;

            esac

        fi

    fi


    # ========================================================
    # Extract SDK
    # ========================================================

    echo
    echo "============================================================"
    echo " Extracting SDK"
    echo "============================================================"
    echo

    echo "Source:"
    echo "  $SDK_TARBALL"
    echo

    echo "Destination:"
    echo "  $SDK_DIR"
    echo


    mkdir -p "$SDK_DIR"


    tar -xzf "$SDK_TARBALL" \
        -C "$SDK_DIR" \
        --strip-components=1


    # ========================================================
    # Store SHA256
    # ========================================================

    echo "$CURRENT_SHA" > "$SDK_SHA"


    echo
    echo "[OK] SDK SHA256 stored:"
    echo "     $SDK_SHA"
    echo


    # ========================================================
    # Verify Sysroot
    # ========================================================

    SYSROOT_DIR="$(find "$SDK_DIR" \
        -type d \
        -name sysroot \
        -print -quit)"


    if [ -z "$SYSROOT_DIR" ]; then

        echo
        echo "[ERROR] SDK sysroot not found."
        echo
        echo "Expected a directory similar to:"
        echo
        echo "  $SDK_DIR/aarch64-buildroot-linux-gnu/sysroot"
        echo

        rm -rf "$SDK_DIR"

        exit 1

    fi


    echo "[OK] SDK sysroot found:"
    echo "     $SYSROOT_DIR"
    echo


    # ========================================================
    # Verify AArch64 Compiler
    # ========================================================

    COMPILER="$SDK_DIR/bin/aarch64-buildroot-linux-gnu-gcc"


    if [ ! -x "$COMPILER" ]; then

        echo
        echo "[ERROR] AArch64 compiler not found:"
        echo
        echo "  $COMPILER"
        echo

        rm -rf "$SDK_DIR"

        exit 1

    fi


    echo "[OK] AArch64 compiler found:"
    echo "     $COMPILER"
    echo

}


# ============================================================
# Prepare SDK
# ============================================================

prepare_sdk


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
