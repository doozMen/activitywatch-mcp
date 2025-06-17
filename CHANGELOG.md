# Changelog

All notable changes to the ActivityWatch MCP Server Swift implementation will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.3.1] - 2025-06-17

### Improved
- Folder paths are now resolved to absolute paths when possible
- Added intelligent path resolution that checks common development directories:
  - ~/Developer, ~/Documents, ~/Projects, ~/Code, ~/dev, ~/src, ~/workspace
- Better handling of terminal paths including tilde expansion
- Improved extraction of full paths from editor window titles
- Finder folders are now resolved to their likely absolute locations

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