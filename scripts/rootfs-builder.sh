#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# RootFS Builder
#
# Usage:
#
#   ./scripts/rootfs-builder.sh <PACKAGES_DIR> <ROOTFS_DIR>
#
# Example:
#
#   ./scripts/rootfs-builder.sh packages rpi_rootfs
#
# Package ownership:
#
#   /bin/*
#   /sbin/*
#   /usr/bin/*
#   /usr/sbin/*
#   /usr/share/*
#
# Configuration/runtime directories are preserved.
#
# Runtime libraries are handled separately by:
#
#   scripts/resolve-runtime-deps.sh
#
# Responsibility:
#
#   Merge every:
#
#       packages/*/install
#
#   into:
#
#       rpi_rootfs/
#
# Runtime dependency resolution is handled separately by:
#
#   scripts/resolve-runtime-deps.sh
# ============================================================


# ============================================================
# Argument Check
# ============================================================

if [ "$#" -ne 2 ]; then

    echo
    echo "Usage:"
    echo
    echo "  $0 <PACKAGES_DIR> <ROOTFS_DIR>"
    echo

    exit 1

fi


# ============================================================
# Paths
# ============================================================

PACKAGES_DIR="$(cd "$1" && pwd)"

mkdir -p "$2"

ROOTFS_DIR="$(cd "$2" && pwd)"

METADATA_DIR="$ROOTFS_DIR/.metadata"

OLD_MANIFEST="$METADATA_DIR/package-files.manifest"

NEW_MANIFEST="$METADATA_DIR/package-files.manifest.new"


# ============================================================
# Create metadata directory
# ============================================================

mkdir -p "$METADATA_DIR"

touch "$OLD_MANIFEST"

rm -f "$NEW_MANIFEST"

touch "$NEW_MANIFEST"


# ============================================================
# Counters
# ============================================================

PACKAGE_COUNT=0
FILE_COUNT=0
COPY_COUNT=0
SKIP_COUNT=0
OVERWRITE_COUNT=0
REMOVE_COUNT=0

# ============================================================
# Header
# ============================================================

echo
echo "============================================================"
echo " RootFS Package Builder"
echo "============================================================"
echo
echo "Packages Dir : $PACKAGES_DIR"
echo "RootFS Dir   : $ROOTFS_DIR"
echo
echo "Package ownership:"
echo "  /bin/*"
echo "  /sbin/*"
echo "  /usr/bin/*"
echo "  /usr/sbin/*"
echo "  /usr/share/*"
echo
echo "Configuration directories are preserved."
echo "Runtime libraries are handled separately."
echo
echo "============================================================"
echo

# ============================================================
# Check whether a path belongs to package ownership
# ============================================================

