#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# Project-wide Runtime Dependency Resolver
#
# Usage:
#   ./scripts/resolve-runtime-deps.sh \
#       <PACKAGES_DIR> <SYSROOT> <ROOTFS_DIR>
#
#   ./scripts/resolve-runtime-deps.sh \
#       <PACKAGES_DIR> <ROOTFS_DIR>
#
# Example:
#   ./scripts/resolve-runtime-deps.sh \
#       packages \
#       rootfs
#
# The resolver:
#   1. Discovers every package */install directory
#   2. Scans all installed ELF files
#   3. Resolves PT_INTERP
#   4. Resolves DT_NEEDED recursively
#   5. Resolves dependencies against the SDK sysroot
#   6. Deduplicates dependencies globally
#   7. Preserves required library symlink chains
#   8. Copies runtime files into the rootfs
# ============================================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"


source "$PROJECT_ROOT/sdk/environment-setup" custom-sdk

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <PACKAGES_DIR> <ROOTFS_DIR>"
    exit 1
fi


PACKAGES_DIR="$(cd "$1" && pwd)"
ROOTFS_DIR="$(mkdir -p "$2" && cd "$2" && pwd)"


METADATA_DIR="$ROOTFS_DIR/.metadata"

OLD_MANIFEST="$METADATA_DIR/runtime-libs.manifest"
NEW_MANIFEST="$METADATA_DIR/runtime-libs.manifest.new"

mkdir -p "$METADATA_DIR"

touch "$OLD_MANIFEST"

rm -f "$NEW_MANIFEST"
touch "$NEW_MANIFEST"

READELF="${CROSS_COMPILE:-aarch64-buildroot-linux-gnu-}readelf"
FILE_CMD="${FILE_CMD:-file}"

# ------------------------------------------------------------
# Verify required tools
# ------------------------------------------------------------

if ! command -v "$READELF" >/dev/null 2>&1; then
    echo "[ERROR] readelf not found:"
    echo "        $READELF"
    exit 1
fi

if ! command -v "$FILE_CMD" >/dev/null 2>&1; then
    echo "[ERROR] file command not found."
    exit 1
fi

# ------------------------------------------------------------
# Global dependency sets
# ------------------------------------------------------------

declare -A VISITED_PATHS
declare -A RESOLVED_LIBS
declare -A RESOLVED_PATHS

# ------------------------------------------------------------
# Counters
# ------------------------------------------------------------

ELF_COUNT=0
PACKAGE_COUNT=0
DEPENDENCY_COUNT=0


is_package_owned()
{
    local REL_PATH="$1"

    local PACKAGE_MANIFEST="$METADATA_DIR/package-files.manifest"

    [ -f "$PACKAGE_MANIFEST" ] || return 1

    grep -Fxq "$REL_PATH" "$PACKAGE_MANIFEST"
}


# ============================================================
# Find a runtime library in the SDK sysroot
# ============================================================

find_library()
{
    local LIB="$1"

    find "$SYSROOT" \
        \( -type f -o -type l \) \
        -name "$LIB" \
        -print -quit
}


# ============================================================
# Convert an absolute sysroot path to target rootfs path
#
# Example:
#
# SYSROOT/lib/libc.so.6
#       ->
# /lib/libc.so.6
# ============================================================



