#!/usr/bin/env bash

# ============================================================
# Raspberry Pi 5 Bootable Image Functions
# ============================================================

unmount_partition_everywhere()
{
    local DEVICE="$1"
    local OWN_MOUNT="$2"

    echo
    echo "[INFO] Checking existing mounts for:"
    echo "       $DEVICE"

    # --------------------------------------------------------
    # Find every mount associated with this block device
    # --------------------------------------------------------

    mapfile -t MOUNTS < <(
        findmnt -rn -S "$DEVICE" -o TARGET 2>/dev/null || true
    )

    # --------------------------------------------------------
    # Unmount every detected mount
    # --------------------------------------------------------

    for mountpoint in "${MOUNTS[@]}"; do

        [[ -n "$mountpoint" ]] || continue

        echo "[INFO] Unmounting:"
        echo "       $mountpoint"

        if sudo umount "$mountpoint"; then
            echo "[OK] Unmounted: $mountpoint"
            continue
        fi

        echo "[WARN] Normal unmount failed:"
        echo "       $mountpoint"

        echo "[INFO] Trying lazy unmount..."

        sudo umount -l "$mountpoint" || true
    done

    # --------------------------------------------------------
    # Check our own mount point
    # --------------------------------------------------------

    if mountpoint -q "$OWN_MOUNT"; then

        echo
        echo "[WARN] Mount point still active:"
        echo "       $OWN_MOUNT"

        echo "[INFO] Processes/mounts using it:"

        sudo fuser -vm "$OWN_MOUNT" || true

        echo
        echo "[INFO] Trying lazy unmount..."

        sudo umount -l "$OWN_MOUNT" || true
    fi

    # --------------------------------------------------------
    # Final check
    # --------------------------------------------------------

    if mountpoint -q "$OWN_MOUNT"; then
        echo
        echo "[ERROR] Unable to unmount:"
        echo "        $OWN_MOUNT"

        return 1
    fi

    echo
    echo "[OK] Partition is unmounted."

    return 0
}

