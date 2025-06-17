# ActivityWatch MCP Server (Swift)

[![MCP](https://img.shields.io/badge/MCP-1.0.2-blue)](https://modelcontextprotocol.io)
[![Swift](https://img.shields.io/badge/Swift-6.0+-orange)](https://swift.org)
[![macOS](https://img.shields.io/badge/macOS-15.0+-blue)](https://www.apple.com/macos/)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

A Swift implementation of the Model Context Protocol (MCP) server for [ActivityWatch](https://activitywatch.net/), providing structured access to time tracking data for AI assistants.

## 🌟 What's New in v2.3.0

The `get-folder-activity` tool provides intelligent folder activity analysis by extracting folder names from:
- Terminal applications (with context support like "project = side-project")
- Code editors (VSCode, Xcode, Cursor, JetBrains IDEs)
- File managers (Finder, Path Finder)
- Web browsers (optional)

## 🚀 Features

- **List Buckets**: Browse all ActivityWatch data buckets with optional filtering
- **Active Buckets**: Find which buckets have activity within a time range
- **Active Folders**: Extract unique folder paths from window titles
- **Get Folder Activity**: Analyze and summarize local folder activity with time tracking
- **Run Queries**: Execute powerful AQL (ActivityWatch Query Language) queries
- **Get Events**: Retrieve raw events from specific buckets with time filtering
- **Get Settings**: Access ActivityWatch configuration
- **Query Examples**: Built-in examples for common queries
- **Productivity Prompts**: Guided workflows for productivity analysis

## 📋 Prerequisites

- macOS 15.0+
- Swift 6.0+
- [ActivityWatch](https://activitywatch.net/) running locally
- Swift Package Manager

## 🛠️ Installation

### Quick Install

```bash
./install.sh
```

### Manual Installation

```bash
# Build the project
swift build -c release

# Install to system
swift package experimental-install
```

## ⚙️ Configuration

Add to your Claude Desktop configuration file:

**macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`  
**Linux**: `~/.config/Claude/claude_desktop_config.json`

```json
{
  "mcpServers": {
    "activitywatch-mcp": {
      "command": "~/.swiftpm/bin/activitywatch-mcp",
      "args": ["--log-level", "info"]
    }
  }
}
```

### Options

- `--log-level`: Set logging level (debug, info, warning, error, critical)
- `--server-url`: Custom ActivityWatch server URL (default: http://localhost:5600)

## 📖 Usage Examples

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

### Active Buckets
```
Use active-buckets tool with:
- start: "2024-01-01T00:00:00Z"
- end: "2024-01-02T00:00:00Z"
- Optional: min_events (default: 1)
```

### Active Folders
```
Use active-folders tool with:
- start: "2024-01-01T00:00:00Z"
- end: "2024-01-02T00:00:00Z"
- Optional: bucket_filter (to filter bucket IDs)

Extracts folder paths from window titles in file managers, terminals, and editors.
```

### Get Folder Activity
```
Use get-folder-activity tool with:
- start: "2024-01-01T00:00:00Z"
- end: "2024-01-02T00:00:00Z"
- Optional: includeWeb (include web URLs as folders, default: false)
- Optional: minDuration (minimum seconds to consider active, default: 5)

Provides a comprehensive summary of local folder activity including:
- Time spent in each folder
- Number of events per folder
- Folders grouped by application
- Context extraction from terminal titles (e.g., "project = side-project")
- Top 10 most active folders
```

### Query Examples
```
Use query-examples tool to see common AQL patterns
```

## 🔧 Development

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

## 🏗️ Architecture

The server is built with:
- Swift 6.0 with async/await
- MCP Swift SDK for protocol implementation
- AsyncHTTPClient for ActivityWatch API communication
- Actor-based concurrency for thread safety

## 📝 AQL Query Examples

The server includes built-in query examples accessible through the `query-examples` tool, including:
- Basic window and AFK queries
- Application-specific filtering
- Time calculations per application
- Productivity vs unproductive time analysis
- Combined window and AFK data analysis

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [ActivityWatch](https://activitywatch.net/) for the amazing time tracking platform
- [Model Context Protocol](https://modelcontextprotocol.io/) for the MCP specification
- Original [TypeScript implementation](https://github.com/8bitgentleman/activitywatch-mcp-server) by 8bitgentleman

## 🔗 Related Projects

- [ActivityWatch](https://github.com/ActivityWatch/activitywatch) - The time tracking application
- [MCP Swift SDK](https://github.com/modelcontextprotocol/swift-sdk) - Swift SDK for Model Context Protocol