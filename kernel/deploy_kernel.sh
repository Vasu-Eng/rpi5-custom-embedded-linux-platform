#!/bin/bash

set -e

KERNEL=~/Projects/linux-rpi-custom
BOOTFS=~/Projects/rpi5-custom-embedded-linux-platform/rpi_bootfs

echo "=========================================="
echo " Deploying Raspberry Pi 5 Custom Kernel"
echo "=========================================="

echo "[1/5] Compressing Kernel Image..."

# Verify Image exists
if [ ! -f "$KERNEL/arch/arm64/boot/Image" ]; then
    echo "Error: Kernel Image not found!"
    exit 1
fi

# Compress Image -> Image.gz
gzip -c "$KERNEL/arch/arm64/boot/Image" > \
"$KERNEL/arch/arm64/boot/Image.gz"

echo "✓ Kernel compressed"

echo "[2/5] Copying Kernel Image..."

cp "$KERNEL/arch/arm64/boot/Image.gz" \
   "$BOOTFS/rpi5_custom_minimal_kernel.img.gz"

echo "✓ Kernel copied"

echo "[3/5] Copying Device Tree..."

cp "$KERNEL/arch/arm64/boot/dts/broadcom/bcm2712-rpi-5-b.dtb" \
   "$BOOTFS/"

echo "✓ DTB copied"

echo "[4/5] Updating Device Tree Overlays..."

rsync -a --delete \
   "$KERNEL/arch/arm/boot/dts/overlays/" \
   "$BOOTFS/overlays/"

echo "✓ Overlays updated"

echo "[5/5] Verifying Deployment..."

echo ""
echo "Deployment Summary"
echo "-----------------------------------------"

echo "Kernel:"
ls -lh "$BOOTFS/rpi5_custom_minimal_kernel.img.gz"

echo ""

echo "Device Tree:"
ls -lh "$BOOTFS/bcm2712-rpi-5-b.dtb"

echo ""

echo "Overlay Count:"
find "$BOOTFS/overlays" -name "*.dtbo" | wc -l

echo ""

echo "Verifying Kernel Integrity..."

SOURCE_HASH=$(sha256sum "$KERNEL/arch/arm64/boot/Image.gz" | awk '{print $1}')
DEPLOYED_HASH=$(sha256sum "$BOOTFS/rpi5_custom_minimal_kernel.img.gz" | awk '{print $1}')

echo "Source   : $SOURCE_HASH"
echo "Deployed : $DEPLOYED_HASH"

if [ "$SOURCE_HASH" = "$DEPLOYED_HASH" ]; then
    echo ""
    echo "✓ Kernel integrity verification PASSED."
else
    echo ""
    echo "✗ Kernel integrity verification FAILED!"
    exit 1
fi

echo ""
echo "✓ BSP deployment completed successfully."
