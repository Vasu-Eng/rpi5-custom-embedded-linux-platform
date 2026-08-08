#!/usr/bin/env bash

set -e

copy_to_rootfs()
{
    cp -a "$1"/. "$ROOTFS"/
}


resolve_runtime_dependencies()
{
    
}