sysroot_to_rootfs_path()
{
    local PATH_IN_SYSROOT="$1"
    local REL_PATH

    if [[ "$PATH_IN_SYSROOT" != "$SYSROOT/"* ]]; then
        echo "[ERROR] File is outside SYSROOT:"
        echo "        $PATH_IN_SYSROOT"
        echo "        SYSROOT=$SYSROOT"
        exit 1
    fi

    REL_PATH="${PATH_IN_SYSROOT#"$SYSROOT"}"

    echo "/${REL_PATH#/}"
}
# ============================================================
# Copy a file/symlink while preserving the library structure
# ============================================================
copy_runtime_file()
{
    local SOURCE="$1"
    local REL_PATH

    REL_PATH="$(sysroot_to_rootfs_path "$SOURCE")"

    if [ -z "$REL_PATH" ] || [ "$REL_PATH" = "$SOURCE" ]; then
        echo
        echo "[ERROR] Could not calculate rootfs path:"
        echo "        $SOURCE"
        exit 1
    fi

    local DEST="$ROOTFS_DIR$REL_PATH"

    mkdir -p "$(dirname "$DEST")"

    # --------------------------------------------------------
    # Record this runtime-owned file
    # --------------------------------------------------------

    printf '%s\n' "$REL_PATH" >> "$NEW_MANIFEST"

    # --------------------------------------------------------
    # Package ownership takes priority
    # --------------------------------------------------------

    if is_package_owned "$REL_PATH"; then

        echo
        echo "============================================================"
        echo "[ERROR] Runtime/package ownership conflict"
        echo "============================================================"
        echo
        echo "Runtime dependency:"
        echo "  $REL_PATH"
        echo
        echo "Package manifest already owns this file."
        echo
        echo "Package manifest:"
        echo "  $METADATA_DIR/package-files.manifest"
        echo
        exit 1
    fi

    # --------------------------------------------------------
    # Destination does not exist
    # --------------------------------------------------------

    if [ ! -e "$DEST" ] && [ ! -L "$DEST" ]; then

        if [ -L "$SOURCE" ]; then

            local LINK_TARGET
            LINK_TARGET="$(readlink "$SOURCE")"

            ln -s "$LINK_TARGET" "$DEST"

            echo "[COPY] $REL_PATH -> $LINK_TARGET"

        else

            install -m "$(stat -c '%a' "$SOURCE")" \
                "$SOURCE" \
                "$DEST"

            echo "[COPY] $REL_PATH"

        fi

        return
    fi

    # --------------------------------------------------------
    # Existing destination: compare
    # --------------------------------------------------------

    # Source is symlink
    if [ -L "$SOURCE" ]; then

        local SOURCE_LINK
        SOURCE_LINK="$(readlink "$SOURCE")"

        if [ -L "$DEST" ]; then

            local DEST_LINK
            DEST_LINK="$(readlink "$DEST")"

            if [ "$SOURCE_LINK" = "$DEST_LINK" ]; then

                echo "[SKIP] $REL_PATH -> $SOURCE_LINK"

                return
            fi

        fi

        echo
        echo "============================================================"
        echo "[WARNING] Runtime symlink conflict"
        echo "============================================================"
        echo
        echo "File:"
        echo "  $REL_PATH"
        echo
        echo "SDK:"
        echo "  $SOURCE -> $SOURCE_LINK"
        echo
        echo "RootFS:"
        if [ -L "$DEST" ]; then
            echo "  $DEST -> $(readlink "$DEST")"
        else
            echo "  $DEST -> regular file"
        fi
        echo

    # Source is regular file
    else

        if [ -f "$DEST" ]; then

            local SOURCE_SHA
            local DEST_SHA

            SOURCE_SHA="$(sha256sum "$SOURCE" | awk '{print $1}')"
            DEST_SHA="$(sha256sum "$DEST" | awk '{print $1}')"

            if [ "$SOURCE_SHA" = "$DEST_SHA" ]; then

                echo "[SKIP] $REL_PATH"

                return
            fi

            echo
            echo "============================================================"
            echo "[WARNING] Runtime library conflict"
            echo "============================================================"
            echo
            echo "File:"
            echo "  $REL_PATH"
            echo
            echo "SDK SHA256:"
            echo "  $SOURCE_SHA"
            echo
            echo "RootFS SHA256:"
            echo "  $DEST_SHA"
            echo

        else

            echo
            echo "============================================================"
            echo "[WARNING] Runtime file type conflict"
            echo "============================================================"
            echo
            echo "File:"
            echo "  $REL_PATH"
            echo
            echo "SDK:"
            echo "  regular file"
            echo
            echo "RootFS:"
            echo "  existing non-regular file"
            echo

        fi

    fi

    # --------------------------------------------------------
    # Ask before overwriting
    # --------------------------------------------------------

    read -r -p \
        "Overwrite runtime file? [y/N]: " \
        ANSWER < /dev/tty

    case "$ANSWER" in

        y|Y)

            rm -rf "$DEST"

            if [ -L "$SOURCE" ]; then

                local LINK_TARGET
                LINK_TARGET="$(readlink "$SOURCE")"

                ln -s "$LINK_TARGET" "$DEST"

                echo "[OVERWRITE] $REL_PATH -> $LINK_TARGET"

            else

                install -m "$(stat -c '%a' "$SOURCE")" \
                    "$SOURCE" \
                    "$DEST"

                echo "[OVERWRITE] $REL_PATH"

            fi

            ;;

        *)

            echo
            echo "[ERROR] Runtime dependency resolution cancelled."
            echo
            echo "Existing file was not overwritten:"
            echo "  $DEST"
            echo

            rm -f "$NEW_MANIFEST"

            exit 1
            ;;

    esac
}

