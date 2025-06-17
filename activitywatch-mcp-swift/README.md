# ActivityWatch MCP Server (Swift)

[![MCP](https://img.shields.io/badge/MCP-1.0.2-blue)](https://modelcontextprotocol.io)

A Swift implementation of the Model Context Protocol (MCP) server for ActivityWatch, providing structured access to time tracking data for AI assistants.

## Features

- **List Buckets**: Browse all ActivityWatch data buckets with optional filtering
- **Run Queries**: Execute powerful AQL (ActivityWatch Query Language) queries
- **Get Events**: Retrieve raw events from specific buckets with time filtering
- **Get Settings**: Access ActivityWatch configuration
- **Query Examples**: Built-in examples for common queries
- **Productivity Prompts**: Guided workflows for productivity analysis

## Prerequisites

- macOS 15.0+
- Swift 6.0+
- [ActivityWatch](https://activitywatch.net/) running locally
- Swift Package Manager

## Installation

### Quick Install

```bash
./install-activitywatch-mcp.sh
```

### Manual Installation

```bash
# Build the project
swift build -c release

# Install to system
swift package experimental-install
```

## Configuration

Add to your Claude Desktop configuration:

```json
{
  "mcpServers": {
    "activitywatch-mcp": {
      "command": "activitywatch-mcp",
      "args": ["--log-level", "info"]
    }
  }
}
```

### Options

- `--log-level`: Set logging level (debug, info, warning, error, critical)
- `--server-url`: Custom ActivityWatch server URL (default: http://localhost:5600)

## Usage

### List Buckets
```
Use the list-buckets tool to see available data sources
Optional: filter by type (e.g., "window", "afk")
```

### Run Queries
```
Use run-query tool with:
- timeperiods: ["2024-01-01T00:00:00+00:00/2024-01-02T00:00:00+00:00"]
- query: ["events = query_bucket('aw-watcher-window_hostname'); RETURN = events;"]
```

### Get Events
```
Use get-events tool with:
- bucket_id: "aw-watcher-window_hostname"
- Optional: limit, start, end times
```

### Query Examples
```
Use query-examples tool to see common AQL patterns
```

## Development

### Building

```bash
swift build
```

### Running in Debug Mode

```bash
swift run activitywatch-mcp --log-level debug
```

### Testing

```bash
swift test
```

## Architecture

The server is built with:
- Swift 6.0 with async/await
- MCP Swift SDK for protocol implementation
- AsyncHTTPClient for ActivityWatch API communication
- Actor-based concurrency for thread safety

## Differences from TypeScript Version

This Swift implementation maintains feature parity with the original TypeScript version while leveraging Swift's:
- Strong type safety
- Actor-based concurrency model
- Native performance
- Better error handling with Swift's Result types

## License

MIT License - see LICENSE file for details