is_package_owned()
{
    local REL_PATH="$1"

    case "$REL_PATH" in

        bin/*)
            return 0
            ;;

        sbin/*)
            return 0
            ;;

        usr/bin/*)
            return 0
            ;;

        usr/sbin/*)
            return 0
            ;;

        usr/share/*)
            return 0
            ;;

        *)
            return 1
            ;;

    esac
}


# ============================================================
# Add path to new manifest
# ============================================================

record_manifest()
{
        # ----------------------------------------------------
        # Record every package file.
        #
        # The package install tree is the authoritative source
        # for what this package currently provides.
        # ----------------------------------------------------
	    local REL_PATH="$1"

	    if is_package_owned "$REL_PATH"; then
		printf '%s\n' "$REL_PATH" >> "$NEW_MANIFEST"
	    fi
}


# ============================================================
# Merge One Package
# ============================================================

merge_package()
{

    local INSTALL_DIR="$1"


    PACKAGE_COUNT=$((PACKAGE_COUNT + 1))


    echo
    echo "------------------------------------------------------------"
    echo "[PACKAGE] ${INSTALL_DIR#"$PACKAGES_DIR/"}"
    echo "------------------------------------------------------------"
    echo


    # ========================================================
    # Process every entry inside package install directory
    # ========================================================

    while IFS= read -r -d '' SOURCE; do


        # ----------------------------------------------------
        # Relative path inside package
        # ----------------------------------------------------

        local REL_PATH

        REL_PATH="${SOURCE#"$INSTALL_DIR/"}"


        # ----------------------------------------------------
        # Destination inside rootfs
        # ----------------------------------------------------

        local DEST

        DEST="$ROOTFS_DIR/$REL_PATH"


        # ====================================================
        # Directory
        # ====================================================

        if [ -d "$SOURCE" ] && [ ! -L "$SOURCE" ]; then

            mkdir -p "$DEST"

            continue

        fi


        FILE_COUNT=$((FILE_COUNT + 1))
        # ----------------------------------------------------
	# Record package-owned file
	# ----------------------------------------------------
        record_manifest "$REL_PATH"


        # ====================================================
        # Existing destination
        # ====================================================

        if [ -e "$DEST" ] || [ -L "$DEST" ]; then


            # =================================================
            # SOURCE = symlink
            # =================================================

            if [ -L "$SOURCE" ]; then


                local SOURCE_LINK

                SOURCE_LINK="$(readlink "$SOURCE")"


                # ------------------------------------------------
                # Destination is also a symlink
                # ------------------------------------------------

                if [ -L "$DEST" ]; then


                    local DEST_LINK

                    DEST_LINK="$(readlink "$DEST")"


                    # ------------------------------------------------
                    # Same symlink target
                    # ------------------------------------------------

                    if [ "$SOURCE_LINK" = "$DEST_LINK" ]; then

                        echo "[SKIP] $REL_PATH -> $SOURCE_LINK"

                        SKIP_COUNT=$((SKIP_COUNT + 1))

                        continue

                    fi


                    # ------------------------------------------------
                    # Different symlink
                    # ------------------------------------------------

                    echo
                    echo "============================================================"
                    echo "[WARNING] Symlink conflict"
                    echo "============================================================"
                    echo
                    echo "Path:"
                    echo "  $REL_PATH"
                    echo
                    echo "Package:"
                    echo "  $SOURCE -> $SOURCE_LINK"
                    echo
                    echo "RootFS:"
                    echo "  $DEST -> $DEST_LINK"
                    echo


                # ------------------------------------------------
                # Destination is not a symlink
                # ------------------------------------------------

                else

                    echo
                    echo "============================================================"
                    echo "[WARNING] File type conflict"
                    echo "============================================================"
                    echo
                    echo "Path:"
                    echo "  $REL_PATH"
                    echo
                    echo "Package:"
                    echo "  symlink -> $SOURCE_LINK"
                    echo
                    echo "RootFS:"
                    echo "  regular file/directory"
                    echo

                fi


            # =================================================
            # SOURCE = regular file
            # =================================================

            elif [ -f "$SOURCE" ]; then


                # ------------------------------------------------
                # Destination must also be a regular file
                # ------------------------------------------------

                if [ -f "$DEST" ]; then


                    # ------------------------------------------------
                    # Calculate SHA256
                    # ------------------------------------------------

                    local SOURCE_SHA

                    local DEST_SHA


                    SOURCE_SHA="$(sha256sum "$SOURCE" | awk '{print $1}')"

                    DEST_SHA="$(sha256sum "$DEST" | awk '{print $1}')"


                    # ------------------------------------------------
                    # Identical files
                    # ------------------------------------------------

                    if [ "$SOURCE_SHA" = "$DEST_SHA" ]; then

                        echo "[SKIP] $REL_PATH"

                        SKIP_COUNT=$((SKIP_COUNT + 1))

                        continue

                    fi


                    # ------------------------------------------------
                    # Different files
                    # ------------------------------------------------

                    echo
                    echo "============================================================"
                    echo "[WARNING] File conflict detected"
                    echo "============================================================"
                    echo
                    echo "File:"
                    echo "  $REL_PATH"
                    echo
                    echo "Package:"
                    echo "  $SOURCE"
                    echo
                    echo "Package SHA256:"
                    echo "  $SOURCE_SHA"
                    echo
                    echo "RootFS:"
                    echo "  $DEST"
                    echo
                    echo "RootFS SHA256:"
                    echo "  $DEST_SHA"
                    echo


                else

                    echo
                    echo "============================================================"
                    echo "[WARNING] File type conflict"
                    echo "============================================================"
                    echo
                    echo "Path:"
                    echo "  $REL_PATH"
                    echo
                    echo "Package:"
                    echo "  regular file"
                    echo
                    echo "RootFS:"
                    echo "  different file type"
                    echo

                fi


            # =================================================
            # Unsupported source type
            # =================================================

            else

                echo
                echo "[WARNING] Unsupported source type:"
                echo "          $SOURCE"
                echo

                continue

            fi


            # =================================================
            # Ask before overwrite
            # =================================================

            read -r -p "Overwrite existing entry? [y/N]: " ANSWER < /dev/tty


            case "$ANSWER" in

                y|Y)

                    echo
                    echo "[INFO] Overwriting:"
                    echo "       $REL_PATH"
                    echo

                    rm -rf "$DEST"

                    OVERWRITE_COUNT=$((OVERWRITE_COUNT + 1))

                    ;;


                *)

                    echo
                    echo "[ERROR] RootFS build cancelled."
                    echo
                    echo "Existing rootfs entry was not overwritten:"
                    echo "  $DEST"
                    echo

                    exit 1

                    ;;

            esac

        fi


        # ====================================================
        # Create destination directory
        # ====================================================

        mkdir -p "$(dirname "$DEST")"


        # ====================================================
        # Copy symbolic link
        # ====================================================

        if [ -L "$SOURCE" ]; then


            local LINK_TARGET

            LINK_TARGET="$(readlink "$SOURCE")"


            ln -s "$LINK_TARGET" "$DEST"


            echo "[COPY] $REL_PATH -> $LINK_TARGET"


        # ====================================================
        # Copy regular file
        # ====================================================

        elif [ -f "$SOURCE" ]; then


            local MODE

            MODE="$(stat -c '%a' "$SOURCE")"


            install -m "$MODE" \
                "$SOURCE" \
                "$DEST"


            echo "[COPY] $REL_PATH"


        # ====================================================
        # Unsupported file type
        # ====================================================

        else

            echo
            echo "[WARNING] Unsupported file type:"
            echo "          $SOURCE"
            echo

        fi


    done < <(
        find "$INSTALL_DIR" \
            -mindepth 1 \
            -print0
    )

}


# ============================================================
# Discover Package Install Directories
#
# Only:
#
#   packages/*/install
#
# are treated as package installation trees.
# ============================================================

while IFS= read -r -d '' INSTALL_DIR; do

    merge_package "$INSTALL_DIR"

done < <(
    find "$PACKAGES_DIR" \
        -mindepth 2 \
        -maxdepth 2 \
        -type d \
        -name install \
        -print0
)


# ============================================================
# Sort and remove duplicates from new manifest
# ============================================================

sort -u "$NEW_MANIFEST" -o "$NEW_MANIFEST"


# ============================================================
# Remove stale package-owned files
#
# OLD MANIFEST:
#   files installed by previous package build
#
# NEW MANIFEST:
#   files installed by current package build
#
# OLD - NEW = stale package files
# ============================================================

if [ -s "$OLD_MANIFEST" ]; then

    echo
    echo "============================================================"
    echo " Checking for stale package files"
    echo "============================================================"
    echo


    while IFS= read -r REL_PATH; do

        [ -z "$REL_PATH" ] && continue


        if ! grep -Fxq "$REL_PATH" "$NEW_MANIFEST"; then

            DEST="$ROOTFS_DIR/$REL_PATH"


            if [ -e "$DEST" ] || [ -L "$DEST" ]; then

                echo
                echo "[WARNING] Stale package file detected:"
                echo
                echo "  $REL_PATH"
                echo
                echo "This file was owned by the previous package build"
                echo "but is no longer provided by the current packages."
                echo


                read -r -p \
                    "Remove stale package file? [y/N]: " \
                    ANSWER < /dev/tty


                case "$ANSWER" in

                    y|Y)

                        rm -rf "$DEST"

                        REMOVE_COUNT=$((REMOVE_COUNT + 1))

                        echo "[REMOVE] $REL_PATH"

                        ;;

                    *)

                        echo "[KEEP] $REL_PATH"

                        ;;

                esac

            fi

        fi

    done < "$OLD_MANIFEST"

fi


# ============================================================
# Install new manifest
# ============================================================

mv "$NEW_MANIFEST" "$OLD_MANIFEST"


# ============================================================
# Summary
# ============================================================

echo
echo "============================================================"
echo " RootFS Package Build Complete"
echo "============================================================"
echo
echo "Packages processed : $PACKAGE_COUNT"
echo "Files processed    : $FILE_COUNT"
echo "Files copied       : $COPY_COUNT"
echo "Files skipped      : $SKIP_COUNT"
echo "Files overwritten  : $OVERWRITE_COUNT"
echo "Files removed      : $REMOVE_COUNT"
echo
echo "Package manifest:"
echo "  $OLD_MANIFEST"
echo
echo "RootFS:"
echo "  $ROOTFS_DIR"
echo
echo "============================================================"
echo


