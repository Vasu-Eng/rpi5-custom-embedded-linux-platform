#!/bin/bash

set -e

###############################################################################
# Load Environment
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/environment.sh"

###############################################################################
# Paths
###############################################################################

RT_TESTS_DIR="$PROJECT_ROOT/benchmark-tools/source/rt-tests"

echo "========================================="
echo "Building rt-tests"
echo "========================================="
echo "Source : $RT_TESTS_DIR"
echo "Sysroot: $SYSROOT"
echo

cd "$RT_TESTS_DIR"

make clean

make \
    CROSS_COMPILE="${CROSS_COMPILE}" \
    CFLAGS="${CFLAGS} -Wall -Wno-nonnull" \
    LDFLAGS="${LDFLAGS}"

###############################################################################
# Install
###############################################################################


echo
echo "Installing rt-tests into rootfs..."

install -Dm755 cyclictest        "${ROOTFS}/usr/bin/cyclictest"
install -Dm755 cyclicdeadline    "${ROOTFS}/usr/bin/cyclicdeadline"
install -Dm755 deadline_test     "${ROOTFS}/usr/bin/deadline_test"
install -Dm755 hackbench         "${ROOTFS}/usr/bin/hackbench"
install -Dm755 oslat             "${ROOTFS}/usr/bin/oslat"
install -Dm755 pi_stress         "${ROOTFS}/usr/bin/pi_stress"
install -Dm755 pip_stress        "${ROOTFS}/usr/bin/pip_stress"
install -Dm755 pmqtest           "${ROOTFS}/usr/bin/pmqtest"
install -Dm755 ptsematest        "${ROOTFS}/usr/bin/ptsematest"
install -Dm755 queuelat          "${ROOTFS}/usr/bin/queuelat"
install -Dm755 rt-migrate-test   "${ROOTFS}/usr/bin/rt-migrate-test"
install -Dm755 signaltest        "${ROOTFS}/usr/bin/signaltest"
install -Dm755 sigwaittest       "${ROOTFS}/usr/bin/sigwaittest"
install -Dm755 ssdd              "${ROOTFS}/usr/bin/ssdd"
install -Dm755 svsematest        "${ROOTFS}/usr/bin/svsematest"

echo
echo "rt-tests installed successfully."
