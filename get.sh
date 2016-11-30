#!/bin/sh
# Copyright 2015-2016 Intecture Developers. See the COPYRIGHT file at the
# top-level directory of this distribution and at
# https://intecture.io/COPYRIGHT.
#
# Licensed under the Mozilla Public License 2.0 <LICENSE or
# https://www.tldrlegal.com/l/mpl-2.0>. This file may not be copied,
# modified, or distributed except according to those terms.

# Undefined vars are errors
set -u

ASSET_URL="https://static.intecture.io"

main() {
    need_cmd curl
    need_cmd mktemp
    need_cmd rm
    need_cmd sudo
    need_cmd tar

    if [ $# -eq 0 ]; then
        echo "Usage: get.sh [-k] (agent | api | auth | cli)"
        exit 1
    fi

    local _app=""
    local _keep_dir=no

    for arg in "$@"; do
        case "$arg" in
            agent | api | auth | cli)
                _app="$arg"
                ;;

            -k)
                _keep_dir=yes
                ;;

            *)
                err "Unknown argument $arg"
                ;;
        esac
    done

    assert_nz "$_app" "app"

    get_os
    local _os=$RETVAL
    assert_nz "$_os" "os"

    local _url="$ASSET_URL/$_app/$_os/latest"
    local _dir="$(mktemp -d 2>/dev/null || ensure mktemp -d -t intecture)"
    local _file="$_dir/pkg.tar.bz2"

    if [ $_keep_dir = "no" ]; then
        echo -n "Downloading $_app package..."
    fi
    ensure curl -sSfL "$_url" -o "$_file"
    if [ $_keep_dir = "no" ]; then
        echo "ok"
    fi

    if [ $_keep_dir = "no" ]; then
        echo -n "Installing..."
    fi
    cd "$_dir"
    ensure tar -xf "$_file" --strip 1
    sudo ./installer.sh install
    local _retval=$?
    if [ $_keep_dir = "no" ]; then
        echo "done"
    fi

    if [ $_keep_dir = "no" ]; then
        rm -rf "$_dir"
    else
        echo "$_dir"
    fi

    return "$_retval"
}

get_os() {
    local _os=$(uname -s)
    case $_os in
        Linux)
            # When we can statically link successfully, we should be able
            # to produce vendor-agnostic packages.
            if [ -f "/etc/redhat-release" ]; then
                RETVAL="redhat"
            elif [ -f "/etc/debian_version" ]; then
                RETVAL="debian"
            else
                err "unsupported Linux flavour"
            fi
            ;;

        FreeBSD)
            RETVAL="freebsd"
            ;;

        Darwin)
            RETVAL="darwin"
            ;;

        *)
            err "unsupported OS type: $_os"
            ;;
    esac
}

err() {
    echo "intecture: $1" >&2
    exit 1
}

need_cmd() {
    if ! command -v "$1" > /dev/null 2>&1
    then err "need '$1' (command not found)"
    fi
}

assert_nz() {
    if [ -z "$1" ]; then err "assert_nz $2"; fi
}

ensure() {
    "$@"
    if [ $? != 0 ]; then
        err "command failed: $*";
    fi
}

main "$@" || exit 1
