#!/bin/bash

# ActivityWatch MCP Version Bump Script
# Usage: ./bump-version.sh <new-version>
# Example: ./bump-version.sh 2.6.0
# Example: ./bump-version.sh 2.7.0-beta.1

set -e

if [ $# -ne 1 ]; then
    echo "Usage: $0 <new-version>"
    echo ""
    echo "Examples:"
    echo "  $0 2.6.0              # Bump to stable release"
    echo "  $0 2.7.0-beta.1       # Bump to beta release"
    echo "  $0 3.0.0-alpha.1      # Bump to alpha release"
    echo ""
    echo "Version will be updated in:"
    echo "  - .claude-plugin/plugin.json (plugin version)"
    echo "  - Sources/ActivityWatchMCP/ActivityWatchMCPCommand.swift (CLI version)"
    echo "  - Sources/ActivityWatchMCP/ActivityWatchMCPServer.swift (server version)"
    exit 1
fi

NEW_VERSION=$1

# Validate version format (basic check)
if ! [[ $NEW_VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]]; then
    echo "Error: Invalid version format: $NEW_VERSION"
    echo "Expected format: X.Y.Z or X.Y.Z-prerelease (e.g., 2.6.0, 2.6.0-alpha.1)"
    exit 1
fi

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Update plugin.json
PLUGIN_JSON="$CURRENT_DIR/.claude-plugin/plugin.json"
if [ -f "$PLUGIN_JSON" ]; then
    sed -i '' "s/\"version\": \"[^\"]*\"/\"version\": \"$NEW_VERSION\"/" "$PLUGIN_JSON"
    echo "✓ Updated plugin.json to version $NEW_VERSION"
else
    echo "⚠ Warning: plugin.json not found at $PLUGIN_JSON"
fi

# Update ActivityWatchMCPCommand.swift
COMMAND_SWIFT="$CURRENT_DIR/Sources/ActivityWatchMCP/ActivityWatchMCPCommand.swift"
if [ -f "$COMMAND_SWIFT" ]; then
    sed -i '' "s/version: \"[^\"]*\"/version: \"$NEW_VERSION\"/" "$COMMAND_SWIFT"
    echo "✓ Updated ActivityWatchMCPCommand.swift to version $NEW_VERSION"
else
    echo "⚠ Warning: ActivityWatchMCPCommand.swift not found at $COMMAND_SWIFT"
fi

# Update ActivityWatchMCPServer.swift
SERVER_SWIFT="$CURRENT_DIR/Sources/ActivityWatchMCP/ActivityWatchMCPServer.swift"
if [ -f "$SERVER_SWIFT" ]; then
    sed -i '' "s/private let version = \"[^\"]*\"/private let version = \"$NEW_VERSION\"/" "$SERVER_SWIFT"
    echo "✓ Updated ActivityWatchMCPServer.swift to version $NEW_VERSION"
else
    echo "⚠ Warning: ActivityWatchMCPServer.swift not found at $SERVER_SWIFT"
fi

echo ""
echo "Version bump complete! ✨"
echo "New version: $NEW_VERSION"
echo ""
echo "Next steps:"
echo "  1. Review changes: git diff"
echo "  2. Commit changes: git add . && git commit -m 'chore: Bump version to $NEW_VERSION'"
echo "  3. Create git tag: git tag v$NEW_VERSION"
echo "  4. Build: swift build -c release"
echo "  5. Install: ./install.sh"
