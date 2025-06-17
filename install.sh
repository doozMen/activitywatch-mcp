#!/bin/bash

# Installation script for ActivityWatch MCP Swift server

set -e

echo "Installing ActivityWatch MCP Swift server..."

# Get the SwiftPM directory
SWIFTPM_DIR="$HOME/.swiftpm/bin"

# Get the executable product name from Package.swift
EXECUTABLE_NAME=$(swift package describe --type json | jq -r '.products[0].name')

# Remove existing executable if it exists
if [ -f "$SWIFTPM_DIR/$EXECUTABLE_NAME" ]; then
    echo "Removing existing executable at $SWIFTPM_DIR/$EXECUTABLE_NAME"
    rm -f "$SWIFTPM_DIR/$EXECUTABLE_NAME"
fi

# Build first to ensure we have the latest version
echo "Building latest version..."
swift build -c release

# Get the version from the binary if possible
if [ -f ".build/release/$EXECUTABLE_NAME" ]; then
    echo "Built version: $(.build/release/$EXECUTABLE_NAME --version 2>/dev/null || echo 'version info not available')"
fi

# Install using swift package experimental-install without sudo
echo "Installing to $SWIFTPM_DIR..."
swift package experimental-install --product "$EXECUTABLE_NAME"

# Verify installation
if [ -f "$SWIFTPM_DIR/$EXECUTABLE_NAME" ]; then
    echo "✅ Installation successful!"
    echo ""
    echo "Executable installed at:"
    echo "  - $SWIFTPM_DIR/$EXECUTABLE_NAME"
    echo ""
    echo "Installed version:"
    "$SWIFTPM_DIR/$EXECUTABLE_NAME" --version 2>/dev/null || echo "  (version check not available)"
    echo ""
    echo "To use with Claude Desktop, add this to your claude_desktop_config.json:"
    echo ""
    echo '{'
    echo '  "mcpServers": {'
    echo '    "activitywatch-mcp": {'
    echo '      "type": "stdio",'
    echo '      "command": "'$SWIFTPM_DIR/$EXECUTABLE_NAME'",'
    echo '      "args": ["--log-level", "info"]'
    echo '    }'
    echo '  }'
    echo '}'
    echo ""
    echo "📍 Config file locations:"
    echo "  - macOS: ~/Library/Application Support/Claude/claude_desktop_config.json"
    echo "  - Linux: ~/.config/Claude/claude_desktop_config.json"
    echo ""
    echo "⚙️  Optional: Specify a custom ActivityWatch server URL:"
    echo '      "args": ["--log-level", "info", "--server-url", "http://localhost:5600"]'
    echo ""
    
    # Note about testing
    echo "To test the installation, run:"
    echo "  $EXECUTABLE_NAME --help"
    echo ""
    echo "To verify ActivityWatch connection:"
    echo "  $EXECUTABLE_NAME --version"
else
    echo "❌ Installation failed!"
    exit 1
fi