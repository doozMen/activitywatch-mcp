# Changelog

All notable changes to the ActivityWatch MCP Server Swift implementation will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.5.1] - 2025-11-09

### Fixed
- Fixed plugin.json validation issues for Claude Code marketplace
  - Changed repository field to use HTTPS URL format
  - Removed unsupported schema fields (schemaVersion, homepage, bugs, keywords, categories)
  - Plugin now passes Claude Code marketplace validation

## [2.5.0] - 2025-10-08

### Added
- **Comprehensive Integration Test Suite**: 91 tests covering all MCP tools and core functionality
  - **APIClientTests.swift** (23 tests): REST API communication, error handling, concurrent operations
  - **FolderActivityTests.swift** (21 tests): Folder extraction from window titles for 15+ applications
  - **QueryFormatTests.swift** (31 tests): Natural language and ISO 8601 date parsing
  - **MCPToolTests.swift** (16 tests): All 9 MCP tools with real-world workflows

### Technical Details
- Tests run against live ActivityWatch instance on localhost:5600
- Comprehensive folder extraction support for Terminal (Warp, iTerm), IDEs (Cursor, VSCode, Xcode, JetBrains), and Finder
- Natural language date parsing with SwiftDateParser integration
- 100% test pass rate with ~30 second execution time
- Swift 6.0 strict concurrency compliant with zero warnings
- Actor-based concurrency ensures thread-safe operations

## [2.4.1] - 2025-06-19

### Fixed
- Made `end` parameter truly optional in tool schemas (removed from required arrays)
- Added automatic handling for common AI mistakes like providing `end="now"` with `start="today"`
- Improved tool descriptions with explicit warnings about not adding `end` parameter for single day queries
- Better error messages and logging when AI provides incorrect parameters

### Changed
- Tool descriptions now emphasize that `end` parameter should be omitted for single day queries
- Added logic to ignore `end="now"` when used with single period queries like "today" or "yesterday"

## [2.4.0] - 2025-06-19

### Added
- Natural language date parsing support via SwiftDateParser integration
- All date parameters now accept natural language inputs like:
  - "today", "yesterday", "tomorrow"
  - "3 days ago", "last week", "this month"
  - "2 hours ago", "last monday"
- Backward compatibility with ISO 8601 date formats
- DateParsingHelper utility for consistent date handling across all tools
- Smart defaults: omitting end date defaults to end of start day

### Changed
- Updated all tool descriptions to document natural language date support
- Enhanced README with comprehensive date formatting guide
- Improved error handling by removing force unwraps

### Fixed
- Independent date parsing for get-events tool (start and end dates are now parsed separately)
- Proper error handling for date calculation failures

## [2.3.1] - 2025-06-17

### Added
- New `get-version` tool to retrieve MCP server version information

### Improved
- Folder paths are now resolved to absolute paths when possible
- Added intelligent path resolution that checks common development directories:
  - ~/Developer, ~/Documents, ~/Projects, ~/Code, ~/dev, ~/src, ~/workspace
- Better handling of terminal paths including tilde expansion
- Improved extraction of full paths from editor window titles
- Finder folders are now resolved to their likely absolute locations
- Updated install script to include PATH environment variable in MCP configuration

## [2.3.0] - 2025-06-17

### Added
- New `get-folder-activity` tool that analyzes window titles to extract and summarize local folder activity
- `FolderActivityAnalyzer` actor for intelligent folder name extraction from different applications
- Support for extracting folder names from:
  - Terminal applications (Warp, iTerm, Terminal, etc.) with context support (e.g., "folder = context")
  - Code editors (Cursor, VSCode, Xcode, JetBrains IDEs)
  - File managers (Finder, Path Finder)
  - Web browsers (optional, for web-based folders)
- Time tracking and event counting for each folder
- Grouped folder activity reports by application
- Top 10 most active folders summary

### Improved
- Better folder name extraction patterns for terminal applications
- Support for relative path indicators (..folder/subfolder)
- Context extraction from terminal titles

## [2.2.0] - 2025-06-12

### Added
- `active-folders` tool to extract folder paths from window titles
- `active-buckets` tool to find buckets with activity in a time range

## [2.1.0] - 2025-06-11

### Added
- Query normalization for better compatibility with different MCP clients
- Prompts support for guided workflows
- Better error messages

## [2.0.0] - 2025-06-10

### Changed
- Complete rewrite in Swift from TypeScript
- Actor-based concurrency model
- Native macOS performance

### Added
- All core ActivityWatch tools:
  - `list-buckets`
  - `run-query`
  - `get-events`
  - `get-settings`
  - `query-examples`

[Unreleased]: https://github.com/doozMen/activitywatch-mcp/compare/v2.5.1...HEAD
[2.5.1]: https://github.com/doozMen/activitywatch-mcp/compare/v2.5.0...v2.5.1
[2.5.0]: https://github.com/doozMen/activitywatch-mcp/compare/v2.4.1...v2.5.0
[2.4.1]: https://github.com/doozMen/activitywatch-mcp/compare/v2.4.0...v2.4.1
[2.4.0]: https://github.com/doozMen/activitywatch-mcp/compare/v2.3.1...v2.4.0
[2.3.1]: https://github.com/doozMen/activitywatch-mcp/compare/v2.3.0...v2.3.1
[2.3.0]: https://github.com/doozMen/activitywatch-mcp/compare/v2.2.0...v2.3.0
[2.2.0]: https://github.com/doozMen/activitywatch-mcp/compare/v2.1.0...v2.2.0
[2.1.0]: https://github.com/doozMen/activitywatch-mcp/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/doozMen/activitywatch-mcp/releases/tag/v2.0.0