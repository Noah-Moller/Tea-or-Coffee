# Tea or Coffee ☕

A simple, fun web application for collecting drink orders when friends come over. Instead of asking everyone individually what they'd like, guests can place their orders through a web interface, and you can manage everything from an admin portal.

## About This Project

This project started as a fun way to simplify the process of getting drink orders when people visit. Rather than going around asking each person what they'd like, guests can simply open a web page on their phone, select their drink, and add their name. The admin portal lets you see all orders, manage sessions, and track popular drinks.

I built this primarily as a learning project to explore the **Go programming language**. The server is written in Go, and I created a Swift-based CLI tool (`torc`) to make installation and management easy on both macOS and Linux.

## Features

- 📱 **Simple Order Interface** - Guests can place orders from any device on your network
- 🎯 **Session Management** - Organize orders by session (e.g., "Morning Meeting", "Afternoon Break")
- 📊 **Popular Items Tracking** - See which drinks are ordered most frequently
- 🛠️ **Easy CLI Management** - Install, update, and manage the server with simple commands
- 🔧 **Cross-Platform** - Works on macOS and Linux

## Quick Start

### Install the CLI

**Install the CLI with one command:**

```bash
curl -fsSL https://raw.githubusercontent.com/Noah-Moller/tea-or-coffee/main/cli/install.sh | bash
```

This downloads the pre-built binary for your platform and installs it to `/usr/local/bin/torc`.

**Note:** All `torc` commands require `sudo` privileges for installation and service management.

### Install the Server

```bash
sudo torc install
```

This will:
- Check for Go installation
- Build the server binary from source
- Copy web/admin files and menu configuration
- Set up systemd (Ubuntu) or launchd (macOS) service
- Start the service automatically
- Display access URLs

Once installed, you'll have:
- **Order Portal**: `http://your-server-ip:8080/` - For guests to place orders
- **Admin Portal**: `http://your-server-ip:9090/` - For managing sessions and viewing orders

## Usage

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

Options:
- `[a]` Add a new menu item
- `[r]` Remove a menu item
- `[e]` Edit an existing menu item
- `[s]` Save and exit
- `[q]` Quit without saving

### Update

Update both the CLI and server to the latest version:

```bash
sudo torc update
```

### Uninstall

Remove the server installation (and optionally the CLI):

```bash
sudo torc uninstall
```

**Note:** This preserves session data (`Sessions/`) and popular items stats (`popular.json`).

## Building from Source

### CLI (Swift)

If you have Swift installed and want to build the CLI from source:

From the `cli/` directory:

```bash
swift build -c release
```

The binary will be at `.build/release/torc`.

To install it system-wide:

```bash
sudo cp .build/release/torc /usr/local/bin/
```

### Server (Go)

The server is built automatically during `torc install`, but you can build it manually:

```bash
go build -o torc-server main.go
```

### Building Standalone Binaries

See [cli/BUILD.md](cli/BUILD.md) for instructions on building distributable CLI binaries.

## Requirements

- **Swift 5.9+** (for building the CLI)
- **Go 1.21+** (for building the server)
- **macOS 13+** or **Ubuntu Linux**
- **sudo access** (for systemd service installation on Linux)

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

## Firewall Configuration

If you're using UFW (Ubuntu Firewall), make sure to allow both ports:

```bash
sudo ufw allow 8080/tcp  # Order portal
sudo ufw allow 9090/tcp  # Admin portal
```

## License

This is a personal project built for fun and learning. Feel free to use it, modify it, or learn from it!
