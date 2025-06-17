#!/bin/bash
set -e

echo "🔨 Building release version..."
swift build -c release

echo "🗑️  Removing existing installation if present..."
rm -f ~/.swiftpm/bin/activitywatch-mcp || true
rm -f /usr/local/bin/activitywatch-mcp || true

echo "📦 Installing activitywatch-mcp..."
swift package experimental-install

echo "✅ Installation complete!"
echo ""
echo "🔧 To use with Claude Desktop, add this to your config:"
echo ""
echo '"mcpServers": {'
echo '  "activitywatch": {'
echo '    "command": "activitywatch-mcp",'
echo '    "args": ["--log-level", "info"],'
echo '    "env": {'
echo '      "PATH": "'$HOME'/.swiftpm/bin:/usr/local/bin:/usr/bin:/bin"'
echo '    }'
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
echo "  activitywatch-mcp --help     # Show help"
echo "  activitywatch-mcp --version  # Show version"