# ============================================================
# Copy a symlink chain
#
# Example:
#
# libfoo.so
#   -> libfoo.so.1
#       -> libfoo.so.1.2.3
#
# All required entries are copied.
# ============================================================
copy_library_chain()
{
    local SOURCE="$1"

    local CURRENT="$SOURCE"

    # The target path is based on the original sysroot path.
    local REL_PATH
    REL_PATH="$(sysroot_to_rootfs_path "$SOURCE")"

    while true; do

        copy_runtime_file "$CURRENT" 

        if [ ! -L "$CURRENT" ]; then
            break
        fi

        local LINK_TARGET
        LINK_TARGET="$(readlink "$CURRENT")"

        local NEXT

        if [[ "$LINK_TARGET" = /* ]]; then
            NEXT="$SYSROOT$LINK_TARGET"
        else
            NEXT="$(dirname "$CURRENT")/$LINK_TARGET"
        fi

        NEXT="$(realpath -m "$NEXT")"

        if [ ! -e "$NEXT" ] && [ ! -L "$NEXT" ]; then
            echo
            echo "============================================================"
            echo "[ERROR] Broken library symlink"
            echo "============================================================"
            echo
            echo "Original:"
            echo "  $SOURCE"
            echo
            echo "Current:"
            echo "  $CURRENT"
            echo
            echo "Link:"
            echo "  -> $LINK_TARGET"
            echo
            echo "Resolved:"
            echo "  $NEXT"
            echo
            exit 1
        fi

        CURRENT="$NEXT"

        # The next symlink target belongs in the SAME target
        # directory as the original library chain.
        #
        # Example:
        #
        # /lib/libc.so.6 -> libc-2.41.so
        #
        # becomes:
        #
        # /lib/libc.so.6
        # /lib/libc-2.41.so
        #
        local TARGET_DIR
        TARGET_DIR="$(dirname "$REL_PATH")"

        REL_PATH="$TARGET_DIR/$(basename "$CURRENT")"

    done
}

# ============================================================
# Resolve a library recursively
# ============================================================

resolve_library()
{
    local LIB="$1"

    # --------------------------------------------------------
    # Already resolved by library name
    # --------------------------------------------------------

    if [ "${RESOLVED_LIBS[$LIB]+yes}" ]; then
        return
    fi

    local LIB_PATH

    LIB_PATH="$(find_library "$LIB")"

    if [ -z "$LIB_PATH" ]; then

        echo
        echo "[ERROR] Runtime dependency not found:"
        echo "        $LIB"
        echo
        echo "        Sysroot:"
        echo "        $SYSROOT"
        echo

        exit 1
    fi

    RESOLVED_LIBS["$LIB"]=1
    RESOLVED_PATHS["$LIB_PATH"]=1
    DEPENDENCY_COUNT=$((DEPENDENCY_COUNT + 1))

    local REL_PATH
    REL_PATH="$(sysroot_to_rootfs_path "$LIB_PATH")"

    echo "[RESOLVE] $LIB"
    echo "          -> $REL_PATH"

    # --------------------------------------------------------
    # Copy library and its symlink chain
    # --------------------------------------------------------

    copy_library_chain "$LIB_PATH"

    # --------------------------------------------------------
    # Avoid recursively processing the same ELF path
    # --------------------------------------------------------

    if [ "${VISITED_PATHS[$LIB_PATH]+yes}" ]; then
        return
    fi

    VISITED_PATHS["$LIB_PATH"]=1

    # --------------------------------------------------------
    # Read DT_NEEDED from this library
    # --------------------------------------------------------

    local NEEDED

    NEEDED="$("$READELF" -d "$LIB_PATH" 2>/dev/null |
        sed -n 's/.*Shared library: \[\(.*\)\]/\1/p')"

    if [ -n "$NEEDED" ]; then

        while read -r DEP; do

            [ -z "$DEP" ] && continue

            resolve_library "$DEP"

        done <<< "$NEEDED"

    fi
}

# ============================================================
# Resolve ELF interpreter
# ============================================================

resolve_interpreter()
{
    local ELF="$1"

    local INTERP

    INTERP="$("$READELF" -l "$ELF" 2>/dev/null |
        sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"

    [ -z "$INTERP" ] && return

    echo "  PT_INTERP:"
    echo "    $INTERP"

    local INTERP_NAME
    INTERP_NAME="$(basename "$INTERP")"

    resolve_library "$INTERP_NAME"
}

# ============================================================
# Process a package ELF
# ============================================================

process_elf()
{
    local ELF="$1"

    ELF_COUNT=$((ELF_COUNT + 1))

    local REL_ELF
    REL_ELF="${ELF#"$PACKAGES_DIR/"}"

    echo
    echo "[ELF] $REL_ELF"

    # --------------------------------------------------------
    # Check whether this ELF is dynamically linked
    # --------------------------------------------------------

    resolve_interpreter "$ELF"

    # --------------------------------------------------------
    # Read DT_NEEDED
    # --------------------------------------------------------

    local NEEDED

    NEEDED="$("$READELF" -d "$ELF" 2>/dev/null |
        sed -n 's/.*Shared library: \[\(.*\)\]/\1/p')"

    if [ -z "$NEEDED" ]; then

        echo "  DT_NEEDED:"
        echo "    none"

        return
    fi

    echo "  DT_NEEDED:"

    while read -r LIB; do

        [ -z "$LIB" ] && continue

        echo "    $LIB"

        resolve_library "$LIB"

    done <<< "$NEEDED"
}

# ============================================================
# Discover package install directories
# ============================================================

echo
echo "============================================================"
echo " Project Runtime Dependency Resolver"
echo "============================================================"
echo
echo "Packages Dir : $PACKAGES_DIR"
echo "Sysroot      : $SYSROOT"
echo "Rootfs       : $ROOTFS_DIR"
echo "Readelf      : $READELF"
echo
echo "============================================================"
echo

while IFS= read -r -d '' INSTALL_DIR; do

    PACKAGE_COUNT=$((PACKAGE_COUNT + 1))

    echo
    echo "------------------------------------------------------------"
    echo "[PACKAGE] ${INSTALL_DIR#"$PACKAGES_DIR/"}"
    echo "------------------------------------------------------------"

    while IFS= read -r -d '' ELF; do

        FILE_TYPE="$("$FILE_CMD" -b "$ELF" 2>/dev/null || true)"

        case "$FILE_TYPE" in
            *"ELF "*)
                process_elf "$ELF"
                ;;
        esac

    done < <(find "$INSTALL_DIR" -type f -print0)

done < <(
    find "$PACKAGES_DIR" \
        -mindepth 2 \
        -maxdepth 2 \
        -type d \
        -name install \
        -print0
)

# ============================================================
# Remove stale runtime-owned files
# ============================================================

sort -u "$NEW_MANIFEST" -o "$NEW_MANIFEST"

echo
echo "============================================================"
echo " Checking for stale runtime libraries"
echo "============================================================"
echo

if [ -s "$OLD_MANIFEST" ]; then

    while IFS= read -r REL_PATH; do

        [ -z "$REL_PATH" ] && continue

        if ! grep -Fxq "$REL_PATH" "$NEW_MANIFEST"; then

            DEST="$ROOTFS_DIR/$REL_PATH"

            if [ -e "$DEST" ] || [ -L "$DEST" ]; then

                echo
                echo "============================================================"
                echo "[WARNING] Stale runtime library detected"
                echo "============================================================"
                echo
                echo "File:"
                echo "  $REL_PATH"
                echo
                echo "This file was installed by the previous runtime"
                echo "dependency resolution but is no longer required."
                echo

                read -r -p \
                    "Remove stale runtime file? [y/N]: " \
                    ANSWER < /dev/tty

                case "$ANSWER" in

                    y|Y)

                        rm -rf "$DEST"

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

mv "$NEW_MANIFEST" "$OLD_MANIFEST"


# ============================================================
# Final report
# ============================================================

echo
echo "============================================================"
echo " Runtime Dependency Summary"
echo "============================================================"
echo

echo "Packages scanned     : $PACKAGE_COUNT"
echo "ELF files scanned    : $ELF_COUNT"
echo "Unique dependencies  : ${#RESOLVED_LIBS[@]}"
echo

echo "Runtime files:"
echo

for LIB_PATH in "${!RESOLVED_PATHS[@]}"; do

    REL_PATH="$(sysroot_to_rootfs_path "$LIB_PATH")"

    echo "  $REL_PATH"

done | sort

echo
echo "============================================================"
echo " Runtime Dependency Resolution Complete"
echo "============================================================"
echo
