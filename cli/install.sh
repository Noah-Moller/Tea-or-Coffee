#!/usr/bin/env bash
set -e

# Install script for torc CLI
# Downloads the appropriate binary from GitHub Releases and installs it

REPO_OWNER="${REPO_OWNER:-Noah-Moller}"
REPO_NAME="${REPO_NAME:-tea-or-coffee}"
VERSION="${VERSION:-latest}"

# Detect OS and architecture
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

# Map architecture
case "$ARCH" in
    x86_64) ARCH="amd64" ;;
    arm64|aarch64) ARCH="arm64" ;;
esac

# Determine platform and binary name
case "$OS" in
    darwin|macos)
        if [ "$ARCH" = "arm64" ]; then
            PLATFORM="macos-arm64"
        else
            PLATFORM="macos-x86_64"
        fi
        ;;
    linux)
        PLATFORM="linux-amd64"
        ;;
    *)
        echo "Error: Unsupported OS: $OS"
        echo "Supported platforms: macOS (arm64/x86_64), Linux (amd64)"
        exit 1
        ;;
esac

BINARY_NAME="torc-$PLATFORM"
INSTALL_PATH="/usr/local/bin/torc"

# Determine download URL
if [ "$VERSION" = "latest" ]; then
    # Try to get latest release
    if command -v curl >/dev/null 2>&1; then
        LATEST_TAG=$(curl -s "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' || echo "v0.1.0")
        VERSION="$LATEST_TAG"
    else
        VERSION="v0.1.0"
    fi
fi

DOWNLOAD_URL="https://github.com/$REPO_OWNER/$REPO_NAME/releases/download/$VERSION/$BINARY_NAME"

echo "Installing torc CLI..."
echo "  Platform: $PLATFORM"
echo "  Version: $VERSION"
echo "  URL: $DOWNLOAD_URL"
echo

# Download binary
TMP_FILE="/tmp/torc-$$"
if command -v curl >/dev/null 2>&1; then
    echo "Downloading..."
    curl -fsSL "$DOWNLOAD_URL" -o "$TMP_FILE" || {
        echo "Error: Failed to download binary"
        echo "Make sure the release exists at: $DOWNLOAD_URL"
        exit 1
    }
elif command -v wget >/dev/null 2>&1; then
    echo "Downloading..."
    wget -q "$DOWNLOAD_URL" -O "$TMP_FILE" || {
        echo "Error: Failed to download binary"
        echo "Make sure the release exists at: $DOWNLOAD_URL"
        exit 1
    }
else
    echo "Error: Need curl or wget to download binary"
    exit 1
fi

# Make executable
chmod +x "$TMP_FILE"

# Install to /usr/local/bin (requires sudo)
echo "Installing to $INSTALL_PATH..."
if [ -w "$(dirname "$INSTALL_PATH")" ]; then
    mv "$TMP_FILE" "$INSTALL_PATH"
else
    sudo mv "$TMP_FILE" "$INSTALL_PATH"
fi

echo
echo "✓ torc installed successfully!"
echo
echo "You can now run:"
echo "  torc install    # Install the Tea or Coffee server"
echo "  torc help       # Show all commands"
echo
