#!/bin/bash

# SPDX-License-Identifier: MIT
#
# Copyright (C) 2025, Nathan Gill
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THEf
# SOFTWARE.

MANAGER_VERSION="0.1.0"
DISCORD_TARBALL_URL="https://discord.com/api/download?platform=linux&format=tar.gz"
LOCAL_INSTALL_DIR="~/.local/bin/discord"
SYSTEM_INSTALL_DIR="/opt/discord"
INSTALL_DIR=""
LOCAL_INSTALL=0
SYSTEM_INSTALL=0
NO_BANNER=0

supports_truecolor() {
    [[ "$COLORTERM" == *truecolor* || "$TERM" == *-truecolor || "$TERM" == *-direct ]] && return 0
    return 1
}

# https://stackoverflow.com/questions/4023830/how-to-compare-two-strings-in-dot-separated-version-format-in-bash
compare_versions() {
    if [[ $1 == $2 ]]
    then
        return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if ((10#${ver1[i]:=0} > 10#${ver2[i]:=0}))
        then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            return 2
        fi
    done
    return 0
}

get_latest_version() {
    response=$(curl -sI -L "$DISCORD_TARBALL_URL")
    if [[ $? -ne 0 ]]; then
        echo "Error: curl failed with code $?"
        exit 1
    fi

    echo "$response" | grep -i '^location:' | grep -oP 'discord-\K[0-9]+(\.[0-9]+)*'
}

get_current_version() {
    if [[ -f "$INSTALL_DIR/VERSION" ]]; then
        cat "$INSTALL_DIR/VERSION"
    else
        echo ""
    fi
}

configure_system_or_user() {
    if (( LOCAL_INSTALL )); then
        INSTALL_DIR="$LOCAL_INSTALL_DIR"
    elif (( SYSTEM_INSTALL )); then
        INSTALL_DIR="$SYSTEM_INSTALL_DIR"
    elif [ "$EUID" -eq 0 ]; then
        SYSTEM_INSTALL=1
        INSTALL_DIR="$SYSTEM_INSTALL_DIR"
    else
        LOCAL_INSTALL=1
        INSTALL_DIR="$LOCAL_INSTALL_DIR"
    fi
}

banner() {
    echo -en "$BANNER_COLOR"
    echo '  ____  _                       _ __  __                                   '
    echo ' |  _ \(_)___  ___ ___  _ __ __| |  \/  | __ _ _ __   __ _  __ _  ___ _ __ '
    echo ' | | | | / __|/ __/ _ \| '\''__/ _` | |\/| |/ _` | '\''_ \ / _` |/ _` |/ _ \ '\''__|'
    echo ' | |_| | \__ \ (_| (_) | | | (_| | |  | | (_| | | | | (_| | (_| |  __/ |   '
    echo ' |____/|_|___/\___\___/|_|  \__,_|_|  |_|\__,_|_| |_|\__,_|\__, |\___|_|   '
    echo '                                                           |___/           '
    echo -e "$RESET_COLOR"
}

is_up_to_date() {
    latest_version=$(get_latest_version)
    current_version=$(get_current_version)

    if [[ -z "$latest_version" ]]; then
        echo "Failed to get remote version information."
        exit 1
    fi

    if [[ ! -z "$current_version" ]]; then
        compare_versions $latest_version $current_version
    fi

    up_to_date=$?

    if [[ up_to_date -eq 2 ]]; then
        return 0
    fi

    return 1
}

version() {
    echo -e "You have DiscordManager version: $BANNER_COLOR$MANAGER_VERSION$RESET_COLOR"

    current_version=$(get_current_version)
    
    if (( LOCAL_INSTALL )) && [[ -n "$current_version" ]]; then
        echo -e "You ($(whoami)) have Discord version: $BANNER_COLOR$current_version$RESET_COLOR"
    elif (( SYSTEM_INSTALL )) && [[ -n "$current_version" ]]; then
        echo -e "You have Discord version: $BANNER_COLOR$current_version$RESET_COLOR"
    elif (( LOCAL_INSTALL )); then
        echo "You ($(whoami)) do not have Discord installed. Use '$0 install' to install."
    else
        echo "You do not have Discord installed. Use '$0 install' to install."
    fi
}

check() {
    latest_version=$(get_latest_version)
    current_version=$(get_current_version)

    if [[ -z "$latest_version" ]]; then
        echo "Failed to get remote version information."
        exit 1
    fi

    if [[ ! -z "$current_version" ]]; then
        compare_versions $latest_version $current_version
    fi

    up_to_date=$?
    up_to_date_str="Your version is up-to-date."

    if [[ up_to_date -eq 1 ]]; then
        up_to_date_str="Your version is out of date. Use '$0 upgrade' to upgrade."
    fi

    echo -e "The latest version of Discord is: $BANNER_COLOR$latest_version$RESET_COLOR"

    if (( LOCAL_INSTALL )) && [[ -n "$current_version" ]]; then
        echo -e "You ($(whoami)) have version: $BANNER_COLOR$current_version$RESET_COLOR"
        echo "$up_to_date_str"
    elif (( SYSTEM_INSTALL )) && [[ -n "$current_version" ]]; then
        echo -e "You have version: $BANNER_COLOR$current_version$RESET_COLOR"
        echo "$up_to_date_str"
    elif (( LOCAL_INSTALL )); then
        echo "You ($(whoami)) do not have Discord installed. Use '$0 install' to install."
    else
        echo "You do not have Discord installed. Use '$0 install' to install."
    fi
}

help() {
    echo "Usage: $0 [ install | uninstall | upgrade | version | check | help ] [ --system | --user ] [ --no-banner ]"
    echo "    Subcommands:"
    echo -e "$BANNER_COLOR        install$RESET_COLOR:     Downloads and installs the latest version of Discord."
    echo -e "$BANNER_COLOR        uninstall$RESET_COLOR:   Removes Discord from this computer."
    echo -e "$BANNER_COLOR        upgrade$RESET_COLOR:     Upgrades an existing installation of Discord."
    echo -e "$BANNER_COLOR        version$RESET_COLOR:     Displays the installed version of Discord, and DiscordManager."
    echo -e "$BANNER_COLOR        check$RESET_COLOR:       Checks for a new Discord version, but does not update to it."
    echo -e "$BANNER_COLOR        help$RESET_COLOR:        Displays this help message."
    echo "    Options:"
    echo -e "$BANNER_COLOR        --system$RESET_COLOR:    Use the system installation."
    echo -e "$BANNER_COLOR        --user$RESET_COLOR:      Use the per-user installtion."
    echo -e "$BANNER_COLOR        --no-banner$RESET_COLOR: Don't display the \"DiscordManager\" banner."
    echo "    Notes:"
    echo -e "        $BANNER_COLOR--system$RESET_COLOR and $BANNER_COLOR--user$RESET_COLOR cannot be used together."
    echo "    Copyright:"
    echo -e "        DiscordManager copyright (C) 2025, Nathan Gill, under the MIT license. See LICENSE for details."
    echo "    Disclaimer:"
    echo "        Discord is a trademark of Discord Inc. This project is not affiliated with, endorsed by, or sponsored by Discord Inc."
}

if supports_truecolor; then
    BANNER_COLOR="\e[38;2;88;101;242m"
else
    BANNER_COLOR="\e[94m"
fi

RESET_COLOR="\e[0m"

subcommand="${1:-help}"
shift

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --user) LOCAL_INSTALL=1; shift ;;
        --system) SYSTEM_INSTALL=1; shift ;;
        --no-banner) NO_BANNER=1; shift ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if (( LOCAL_INSTALL && SYSTEM_INSTALL )); then
    echo -e "Cannot use $BANNER_COLOR--system$RESET_COLOR and $BANNER_COLOR--user$RESET_COLOR in the same command."
    echo "Use '$0 help' for more information."
    exit 1;
fi

configure_system_or_user

if (( ! NO_BANNER )); then
    banner
fi

case "$subcommand" in
    install)
        echo "install not implemented"
        ;;
    uninstall)
        echo "uninstall not implemented"
        ;;
    update)
        echo "upgrade not implemented"
        ;;
    version)
        version
        ;;
    check)
        check
        ;;
    help|--help|-h)
        help
        ;;
    *)
        echo "Unknown subcommand: $subcommand"
        echo "Use '$0 help' for usage."
        exit 1
        ;;
esac