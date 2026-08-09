#!/usr/bin/env bash

set -e



# ============================================================
# SDK Preparation
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"


prepare_sdk()
{    
	 
	SDK_ROOT="${PROJECT_ROOT}/sdk/custom-sdk"
	SDK_TARBALL="${SDK_ROOT}/buildroot-toolchains/output/images/aarch64-buildroot-linux-gnu_sdk-buildroot.tar.gz"

	SDK_DIR="${SDK_ROOT}/aarch64-sdk"

	SDK_SHA="${SDK_DIR}/.sdk-sha256"

    echo
    echo "============================================================"
    echo " SDK Manager"
    echo "============================================================"
    echo
    echo " SDK       : custom-sdk"
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
# Direct Execution
# ============================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    prepare_sdk
fi


