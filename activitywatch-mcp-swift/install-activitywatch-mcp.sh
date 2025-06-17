#!/bin/bash
set -e

echo "🔨 Building ActivityWatch MCP Server..."
swift build -c release

echo "🗑️  Removing existing installation if present..."
rm -f ~/.swiftpm/bin/activitywatch-mcp || true

echo "📦 Installing activitywatch-mcp..."
swift package experimental-install

echo "✅ Installation complete!"
echo ""
echo "🔧 To use with Claude Desktop, add this to your config:"
echo ""
echo "\"mcpServers\": {"
echo "  \"activitywatch-mcp\": {"
echo "    \"command\": \"activitywatch-mcp\","
echo "    \"args\": [\"--log-level\", \"info\"]"
echo "  }"
echo "}"
echo ""
echo "📍 Config location:"
echo "  macOS: ~/Library/Application Support/Claude/claude_desktop_config.json"
echo "  Linux: ~/.config/Claude/claude_desktop_config.json"
echo ""
echo "⚙️  Optional: Specify a custom ActivityWatch server URL:"
echo "    \"args\": [\"--log-level\", \"info\", \"--server-url\", \"http://localhost:5600\"]"