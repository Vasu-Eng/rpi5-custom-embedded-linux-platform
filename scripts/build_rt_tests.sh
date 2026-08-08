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

RT_TESTS_DIR="${PROJECT_ROOT}/benchmark-tools/source/rt-tests"

###############################################################################
# Executables to Install
###############################################################################

EXECUTABLES=(
    cyclictest
    cyclicdeadline
    deadline_test
    hackbench
    oslat
    pi_stress
    pip_stress
    pmqtest
    ptsematest
    queuelat
    rt-migrate-test
    signaltest
    sigwaittest
    ssdd
    svsematest
)

###############################################################################
# Build
###############################################################################

echo "========================================="
echo "Building rt-tests"
echo "========================================="
echo "Source : ${RT_TESTS_DIR}"
echo "Sysroot: ${SYSROOT}"
echo "Rootfs : ${ROOTFS}"
echo

cd "${RT_TESTS_DIR}"

make clean

make \
    CROSS_COMPILE="${CROSS_COMPILE}" \
    CFLAGS="${CFLAGS} -Wall -Wno-nonnull" \
    LDFLAGS="${LDFLAGS}"

###############################################################################
# Install Executables
###############################################################################

echo
echo "========================================="
echo "Installing rt-tests"
echo "========================================="

mkdir -p "${ROOTFS}/usr/bin"

for exe in "${EXECUTABLES[@]}"
do
    echo "Installing ${exe}"
    install -Dm755 "${exe}" "${ROOTFS}/usr/bin/${exe}"
done

###############################################################################
# Install Runtime Dependencies
###############################################################################

echo
echo "========================================="
echo "Resolving Runtime Libraries"
echo "========================================="

declare -A REQUIRED_LIBS
declare -A LIB_USERS
declare -A INSTALLED_LIBS

#
# Collect runtime libraries
#
for exe in "${EXECUTABLES[@]}"
do
    while read -r lib
    do
        #
        # Skip dynamic loader.
        # It should already exist in the rootfs.
        #
        [ "$lib" = "ld-linux-aarch64.so.1" ] && continue

        REQUIRED_LIBS["$lib"]=1

        if [ -z "${LIB_USERS[$lib]}" ]; then
            LIB_USERS["$lib"]="$exe"
        else
            LIB_USERS["$lib"]="${LIB_USERS[$lib]}, $exe"
        fi

    done < <(
        readelf -d "$exe" 2>/dev/null |
        awk '/NEEDED/{
            gsub(/\[/,"");
            gsub(/\]/,"");
            print $NF
        }'
    )
done

echo
echo "Searching runtime libraries..."
echo

FAILED=0

for lib in "${!REQUIRED_LIBS[@]}"
do

    #
    # Already installed?
    #
    if [ -n "${INSTALLED_LIBS[$lib]}" ]; then
        continue
    fi

    LIB_PATH=$(find "${SYSROOT}" -name "${lib}" | head -n1)

    if [ -z "${LIB_PATH}" ]; then

        echo "[ERROR] Missing library : ${lib}"
        echo "        Required by    : ${LIB_USERS[$lib]}"
        echo

        FAILED=1
        continue
    fi

    DEST="${ROOTFS}$(dirname "${LIB_PATH#$SYSROOT}")"

    mkdir -p "${DEST}"

    cp -a "${LIB_PATH}" "${DEST}/"

    #
    # Copy symlink target if required
    #
    if [ -L "${LIB_PATH}" ]; then

        TARGET=$(readlink "${LIB_PATH}")

        if [ -f "$(dirname "${LIB_PATH}")/${TARGET}" ]; then

            cp -a \
                "$(dirname "${LIB_PATH}")/${TARGET}" \
                "${DEST}/"
        fi
    fi

    INSTALLED_LIBS["$lib"]=1

    echo "[OK] ${lib}"

done

###############################################################################
# Summary
###############################################################################

echo
echo "========================================="
echo "Runtime Dependency Summary"
echo "========================================="
echo

echo "Installed Libraries:"
for lib in "${!INSTALLED_LIBS[@]}"
do
    echo "  ✓ ${lib}"
done

echo

if [ "$FAILED" -eq 1 ]; then

    echo "Missing Libraries:"
    echo

    for lib in "${!REQUIRED_LIBS[@]}"
    do
        if [ -z "${INSTALLED_LIBS[$lib]}" ]; then
            echo "  ✗ ${lib}"
            echo "      Required by: ${LIB_USERS[$lib]}"
        fi
    done

    echo
    echo "Build FAILED."
    exit 1

fi

echo "All runtime dependencies resolved successfully."
echo
echo "rt-tests installed into:"
echo "${ROOTFS}/usr/bin"
echo
echo "Build completed successfully."
