# ActivityWatch MCP Server (Swift)

[![MCP](https://img.shields.io/badge/MCP-1.0.2-blue)](https://modelcontextprotocol.io)
[![Swift](https://img.shields.io/badge/Swift-6.0+-orange)](https://swift.org)
[![macOS](https://img.shields.io/badge/macOS-15.0+-blue)](https://www.apple.com/macos/)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

A Swift implementation of the Model Context Protocol (MCP) server for [ActivityWatch](https://activitywatch.net/), providing structured access to time tracking data for AI assistants.

## 🌟 What's New in v2.3.1

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
- start: "today" or "yesterday" or "3 days ago"
- end: Optional (defaults to end of start day)
- Optional: min_events (default: 1)

Examples:
- start="today" - Today's active buckets
- start="yesterday" - Yesterday's data
- start="this week" - This week's activity
```

### Active Folders
```
Use active-folders tool with:
- start: Natural language or ISO 8601 date
- end: Optional
- Optional: bucket_filter (to filter bucket IDs)

Examples:
- start="today" - Today's folder access
- start="2 hours ago", end="now" - Recent folders
- start="last monday" - Since last Monday

Extracts folder paths from window titles in file managers, terminals, and editors.
```

### Get Folder Activity
```
Use get-folder-activity tool with:
- start: Natural language or ISO 8601 date
- end: Optional
- Optional: includeWeb (include web URLs as folders, default: false)
- Optional: minDuration (minimum seconds to consider active, default: 5)

Examples:
- start="yesterday" - Yesterday's folder activity
- start="this week" - This week's folders
- start="monday", end="friday" - Work week activity

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

## 📅 Date and Time Formatting Guide

ActivityWatch uses ISO 8601 format for all date and time parameters. Here's a comprehensive guide:

### Basic Format
All dates must be in ISO 8601 format with timezone information:
- **Full format**: `YYYY-MM-DDTHH:MM:SSZ` or `YYYY-MM-DDTHH:MM:SS+HH:MM`
- **Date part**: Year-Month-Day
- **Time part**: Hour:Minute:Second
- **Separator**: Use `T` between date and time
- **Timezone**: Use `Z` for UTC or `+HH:MM`/`-HH:MM` for offset

### Relative Date Examples

When instructing AI assistants to query ActivityWatch, use these relative date descriptions:

#### Common Time Periods
```
- "Get today's activities" → start: today at 00:00:00Z, end: today at 23:59:59Z
- "Show yesterday's data" → start: yesterday at 00:00:00Z, end: yesterday at 23:59:59Z
- "Last 7 days" → start: 7 days ago at 00:00:00Z, end: today at 23:59:59Z
- "This week" → start: Monday of this week at 00:00:00Z, end: Sunday at 23:59:59Z
- "Last month" → start: first day of last month at 00:00:00Z, end: last day of last month at 23:59:59Z
```

#### Examples by Timezone

##### UTC (Recommended)
```
- Today at midnight: <current_date>T00:00:00Z
- Today at noon: <current_date>T12:00:00Z
- Today at 11:59 PM: <current_date>T23:59:59Z
```

##### With Timezone Offset
```
- Eastern Time (EST, -05:00): <current_date>T09:00:00-05:00
- Central European Time (CET, +01:00): <current_date>T09:00:00+01:00
- Japan Standard Time (JST, +09:00): <current_date>T09:00:00+09:00
```

### Common Query Patterns

#### Get Today's Data (UTC)
```json
{
  "start": "<today>T00:00:00Z",
  "end": "<today>T23:59:59Z"
}
```

#### Get This Week's Data
```json
{
  "start": "<monday_of_this_week>T00:00:00Z",
  "end": "<sunday_of_this_week>T23:59:59Z"
}
```

#### Get Last 7 Days
```json
{
  "start": "<7_days_ago>T00:00:00Z",
  "end": "<today>T23:59:59Z"
}
```

### For AQL Queries
The `run-query` tool uses a slightly different format for time periods:
```json
{
  "timeperiods": ["<start_date>T00:00:00+00:00/<end_date>T00:00:00+00:00"],
  "query": ["..."]
}
```

Note the:
- Use of `+00:00` instead of `Z` for UTC
- Periods are separated by `/`
- Multiple periods can be specified in the array

### Tips
1. **Always include timezone** - Never omit the timezone designator
2. **Use UTC when possible** - Simplifies calculations and avoids DST issues
3. **Be consistent** - Stick to one format throughout your queries
4. **Check your system time** - Ensure your computer's clock is correctly set

### Natural Language Date Support
This MCP server integrates [SwiftDateParser](https://github.com/doozMen/dateutil-swift) to support natural language date queries:
- "Show me what I did yesterday"
- "Get activities from last Monday"  
- "Summary of 3 days ago"
- "What did I work on this week"
- "Show folders accessed 2 hours ago"

All date parameters in tools support both natural language and ISO 8601 formats.

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