create_rpi5_bootable_image()
{
    local PROJECT_ROOT="$1"

    local BOOTFS_DIR="$PROJECT_ROOT/rpi_bootfs"
    local OUTPUT_DIR="$PROJECT_ROOT/Bootable"

    local IMAGE_NAME="${RPI_IMAGE_NAME:-rpi5_custom.img}"
    local IMAGE_SIZE="${RPI_IMAGE_SIZE:-256M}"

    local IMAGE="$OUTPUT_DIR/$IMAGE_NAME"
    local MOUNT_POINT="$PROJECT_ROOT/.rpi5_boot_mount"

    local LOOP_DEVICE=""
    local PARTITION_DEVICE=""

    echo
    echo "============================================================"
    echo " Creating Raspberry Pi 5 Bootable Image"
    echo "============================================================"
    echo

    # --------------------------------------------------------
    # Check bootfs
    # --------------------------------------------------------

    if [[ ! -d "$BOOTFS_DIR" ]]; then
        echo "[ERROR] Boot filesystem not found:"
        echo "        $BOOTFS_DIR"
        return 1
    fi

    # --------------------------------------------------------
    # Check required files
    # --------------------------------------------------------

    local REQUIRED_FILES=(
        "$BOOTFS_DIR/config.txt"
        "$BOOTFS_DIR/cmdline.txt"
    )

    for file in "${REQUIRED_FILES[@]}"; do
        if [[ ! -e "$file" ]]; then
            echo "[ERROR] Required boot file not found:"
            echo "        $file"
            return 1
        fi
    done

    # --------------------------------------------------------
    # Check required host tools
    # --------------------------------------------------------

    local REQUIRED_TOOLS=(
        parted
        losetup
        mkfs.vfat
        mount
        umount
        fdisk
    )

    for tool in "${REQUIRED_TOOLS[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            echo "[ERROR] Required host tool not found: $tool"
            return 1
        fi
    done

    # --------------------------------------------------------
    # Create directories
    # --------------------------------------------------------

    mkdir -p "$OUTPUT_DIR"
    sudo mkdir -p "$MOUNT_POINT"

    # --------------------------------------------------------
    # Remove previous image
    # --------------------------------------------------------

    if [[ -e "$IMAGE" ]]; then
        echo "[INFO] Removing existing image:"
        echo "       $IMAGE"

        rm -f "$IMAGE"
    fi

    # --------------------------------------------------------
    # Create empty image
    # --------------------------------------------------------

    echo
    echo "[1/8] Creating image"
    echo "      Size: $IMAGE_SIZE"

    truncate -s "$IMAGE_SIZE" "$IMAGE"

    # --------------------------------------------------------
    # Create MBR partition table
    # --------------------------------------------------------

    echo
    echo "[2/8] Creating MBR partition table"

    sudo parted -s "$IMAGE" mklabel msdos

    # --------------------------------------------------------
    # Create FAT32 partition
    # --------------------------------------------------------

    echo
    echo "[3/8] Creating FAT32 boot partition"

    sudo parted -s "$IMAGE" \
        mkpart primary fat32 1MiB 100%

    sudo parted -s "$IMAGE" \
        set 1 boot on

    # --------------------------------------------------------
    # Attach image
    # --------------------------------------------------------

    echo
    echo "[4/8] Attaching image to loop device"

    LOOP_DEVICE="$(
        sudo losetup \
            --find \
            --show \
            --partscan \
            "$IMAGE"
    )"

    if [[ -z "$LOOP_DEVICE" ]]; then
        echo "[ERROR] Failed to attach image."
        return 1
    fi

    echo "      Loop device: $LOOP_DEVICE"

    PARTITION_DEVICE="${LOOP_DEVICE}p1"

    # --------------------------------------------------------
    # Wait for partition device
    # --------------------------------------------------------

    echo
    echo "[INFO] Waiting for partition device..."

    for ((i=0; i<20; i++)); do
        if [[ -b "$PARTITION_DEVICE" ]]; then
            break
        fi

        sleep 0.2
    done

    if [[ ! -b "$PARTITION_DEVICE" ]]; then
        echo "[ERROR] Partition device not found:"
        echo "        $PARTITION_DEVICE"

        sudo losetup -d "$LOOP_DEVICE" || true

        return 1
    fi

    echo "      Partition: $PARTITION_DEVICE"

    # --------------------------------------------------------
    # Format FAT32
    # --------------------------------------------------------

    echo
    echo "[5/8] Formatting FAT32 filesystem"

    sudo mkfs.vfat \
        -F 32 \
        -n RPI5BOOT \
        "$PARTITION_DEVICE"

    # --------------------------------------------------------
    # Mount partition
    # --------------------------------------------------------

    echo
    echo "[6/8] Mounting boot partition"

    sudo mount \
        "$PARTITION_DEVICE" \
        "$MOUNT_POINT"

    # --------------------------------------------------------
    # Copy boot filesystem
    # --------------------------------------------------------

    echo
    echo "[7/8] Copying rpi_bootfs"
	# Copy regular boot files
	for file in "$BOOTFS_DIR"/*; do

	    [[ -e "$file" ]] || continue

	    case "$(basename "$file")" in
		overlays)
		    continue
		    ;;
	    esac

	    sudo cp -r "$file" "$MOUNT_POINT/"
	done

# --------------------------------------------------------
# Copy device-tree overlays
# --------------------------------------------------------

	if [[ -d "$BOOTFS_DIR/overlays" ]]; then

	    echo "[INFO] Copying device-tree overlays"

	    sudo mkdir -p "$MOUNT_POINT/overlays"

	    find "$BOOTFS_DIR/overlays" \
		-maxdepth 1 \
		-type f \
		\( -name '*.dtbo' -o -name 'README*' \) \
		-exec sudo cp {} "$MOUNT_POINT/overlays/" \;

	fi
	
# --------------------------------------------------------
# Flush filesystem
# --------------------------------------------------------

echo
echo "[INFO] Flushing filesystem"

sync

# --------------------------------------------------------
# Unmount partition
# --------------------------------------------------------

unmount_partition_everywhere \
    "$PARTITION_DEVICE" \
    "$MOUNT_POINT"


    # --------------------------------------------------------
    # Final verification
    # --------------------------------------------------------

    echo
    echo "[8/8] Verifying image"

    echo
    echo "Image:"
    ls -lh "$IMAGE"

    echo
    echo "Partition table:"
    sudo fdisk -l "$IMAGE"

    echo
    echo "============================================================"
    echo " Bootable image created successfully"
    echo "============================================================"
    echo
    echo "Output:"
    echo "  $IMAGE"
    echo

echo
echo "============================================================"
echo " Image creation finished"
echo "============================================================"
echo
echo "The boot partition is currently attached as:"
echo "  $PARTITION_DEVICE"
echo
echo "Loop device:"
echo "  $LOOP_DEVICE"
echo
read -r -p "Kindly verify the boot partition before detaching it. Unmount and detach now? [y/N]: " answer

case "$answer" in
    y|Y|yes|YES)
        echo
        echo "[INFO] Unmounting boot partition..."

        if mountpoint -q "$MOUNT_POINT"; then
            sudo umount "$MOUNT_POINT"
        fi

        echo "[INFO] Detaching loop device..."

        sudo losetup -d "$LOOP_DEVICE"

        echo "[OK] Loop device detached."

        LOOP_DEVICE=""

        rmdir "$MOUNT_POINT" 2>/dev/null || true
        ;;

    *)
        echo
        echo "[INFO] Leaving loop device attached."
        echo
        echo "You can manually detach it later with:"
        echo
        echo "  sudo losetup -d $LOOP_DEVICE"
        echo
        ;;
esac




    return 0
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then

    PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

    create_rpi5_bootable_image "$PROJECT_ROOT"

fi



