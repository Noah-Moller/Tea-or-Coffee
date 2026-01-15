# Tea or Coffee (torc) - CLI Installer

Swift-based CLI tool for installing and managing the Tea or Coffee server on macOS and Ubuntu.

## Quick Install

**Install the CLI with one command:**

```bash
curl -fsSL https://raw.githubusercontent.com/Noah-Moller/tea-or-coffee/main/cli/install.sh | bash
```

This downloads the pre-built binary for your platform and installs it to `/usr/local/bin/torc`.

**Note:** All `torc` commands require `sudo` privileges for installation and service management.

**Then install the server:**

```bash
sudo torc install
```

## Building from Source

If you have Swift installed and want to build from source:

From the `cli/` directory:

```bash
swift build -c release
```

The binary will be at `.build/release/torc`.

To install it system-wide:

```bash
sudo cp .build/release/torc /usr/local/bin/
```

### Building Standalone Binaries

See [BUILD.md](BUILD.md) for instructions on building distributable binaries.

## Usage

### Install

Install and start the Tea or Coffee server:

```bash
sudo torc install
```

**Note:** Requires sudo privileges for installing binaries and setting up system services.

This will:
- Check for Go installation
- Build the server binary
- Copy web/admin files and menu.txt
- Set up systemd (Ubuntu) or launchd (macOS) service
- Start the service
- Display access URLs

### Status

Check if the server is running and view access URLs:

```bash
torc status
```

### Update Menu

Interactively edit the menu items:

```bash
sudo torc update-menu
```

**Note:** Requires sudo privileges to modify the menu file in the installation directory.

Options:
- `[a]` Add a new menu item
- `[r]` Remove a menu item
- `[e]` Edit an existing menu item
- `[s]` Save and exit
- `[q]` Quit without saving

### Uninstall

Remove the server installation (and optionally the CLI):

```bash
sudo torc uninstall
```

**Note:** Requires sudo privileges. This preserves session data (`Sessions/`) and popular items stats (`popular.json`).

### Update

Update both the CLI and server to the latest version:

```bash
sudo torc update
```

**Note:** Requires sudo privileges to update binaries and restart services.

## Requirements

- Swift 5.9+ (for building the CLI)
- Go 1.21+ (for building the server)
- macOS 13+ or Ubuntu Linux
- sudo access (for systemd service installation on Linux)

## Service Management

### macOS (launchd)

- Service file: `~/Library/LaunchAgents/com.teacoffee.torc.plist`
- Check status: `launchctl list | grep torc`
- Stop: `launchctl unload ~/Library/LaunchAgents/com.teacoffee.torc.plist`
- Start: `launchctl load ~/Library/LaunchAgents/com.teacoffee.torc.plist`

### Ubuntu (systemd)

- Service file: `/etc/systemd/system/torc-server.service`
- Check status: `sudo systemctl status torc-server`
- Stop: `sudo systemctl stop torc-server`
- Start: `sudo systemctl start torc-server`
- View logs: `sudo journalctl -u torc-server -f`

## Installation Paths

### macOS
- Binary: `/usr/local/bin/torc-server`
- App root: `/usr/local/torc-server`

### Ubuntu
- Binary: `/usr/local/bin/torc-server`
- App root: `/opt/torc-server`
