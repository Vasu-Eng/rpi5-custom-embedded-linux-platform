#!/usr/bin/env bash

set -e


setup_environment()
{
    source "$PROJECT_ROOT/sdk/environment-setup"
}

create_build_dir()
{
    mkdir -p "$1"
}

create_install_dir()
{
    mkdir -p "$1"
}

clean_directory()
{
    rm -rf "$1"
    mkdir -p "$1"
}
