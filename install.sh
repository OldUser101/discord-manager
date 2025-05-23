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

supports_truecolor() {
    [[ "$COLORTERM" == *truecolor* || "$TERM" == *-truecolor || "$TERM" == *-direct ]] && return 0
    return 1
}

ask_confirm() {
    local prompt="${1}"
    local default="${2}"
    local reply

    local options
    case "$default" in
        yes|y) options="[Y/n]" ;;
        no|n) options="[y/N]" ;;
        *) options="[y/n]" ;;
    esac

    while true; do
        read -rp "$prompt $options: " reply
        reply=${reply,,}

        if [[ -z "$reply" ]]; then
            if [[ "$default" =~ ^(yes|y)$ ]]; then
                return 0
            else
                return 1
            fi
        fi

        case "$reply" in
            y|yes) return 0 ;;
            n|no) return 1 ;;
            *)
                if [[ "$default" =~ ^(yes|y)$ ]]; then
                    return 0
                else
                    return 1
                fi
            ;;
        esac
    done
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

if supports_truecolor; then
    BANNER_COLOR="\e[38;2;88;101;242m"
else
    BANNER_COLOR="\e[94m"
fi

RED_COLOR="\e[1;31m"
GREEN_COLOR="\e[1;32m"
RESET_COLOR="\e[0m"

SYSTEM_INSTALL=0
LOCAL_INSTALL=0

LATEST_SOURCE="https://raw.githubusercontent.com/OldUser101/discord-manager/refs/heads/main"

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --user) LOCAL_INSTALL=1; shift ;;
        --system) SYSTEM_INSTALL=1; shift ;;
    esac
done

if (( LOCAL_INSTALL && SYSTEM_INSTALL )); then
    echo -e "Cannot use $BANNER_COLOR--system$RESET_COLOR and $BANNER_COLOR--user$RESET_COLOR in the same command."
    exit 1;
fi

banner

if (( LOCAL_INSTALL )); then
    LOCAL_INSTALL=1
    echo -e "Installing in ${BANNER_COLOR}PER-USER$RESET_COLOR scope."
    INSTALL_DIR=$(eval echo "~/.local/share/discord-manager")
    SYMLINK_DIR=$(eval echo "~/.local/bin")
elif [[ "$EUID" -eq 0 ]] || (( SYSTEM_INSTALL )); then
    SYSTEM_INSTALL=1
    echo -e "Installing in ${BANNER_COLOR}SYSTEM$RESET_COLOR scope."
    INSTALL_DIR="/usr/share/discord-manager"
    SYMLINK_DIR="/usr/bin"
else
    LOCAL_INSTALL=1
    echo -e "Installing in ${BANNER_COLOR}PER-USER$RESET_COLOR scope."
    INSTALL_DIR=$(eval echo "~/.local/share/discord-manager")
    SYMLINK_DIR=$(eval echo "~/.local/bin")
fi

ask_confirm "Do you want to continue?" yes
if [[ $? -eq 1 ]]; then
    exit 0
fi

echo "Creating installation directory..."

mkdir -p "$INSTALL_DIR"
if [[ $? -ne 0 ]]; then
    echo -e "${RED_COLOR}Failed to create installation directory.$RESET_COLOR"
    exit 1
fi

echo "Downloading files..."

wget -q -O "$INSTALL_DIR/discord-manager.sh" "$LATEST_SOURCE/discord-manager.sh"
if [[ $? -ne 0 ]]; then
    echo -e "${RED_COLOR}Failed to download DiscordManager.$RESET_COLOR"
    exit 1
fi

wget -q -O "$INSTALL_DIR/README.md" "$LATEST_SOURCE/README.md"
if [[ $? -ne 0 ]]; then
    echo -e "${RED_COLOR}Failed to download DiscordManager.$RESET_COLOR"
    exit 1
fi

wget -q -O "$INSTALL_DIR/LICENSE" "$LATEST_SOURCE/LICENSE"
if [[ $? -ne 0 ]]; then
    echo -e "${RED_COLOR}Failed to download DiscordManager.$RESET_COLOR"
    exit 1
fi

echo "Configuring DiscordManager..."

chmod +x "$INSTALL_DIR/discord-manager.sh"
if [[ $? -ne 0 ]]; then
    echo -e "${RED_COLOR}Failed to change file permissions.$RESET_COLOR"
    exit 1
fi

ln -sf "$INSTALL_DIR/discord-manager.sh" "$SYMLINK_DIR/discord-manager"
if [[ $? -ne 0 ]]; then
    echo -e "${RED_COLOR}Failed to create DiscordManager symlinks.$RESET_COLOR"
    exit 1
fi

echo -e "${GREEN_COLOR}Installation success!$RESET_COLOR"