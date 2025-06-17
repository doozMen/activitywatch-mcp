#!/bin/bash

# Install script for ActivityWatch MCP server
echo "Installing ActivityWatch MCP server..."

# Build in release mode
echo "Building in release mode..."
swift build -c release

# Install using swift package experimental-install
echo "Installing to /usr/local/bin..."
swift package experimental-install

echo "Installation complete!"
echo "You can now use 'activitywatch-mcp' from anywhere in your terminal."