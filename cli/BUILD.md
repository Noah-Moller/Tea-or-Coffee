# Building Standalone Binaries for torc

This guide explains how to build standalone `torc` binaries that can be distributed to users without requiring Swift to be installed.

## Quick Start

### Build for Current Platform

```bash
cd cli
./build-release.sh
```

This creates a binary in `dist/` directory.

### Build for Specific Platform

```bash
./build-release.sh linux amd64
./build-release.sh darwin arm64
./build-release.sh darwin x86_64
```

## Distribution Options

### Option 1: Pre-built Binaries (Recommended)

1. **Build binaries for all platforms:**
   ```bash
   # On macOS (arm64)
   ./build-release.sh darwin arm64
   
   # On macOS (x86_64) or use Docker
   ./build-release.sh darwin x86_64
   
   # On Linux or use Docker
   ./build-release.sh linux amd64
   ```

2. **Upload to GitHub Releases:**
   - Create a new release (e.g., `v0.1.0`)
   - Upload the binaries from `dist/`:
     - `torc-macos-arm64`
     - `torc-macos-x86_64`
     - `torc-linux-amd64`

3. **Users install with one command:**
   ```bash
   curl -fsSL https://raw.githubusercontent.com/your-username/tea-or-coffee/main/cli/install.sh | bash
   ```

### Option 2: Static Linking (Advanced)

For truly standalone binaries that don't require Swift runtime:

**macOS:**
```bash
swift build -c release \
  -Xswiftc -static-stdlib \
  -Xlinker -static
```

**Linux:**
```bash
swift build -c release \
  -Xswiftc -static-stdlib \
  -Xlinker -static
```

**Note:** Static linking has limitations and may not work for all Swift features.

### Option 3: Using swift-bundler

For creating app bundles with embedded Swift runtime:

1. Install [swift-bundler](https://github.com/stackotter/swift-bundler)
2. Create a bundle configuration
3. Build with bundler

## CI/CD Build Script

For automated builds, here's a GitHub Actions example:

```yaml
name: Build torc binaries

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, macos-12, macos-13]
    steps:
      - uses: actions/checkout@v3
      - name: Setup Swift
        uses: swift-actions/setup-swift@v1
      - name: Build
        run: |
          cd cli
          ./build-release.sh
      - name: Upload artifact
        uses: actions/upload-artifact@v3
        with:
          name: torc-${{ matrix.os }}
          path: cli/dist/*
```

## Runtime Requirements

### macOS
- Swift runtime is usually pre-installed on macOS 13+
- If not, users can install Xcode Command Line Tools: `xcode-select --install`

### Linux
- Users may need Swift runtime libraries installed
- Or use static linking (see Option 2 above)
- Or bundle runtime libraries with the binary

## Testing the Binary

After building, test that it works:

```bash
# Test help command
./dist/torc-macos-arm64 help

# Test on a clean system (without Swift installed)
# Copy binary to a test machine and verify it runs
```

## File Sizes

Typical binary sizes:
- macOS arm64: ~2-3 MB
- macOS x86_64: ~2-3 MB  
- Linux amd64: ~2-3 MB

With static linking, binaries may be larger (5-10 MB) but are fully standalone.
