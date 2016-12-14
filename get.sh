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

sudo=
tmpdir=

main() {
    need_cmd curl
    need_cmd mktemp
    need_cmd read
    need_cmd rm
    need_cmd tar

    if [ "$(id -u)" != "0" ]; then
        need_cmd sudo
        sudo="sudo -E PATH=$PATH"
    fi

    if [ $# -eq 0 ]; then
        echo "Usage: get.sh [-u -y] [-d <path>] (agent | api | auth | cli)"
        exit 1
    fi

    local _action=install
    local _app=
    local _cleanup=yes
    local _no_prompt=no

    for arg in "$@"; do
        case "$arg" in
            agent | api | auth | cli)
                _app="$arg"
                ;;

            -d)
                tmpdir=yes
                _cleanup=no
                ;;

            -u)
                _action=uninstall
                ;;

            -y)
                _no_prompt=yes
                ;;

            *)
                if [ "$tmpdir" = "yes" ]; then
                    tmpdir="$arg"
                else
                    err "Unknown argument $arg"
                fi
                ;;
        esac
    done

    if [ -z $tmpdir ] || [ $tmpdir = "yes" ]; then
        tmpdir="$(mktemp -d 2>/dev/null || ensure mktemp -d -t intecture)"
    fi

    assert_nz "$tmpdir" "temp dir"
    assert_nz "$_app" "app"

    get_os
    local _os=$RETVAL
    assert_nz "$_os" "os"

    local _url="$ASSET_URL/$_app/$_os/latest"
    local _file="$tmpdir/$_app.tar.bz2"

    echo -n "Downloading $_app package..."
    if [ ! -f "$_file" ]; then
        ensure curl -sSfL "$_url" -o "$_file"
        echo "ok"
    else
        echo "cached"
    fi

    if [ "$_action" = "uninstall" ]; then
        echo -n "Uninstalling..."
    else
        echo -n "Installing..."
    fi
    mkdir "$tmpdir/$_app"
    ensure tar -C "$tmpdir/$_app" -xf "$_file" --strip 1
    installer "$_action" "$_app" "$_no_prompt"
    RETVAL=$?
    echo "done"

    if [ $_cleanup = "yes" ]; then
        rm -rf "$tmpdir"
    fi

    return "$RETVAL"
}

installer() {
    local _target=$1
    if [ "$_target" = "install" ] && [ $2 = "api" ] && [ $3 = "no" ]; then
        echo "Which language components do you want to install?"
        echo "Note that C support is an auto-dependency for all other languages."
        while true; do
            read -p "Please choose one of [C, PHP]: " lang < /dev/tty
            case $lang in
                C | c)
                    _target="install-c"
                    break
                    ;;

                PHP | php)
                    _target="install-php"
                    break
                    ;;

                * )
                    echo "Please enter a valid option..."
                    ;;
            esac
        done
    fi

    local _pwd="$(pwd)"
    cd "$tmpdir/$_app"
    $sudo ./installer.sh $_target
    RETVAL=$?
    cd "$_pwd"
    return "$RETVAL"
}

get_os() {
    local _os=$(uname -s)
    case $_os in
        Linux)
            # When we can statically link successfully, we should be able
            # to produce vendor-agnostic packages.
            if [ -f "/etc/centos-release" ]; then
                RETVAL="centos"
            elif [ -f "/etc/fedora-release" ]; then
                RETVAL="fedora"
            elif [ -f "/etc/lsb-release" ]; then
                RETVAL="ubuntu"
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
