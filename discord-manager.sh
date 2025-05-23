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
DISCORD_EXEC="Discord/Discord"
DISCORD_ICON="Discord/discord.png"
DESKTOP_DIR=$(eval echo "~/.local/share/applications")
LOCAL_INSTALL_DIR="~/.local/share/discord"
LOCAL_SYMLINK="~/.local/bin"
LOCAL_DESKTOP="discord-user.desktop"
SYSTEM_INSTALL_DIR="/usr/share/discord"
SYSTEM_SYMLINK="/usr/bin"
SYSTEM_DESKTOP="discord-system.desktop"
LOCAL_INSTALL=0
SYSTEM_INSTALL=0
NO_BANNER=0

supports_truecolor() {
    [[ "$COLORTERM" == *truecolor* || "$TERM" == *-truecolor || "$TERM" == *-direct ]] && return 0
    return 1
}

compare_versions() {
    if [[ $1 == $2 ]]; then
        return 0
    fi

    v1="$1"
    v2="$2"

    i=1
    while :; do
        part1=$(echo "$v1" | cut -d. -f$i)
        part2=$(echo "$v2" | cut -d. -f$i)

        [ -z "$part1" ] && part1=0
        [ -z "$part2" ] && part2=0

        [ "$part1" -gt "$part2" ] 2>/dev/null && return 1
        [ "$part1" -lt "$part2" ] 2>/dev/null && return 2

        [ -z "$part1" ] && [ -z "$part2" ] && break

        i=$((i + 1))
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
        INSTALL_DIR=$(eval echo "$LOCAL_INSTALL_DIR")
        SYMLINK_DIR=$(eval echo "$LOCAL_SYMLINK")
        DESKTOP_PATH="$DESKTOP_DIR/$LOCAL_DESKTOP"
    elif (( SYSTEM_INSTALL )); then
        INSTALL_DIR=$(eval echo "$SYSTEM_INSTALL_DIR")
        SYMLINK_DIR=$(eval echo "$SYSTEM_SYMLINK")
        DESKTOP_PATH="$DESKTOP_DIR/$SYSTEM_DESKTOP"
    elif [ "$EUID" -eq 0 ]; then
        SYSTEM_INSTALL=1
        INSTALL_DIR=$(eval echo "$SYSTEM_INSTALL_DIR")
        SYMLINK_DIR=$(eval echo "$SYSTEM_SYMLINK")
        DESKTOP_PATH="$DESKTOP_DIR/$SYSTEM_DESKTOP"
    else
        LOCAL_INSTALL=1
        INSTALL_DIR=$(eval echo "$LOCAL_INSTALL_DIR")
        SYMLINK_DIR=$(eval echo "$LOCAL_SYMLINK")
        DESKTOP_PATH="$DESKTOP_DIR/$LOCAL_DESKTOP"
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

install() {
    current_version=$(get_current_version)

    local user_or_system="PER-USER"

    if (( SYSTEM_INSTALL )); then
        user_or_system="SYSTEM"
    fi

    if [[ -n "$current_version" ]]; then
        echo -e "Discord $BANNER_COLOR$current_version $user_or_system$RESET_COLOR is already installed. Use 'discord-manager upgrade' to upgrade it."
        exit 1
    fi

    latest_version=$(get_latest_version)
    if [[ -z "$latest_version" ]]; then
        echo "${RED_COLOR}Failed to get remote version information.$RESET_COLOR"
        exit 1
    fi

    echo -e "Installing Discord $BANNER_COLOR$user_or_system$RESET_COLOR"

    echo -e "The latest version of Discord is: $BANNER_COLOR$latest_version$RESET_COLOR"

    echo -e "Downloading Discord $BANNER_COLOR$latest_version$RESET_COLOR tarball..."

    curl -Lo /tmp/discord.tar.gz -s "https://discord.com/api/download?platform=linux&format=tar.gz"
    if [[ $? -ne 0 ]]; then
        echo -e "${RED_COLOR}Failed to download Discord tarball.$RESET_COLOR"
        exit 1
    fi

    echo "Creating directories..."

    mkdir -p "$INSTALL_DIR"
    if [[ $? -ne 0 ]]; then
        echo -e "${RED_COLOR}Failed to create installation directory.$RESET_COLOR"
        exit 1
    fi

    echo "Extracting Discord tarball..."

    tar -xf /tmp/discord.tar.gz -C "$INSTALL_DIR"
    if [[ $? -ne 0 ]]; then
        echo -e "${RED_COLOR}Failed to extract Discord tarball.$RESET_COLOR"
        exit 1
    fi   

    echo "Setting up Discord..."

    echo "$latest_version" > "$INSTALL_DIR/VERSION"
    
    ln -s "$INSTALL_DIR/$DISCORD_EXEC" "$SYMLINK_DIR/discord"
    if [[ $? -ne 0 ]]; then
        echo -e "${RED_COLOR}Failed to create Discord symlinks.$RESET_COLOR"
        exit 1
    fi

cat > "$DESKTOP_PATH" <<EOF
[Desktop Entry]
Name=Discord
StartupWMClass=discord
Comment=All-in-one voice and text chat for gamers that's free, secure, and works on both your desktop and phone.
GenericName=Internet Messenger
Exec=${SYMLINK_DIR}/discord
Icon=${INSTALL_DIR}/${DISCORD_ICON}
Type=Application
Categories=Network;InstantMessaging;
Path=${SYMLINK_DIR}
EOF

    update-desktop-database "$DESKTOP_DIR"

    echo "Removing temporary files..."

    rm /tmp/discord.tar.gz
    if [[ $? -ne 0 ]]; then
        echo -e "${RED_COLOR}Failed to delete downloaded tarball.$RESET_COLOR"
        exit 1
    fi

    echo -e "${GREEN_COLOR}Installation success!$RESET_COLOR"
}

upgrade() {
    check "no-msg"
    if [[ $? -ne 1 ]]; then
        exit 0
    fi

    ask_confirm "Do you want to install the latest version?" yes
    if [[ $? -eq 1 ]]; then
        exit 0
    fi

    current_version=$(get_current_version)

    local user_or_system="PER-USER"

    if (( SYSTEM_INSTALL )); then
        user_or_system="SYSTEM"
    fi

    echo -e "Downloading Discord $BANNER_COLOR$latest_version$RESET_COLOR tarball..."

    curl -Lo /tmp/discord.tar.gz -s "https://discord.com/api/download?platform=linux&format=tar.gz"
    if [[ $? -ne 0 ]]; then
        echo -e "${RED_COLOR}Failed to download Discord tarball.$RESET_COLOR"
        exit 1
    fi

    echo -e "Removing Discord $BANNER_COLOR$current_version $user_or_system$RESET_COLOR..."

    rm -rf "$INSTALL_DIR"
    if [[ $? -ne 0 ]]; then
        echo "${RED_COLOR}Failed to remove old Discord.$RESET_COLOR"
        exit 1
    fi

    echo "Creating directories..."

    mkdir -p "$INSTALL_DIR"
    if [[ $? -ne 0 ]]; then
        echo -e "${RED_COLOR}Failed to create installation directory.$RESET_COLOR"
        exit 1
    fi

    echo "Extracting Discord tarball..."

    tar -xf /tmp/discord.tar.gz -C "$INSTALL_DIR"
    if [[ $? -ne 0 ]]; then
        echo -e "${RED_COLOR}Failed to extract Discord tarball.$RESET_COLOR"
        exit 1
    fi

    echo "Setting up Discord..."

    echo "$latest_version" > "$INSTALL_DIR/VERSION"

    echo "Removing temporary files..."

    rm /tmp/discord.tar.gz
    if [[ $? -ne 0 ]]; then
        echo -e "${RED_COLOR}Failed to delete downloaded tarball.$RESET_COLOR"
        exit 1
    fi

    echo -e "${GREEN_COLOR}Upgrade success!$RESET_COLOR"
}

uninstall() {    
    current_version=$(get_current_version)

    if [[ -z "$current_version" ]]; then
        if (( LOCAL_INSTALL )); then
            echo "You ($(whoami)) do not have Discord installed. Use 'discord-manager install' to install."
        else
            echo "You do not have Discord installed. Use 'discord-manager install' to install."
        fi
        exit 1
    fi

    local user_or_system="PER-USER"

    if (( SYSTEM_INSTALL )); then
        user_or_system="SYSTEM"
    fi

    echo -e "You are about to uninstall Discord $BANNER_COLOR$current_version $user_or_system$RESET_COLOR."

    if ask_confirm "Are you sure?" no; then
        echo -e "Removing Discord $BANNER_COLOR$current_version $user_or_system$RESET_COLOR..."
        rm -rf "$INSTALL_DIR"
        if [[ $? -ne 0 ]]; then
            echo "${RED_COLOR}Failed to uninstall Discord.$RESET_COLOR"
            exit 1
        fi
        rm "$SYMLINK_DIR/discord"
        if [[ $? -ne 0 ]]; then
            echo "${RED_COLOR}Failed to uninstall Discord.$RESET_COLOR"
            exit 1
        fi
        rm "$DESKTOP_PATH"
        if [[ $? -ne 0 ]]; then
            echo "${RED_COLOR}Failed to uninstall Discord.$RESET_COLOR"
            exit 1
        fi
    else
        echo "Cancelled by user."
        return 0
    fi

    if ask_confirm "Do you want to remove Discord user data?" no; then
        echo "Removing Discord user data..."
        rm -rf "~/.config/discord"
        if [[ $? -ne 0 ]]; then
            echo "${RED_COLOR}Failed to remove Discord user data.$RESET_COLOR"
            exit 1
        fi
    fi

    echo -e "${GREEN_COLOR}Uninstallation success!$RESET_COLOR"
}

version() {
    echo -e "You have DiscordManager version: $BANNER_COLOR$MANAGER_VERSION$RESET_COLOR"

    current_version=$(get_current_version)
    
    if (( LOCAL_INSTALL )) && [[ -n "$current_version" ]]; then
        echo -e "You ($(whoami)) have Discord version: $BANNER_COLOR$current_version PER-USER$RESET_COLOR"
    elif (( SYSTEM_INSTALL )) && [[ -n "$current_version" ]]; then
        echo -e "You have Discord version: $BANNER_COLOR$current_version SYSTEM$RESET_COLOR"
    elif (( LOCAL_INSTALL )); then
        echo "You ($(whoami)) do not have Discord installed. Use 'discord-manager install' to install."
    else
        echo "You do not have Discord installed. Use 'discord-manager install' to install."
    fi
}

check() {
    latest_version=$(get_latest_version)
    current_version=$(get_current_version)

    if [[ -z "$latest_version" ]]; then
        echo "${RED_COLOR}Failed to get remote version information.$RESET_COLOR"
        exit 1
    fi

    if [[ ! -z "$current_version" ]]; then
        compare_versions $latest_version $current_version
    fi

    up_to_date=$?
    up_to_date_str="Your version is up-to-date."

    local rc=0

    if [[ up_to_date -eq 1 ]]; then
        up_to_date_str="Your version is out of date. Use 'discord-manager upgrade' to upgrade."
        rc=1
    fi

    if (( "$1" == "no-msg" )) && [[ up_to_date -eq 1 ]]; then
        up_to_date_str="Your version is out of date."
    fi

    echo -e "The latest version of Discord is: $BANNER_COLOR$latest_version$RESET_COLOR"

    if (( LOCAL_INSTALL )) && [[ -n "$current_version" ]]; then
        echo -e "You ($(whoami)) have Discord version: $BANNER_COLOR$current_version PER-USER$RESET_COLOR"
        echo "$up_to_date_str"
    elif (( SYSTEM_INSTALL )) && [[ -n "$current_version" ]]; then
        echo -e "You have Discord version: $BANNER_COLOR$current_version SYSTEM$RESET_COLOR"
        echo "$up_to_date_str"
    elif (( LOCAL_INSTALL )); then
        echo "You ($(whoami)) do not have Discord installed. Use 'discord-manager install' to install."
        return 0
    else
        echo "You do not have Discord installed. Use 'discord-manager install' to install."
        return 0
    fi

    if [[ rc -eq 1 ]]; then
        return 1
    fi

    return 0
}

help() {
    echo "Usage: discord-manager [ install | uninstall | upgrade | version | check | help ] [ --system | --user ] [ --no-banner ]"
    echo "    Subcommands:"
    echo -e "$BANNER_COLOR        install$RESET_COLOR:     Downloads and installs the latest version of Discord."
    echo -e "$BANNER_COLOR        uninstall$RESET_COLOR:   Removes a Discord installation."
    echo -e "$BANNER_COLOR        upgrade$RESET_COLOR:     Upgrades an existing installation of Discord."
    echo -e "$BANNER_COLOR        check$RESET_COLOR:       Checks for a new Discord version, but does not upgrade."
    echo -e "$BANNER_COLOR        version$RESET_COLOR:     Displays the installed version of Discord and DiscordManager."
    echo -e "$BANNER_COLOR        help$RESET_COLOR:        Displays this help message."
    echo "    Options:"
    echo -e "$BANNER_COLOR        --system$RESET_COLOR:    Target the system wide installation of Discord."
    echo -e "$BANNER_COLOR        --user$RESET_COLOR:      Target the current user installation of Discord."
    echo -e "$BANNER_COLOR        --no-banner$RESET_COLOR: Disables the \"DiscordManager\" banner."
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

RED_COLOR="\e[1;31m"
GREEN_COLOR="\e[1;32m"
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
    echo "Use 'discord-manager help' for more information."
    exit 1;
fi

configure_system_or_user

if (( ! NO_BANNER )); then
    banner
fi

case "$subcommand" in
    install)
        install
        ;;
    uninstall)
        uninstall
        ;;
    upgrade)
        upgrade
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
        echo "Use 'discord-manager help' for usage."
        exit 1
        ;;
esac