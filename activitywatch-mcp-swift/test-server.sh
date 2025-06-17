#!/bin/bash

# Test script for ActivityWatch MCP server
echo "Testing ActivityWatch MCP server..."

# Start the server and send a test request
echo '{"jsonrpc":"2.0","method":"tools/list","id":1}' | .build/debug/activitywatch-mcp --log-level debug 2>&1 | head -20

echo ""
echo "If you see a valid JSON-RPC response with a list of tools, the server is working correctly."