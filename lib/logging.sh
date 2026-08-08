#!/usr/bin/env bash

set -e

log_info()
{
    echo "[INFO] $*"
}

log_error()
{
    echo "[ERROR] $*" >&2
}

log_success()
{
    echo "[ OK ] $*"
}
