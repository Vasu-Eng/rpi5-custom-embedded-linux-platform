#!/usr/bin/env bash

set -e


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$PROJECT_ROOT/sdk/custom-sdk/environment-setup"
echo "Inside build.sh:"
echo "$SYSROOT"

PACKAGE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SOURCE_DIR="${PACKAGE_ROOT}/source"
BUILD_DIR="${PACKAGE_ROOT}/build"
INSTALL_DIR="${PACKAGE_ROOT}/install"

mkdir -p "$BUILD_DIR"
mkdir -p "$INSTALL_DIR"

cd "$BUILD_DIR"

echo "[INFO] Configuring Dropbear..."

"$SOURCE_DIR/configure" \
    --host=aarch64-buildroot-linux-gnu \
    --prefix=/usr

echo "[INFO] Building Dropbear..."

make \
    PROGRAMS="${PROGRAMS}" \
    MULTI="${MULTI}" \
    SCPPROGRESS="${SCPPROGRESS}" \
    -j"$(nproc)"


echo "[INFO] Installing Dropbear..."

make \
    PROGRAMS="${PROGRAMS}" \
    MULTI="${MULTI}" \
    SCPPROGRESS="${SCPPROGRESS}" \
    DESTDIR="${INSTALL_DIR}" \
    install

echo "[INFO] Dropbear build completed."

if [ "$1" = "clean" ]; then
    rm -rf build install
    exit 0
fi


