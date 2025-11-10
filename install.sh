#!/bin/bash
set -e

BUILD_CONFIG="${BUILD_CONFIG:-release}"

echo "🗑️  Removing existing installation if present..."
rm -f "$HOME/.swiftpm/bin/activitywatch"

echo "🔨 Building $BUILD_CONFIG version..."
swift build -c "$BUILD_CONFIG"

echo "📦 Installing activitywatch..."
swift package experimental-install

echo "✅ Installation complete!"
echo ""
echo "🔧 To use with Claude Desktop, add this to your config:"
echo ""
echo '"mcpServers": {'
echo '  "activitywatch": {'
echo '    "command": "activitywatch",'
echo '    "args": ["--log-level", "info"]'
echo '  }'
echo '}'
echo ""
echo "📍 Config location:"
echo "  macOS: ~/Library/Application Support/Claude/claude_desktop_config.json"
echo "  Linux: ~/.config/Claude/claude_desktop_config.json"
echo ""
echo "⚙️  Optional: Specify a custom ActivityWatch server URL:"
echo '  "args": ["--log-level", "info", "--server-url", "http://localhost:5600"]'
echo ""
echo "🖥️  CLI Usage:"
echo "  activitywatch --help     # Show help"
echo "  activitywatch --version  # Show version"