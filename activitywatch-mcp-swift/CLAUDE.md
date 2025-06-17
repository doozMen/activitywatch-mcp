# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is the ActivityWatch MCP (Model Context Protocol) Server written in Swift. It provides structured access to ActivityWatch time tracking data through AI assistants by wrapping the ActivityWatch REST API.

## Common Development Commands

### Setup and Dependencies

```bash
# Ensure ActivityWatch is running
# Default URL: http://localhost:5600

# Check if ActivityWatch is accessible
curl http://localhost:5600/api/0/info
```

### Code Quality and Testing

```bash
# Build in debug mode
swift build

# Run tests
swift test

# Build for release
swift build -c release

# Format code (if swift-format is installed)
swift-format -i Sources/**/*.swift
```

### Running the Server

```bash
# Run directly in debug mode
swift run activitywatch-mcp --log-level debug

# Run with custom server URL
swift run activitywatch-mcp --log-level debug --server-url http://localhost:5600

# Or use the built executable
.build/debug/activitywatch-mcp --log-level debug
```

### Installation

```bash
# Use the install script
./install-activitywatch-mcp.sh

# Or manually install
swift build -c release
swift package experimental-install
```

## Architecture

### Core Components

1. **ActivityWatchMCPServer** (`Sources/ActivityWatchMCP/ActivityWatchMCPServer.swift`)
   - Main MCP server implementation using Swift SDK
   - Handles all MCP protocol communication
   - Implements tool handlers with comprehensive error handling
   - Query format normalization for various MCP client inputs
   - Prompts support for guided workflows

2. **ActivityWatchAPI** (`Sources/ActivityWatchMCP/ActivityWatchAPI.swift`)
   - Actor-based HTTP client for ActivityWatch REST API
   - Uses AsyncHTTPClient for non-blocking I/O
   - Handles JSON encoding/decoding with AnyCodable for flexible data structures
   - Comprehensive error handling with typed errors

3. **ActivityWatchMCPCommand** (`Sources/ActivityWatchMCP/ActivityWatchMCPCommand.swift`)
   - CLI entry point using Swift Argument Parser
   - Configurable logging levels
   - Custom server URL support

### Tool Structure

Each tool follows this pattern:
1. Static tool definition with JSON schema
2. Handler function that extracts and validates parameters
3. API call through ActivityWatchAPI actor
4. Formatted response with error handling

Tools implemented:
- `list-buckets`: Lists all ActivityWatch buckets with optional filtering
- `run-query`: Executes AQL queries with format normalization
- `get-events`: Retrieves raw events from buckets
- `get-settings`: Accesses ActivityWatch settings
- `query-examples`: Provides AQL query examples

### Extension Pattern

To add new operations:
1. Add tool definition in `getStaticTools()` with proper schema
2. Add case in `handleToolCall()` switch statement
3. Implement handler function following existing patterns
4. Use ActivityWatchAPI for HTTP calls
5. Format responses consistently
6. Update version numbers in both command and server
7. Document in README.md

## Key Differences from TypeScript Version

1. **Concurrency Model**: Uses Swift actors instead of promises
2. **Type Safety**: Leverages Swift's strong typing throughout
3. **Error Handling**: Uses Swift's typed throws and Result types
4. **HTTP Client**: AsyncHTTPClient instead of axios
5. **JSON Handling**: AnyCodable wrapper for flexible JSON structures

## Version Management

When creating a new version:
1. Update version in `ActivityWatchMCPCommand.swift` (static configuration)
2. Update version in `ActivityWatchMCPServer.swift` (server initialization)
3. Update version in README.md
4. Commit with message format: `feat: Add [feature] - v[version]`

## Important Instructions

- Test changes with ActivityWatch running locally
- Use debug logging to troubleshoot issues
- Ensure proper error messages for common failures
- Follow Swift naming conventions and style
- Keep responses formatted for AI consumption
- Maintain compatibility with TypeScript version's tool interfaces

## Testing Notes

1. **Unit Tests**: Focus on API response parsing and error handling
2. **Integration Tests**: Require running ActivityWatch instance
3. **Manual Testing**: Use Claude Desktop with debug logging
4. **Error Cases**: Test with ActivityWatch stopped, invalid queries, etc.

## Common Issues and Solutions

1. **Connection Refused**: Ensure ActivityWatch is running
2. **Invalid Query Format**: Check query array structure and timeperiod format
3. **Empty Results**: Verify bucket names and time ranges
4. **JSON Parsing**: Use AnyCodable for flexible data structures

## Performance Considerations

- Actor isolation prevents race conditions
- HTTP client reuse for connection pooling
- Response size limits (1MB for lists, 10MB for queries)
- Timeout configuration for long-running queries