#!/bin/bash
#
# build_rootfs.sh
# Build and manage initramfs image
#

set -e

PROJECT_ROOT="$HOME/Projects/rpi5-custom-embedded-linux-platform"

ROOTFS_DIR="${PROJECT_ROOT}/rpi_rootfs"
BOOTFS_DIR="${PROJECT_ROOT}/rpi_bootfs"

NEW_FILE="${PROJECT_ROOT}/rootfs.cpio.gz"
OLD_FILE="${BOOTFS_DIR}/rootfs.cpio.gz"

echo "================================================="
echo "        Build Root Filesystem (Initramfs)"
echo "================================================="

#-------------------------------------------------------
# Verify directories
#-------------------------------------------------------

if [ ! -d "$ROOTFS_DIR" ]; then
    echo "ERROR: RootFS directory not found."
    echo "$ROOTFS_DIR"
    exit 1
fi

mkdir -p "$BOOTFS_DIR"

#-------------------------------------------------------
# Build initramfs
#-------------------------------------------------------

echo
echo "[1/4] Creating rootfs.cpio.gz..."

(
cd "$ROOTFS_DIR"

find . -print0 \
| cpio --null -o --format=newc --owner=0:0 2>/dev/null \
| gzip -9 > "$NEW_FILE"

)

echo "Done."

echo
echo "[2/4] Generated Image"

ls -lh "$NEW_FILE"

#-------------------------------------------------------
# No previous image
#-------------------------------------------------------

if [ ! -f "$OLD_FILE" ]; then

    echo
    echo "No existing boot image found."
    echo

    read -p "Install generated image to rpi_bootfs? (y/N): " ans

    if [[ "$ans" =~ ^[Yy]$ ]]; then

        cp "$NEW_FILE" "$OLD_FILE"

        echo
        echo "Installed:"
        echo "$OLD_FILE"

    else

        echo
        echo "Image kept at:"
        echo "$NEW_FILE"

    fi

    exit 0
fi

#-------------------------------------------------------
# Compare hashes
#-------------------------------------------------------

echo
echo "[3/4] Comparing SHA256..."

NEW_HASH=$(sha256sum "$NEW_FILE" | awk '{print $1}')
OLD_HASH=$(sha256sum "$OLD_FILE" | awk '{print $1}')

echo
echo "Generated : $NEW_HASH"
echo "Existing  : $OLD_HASH"

echo

#-------------------------------------------------------
# Same Image
#-------------------------------------------------------

if [ "$NEW_HASH" = "$OLD_HASH" ]; then

    echo "================================================="
    echo "No changes detected."
    echo "================================================="

    read -p "Delete newly generated image? (y/N): " ans

    if [[ "$ans" =~ ^[Yy]$ ]]; then

        rm -f "$NEW_FILE"

        echo "Generated image deleted."

    else

        echo "Generated image kept."

    fi

    exit 0
fi

#-------------------------------------------------------
# Different Image
#-------------------------------------------------------

echo "================================================="
echo "RootFS has changed."
echo "================================================="

echo
echo "Generated Image:"
ls -lh "$NEW_FILE"

echo
echo "Existing Image:"
ls -lh "$OLD_FILE"

echo

read -p "Replace boot image with newly generated image? (y/N): " ans

if [[ "$ans" =~ ^[Yy]$ ]]; then

    cp "$NEW_FILE" "$OLD_FILE"
     # Remove temporary generated image
    rm -f "$NEW_FILE"
    echo
    echo "Boot image updated successfully."

else

    echo
    echo "Existing boot image preserved."
    echo "Generated image remains at:"
    echo "$NEW_FILE"

fi

echo
echo "Build completed successfully."
