# DiscordManager

A shell script for managing Discord installations on Linux.

It is designed to replace the tedious task of downloading and reinstalling Discord when an update is available. This is especially helpful if you don't want to use Flatpak or Snap, since you have to manually extract the tarball.

DiscordManager supports almost all Linux systems, provided you have a working internet connection, and a Bash shell.

## Installation

Run the following command in a Bash shell:

```sh
bash <(wget -qO- https://raw.githubusercontent.com/OldUser101/discord-manager/refs/heads/main/install.sh)
```

This will download and install DiscordManager in a suitable scope.

If you want DiscordManager to be installed in a specific scope, you can pass `--system` or `--user` to the install script.

If DiscordManager is updated, you can run this command again to upgrade your installation. Alternatively, you can run `install.sh` in the directory where DiscordManager was installed. This will be `/usr/share/discord-manager` for system wide installations, and `~/.local/share/discord-manager` for per-user installations.

## Usage

Run DiscordManager by typing `discord-manager` in a Bash shell.

Command syntax:

```
discord-manager [ install | uninstall | upgrade | version | check | help ] [ --system | --user ] [ --no-banner ]
```

The following subcommands are supported:

- `install` - Downloads and installs the latest version of Discord.
- `uninstall` - Removes the Discord installation.
- `upgrade` - Upgrades an existing installation of Discord.
- `check` - Checks for a new Discord version, but does not upgrade.
- `version` - Displays the installed version of Discord and DiscordManager.
- `help` - Displays a help message listing commands and options.

The following options are supported:

- `--system` - Target the system wide installation of Discord.
- `--user` - Target the current user installation of Discord.
- `--no-banner` - Disables the \"DiscordManager\" banner.

The `--system` and `--user` options cannot be used at the same time.

## Disclaimer

Discord is a trademark of Discord Inc. This project is not affiliated with, endorsed by, or sponsored by Discord Inc.