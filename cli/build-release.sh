#!/bin/bash
set -e

# Build script for creating standalone torc binaries
# This builds optimized release binaries for distribution

PLATFORM="${1:-$(uname -s | tr '[:upper:]' '[:lower:]')}"
ARCH="${2:-$(uname -m)}"

echo "Building torc for $PLATFORM/$ARCH..."
echo

cd "$(dirname "$0")"

# Build the binary
swift build -c release

# Get the built binary path
BINARY_PATH=".build/release/torc"
OUTPUT_DIR="dist"
mkdir -p "$OUTPUT_DIR"

# Determine output filename
case "$PLATFORM" in
    darwin|macos)
        if [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then
            OUTPUT_NAME="torc-macos-arm64"
        else
            OUTPUT_NAME="torc-macos-x86_64"
        fi
        ;;
    linux)
        OUTPUT_NAME="torc-linux-amd64"
        ;;
    *)
        echo "Unknown platform: $PLATFORM"
        exit 1
        ;;
esac

# Copy binary to dist directory
cp "$BINARY_PATH" "$OUTPUT_DIR/$OUTPUT_NAME"
chmod +x "$OUTPUT_DIR/$OUTPUT_NAME"

echo "✓ Binary built: $OUTPUT_DIR/$OUTPUT_NAME"
echo
echo "Binary size: $(du -h "$OUTPUT_DIR/$OUTPUT_NAME" | cut -f1)"
echo
echo "Note: This binary requires Swift runtime libraries."
echo "For macOS: Usually pre-installed or available via Xcode Command Line Tools"
echo "For Linux: May need Swift runtime installed, or use static linking"
echo
echo "To create a more portable binary, consider:"
echo "  1. Using swift-bundler (https://github.com/stackotter/swift-bundler)"
echo "  2. Building with static linking flags (limited support)"
echo "  3. Bundling Swift runtime libraries with the binary"
