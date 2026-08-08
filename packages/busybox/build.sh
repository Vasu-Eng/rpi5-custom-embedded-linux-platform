#!/usr/bin/env bash

set -e

source ../../sdk/environment-setup

PACKAGE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SOURCE_DIR="${PACKAGE_ROOT}/source"
BUILD_DIR="${PACKAGE_ROOT}/build"
INSTALL_DIR="${PACKAGE_ROOT}/install"

mkdir -p "$BUILD_DIR"
mkdir -p "$INSTALL_DIR"

if [ "$1" = "clean" ]; then
    rm -rf build install
    exit 0
fi
