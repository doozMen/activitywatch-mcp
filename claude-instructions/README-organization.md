# Claude Instructions for ActivityWatch MCP

This directory contains scripts, documentation, and test data that were moved to keep the main Swift package directory clean.

## Directory Structure

### `/scripts/`
Activity analysis and summary generation scripts:

**Production Scripts:**
- `claude-activity-summary.sh` - Two-step ActivityWatch analysis (markdown → JSON)
- `claude-activity-summary-with-markdown.sh` - Import both JSON + markdown to timestory-mcp
- `convert-analysis-to-json.sh` - Standalone converter for existing analyses

**Legacy/Development Scripts:**
- `activity-summary-final.sh` - Earlier iteration
- `activity-summary-two-step.sh` - Development version
- `activity-summary.sh` - Original prototype
- `complex-version.sh` - Full-featured version
- `direct-activity-summary.sh` - Direct approach attempt
- `json-activity-summary.sh` - JSON-focused approach

### `/config/`
Configuration files and templates:
- `claude-prompt-template.md` - Comprehensive prompt template for TimeStory schema analysis
- `mcp-activity-config.json` - MCP server configuration template

### `/test-data/`
Sample data files generated during development:
- `today.json` - Example structured output
- `today.md` - Example Claude analysis
- `data/` - Database files and test datasets

### Root Level Files
- `README.md` - Original development documentation
- `README-claude-summary.md` - Script usage guide

## Script Usage Guide

### Primary Workflow: `claude-activity-summary-with-markdown.sh`
```bash
# Generate and import today's analysis
./claude-instructions/scripts/claude-activity-summary-with-markdown.sh

# Analyze specific dates
./claude-instructions/scripts/claude-activity-summary-with-markdown.sh yesterday
./claude-instructions/scripts/claude-activity-summary-with-markdown.sh 2025-06-25
./claude-instructions/scripts/claude-activity-summary-with-markdown.sh "3 days ago"
```

**What it does:**
1. Collects ActivityWatch data for the specified date
2. Generates comprehensive Claude analysis (markdown)
3. Converts to structured JSON format
4. Imports BOTH JSON structure AND original markdown to timestory-mcp
5. Preserves all rich content while enabling structured queries

### Two-Step Workflow: `claude-activity-summary.sh`
```bash
# Generate analysis and JSON separately
./claude-instructions/scripts/claude-activity-summary.sh today

# Convert existing analysis
cat analysis.md | ./claude-instructions/scripts/convert-analysis-to-json.sh > output.json
```

## Main Swift Package
The main activitywatch-mcp directory now contains only:
- `Package.swift` - Swift package definition
- `Sources/` - Swift source code
- `Tests/` - Swift test files
- `README.md` - User documentation
- `CHANGELOG.md` - Version history
- `CLAUDE.md` - Project instructions for Claude Code
- `install.sh` - Installation script
- `LICENSE` - License file

This organization keeps the Swift package clean while preserving all development scripts and documentation for future reference.

## Integration with TimeStory MCP
These scripts work together with the timestory-mcp package to provide a complete activity tracking and analysis pipeline:

1. **ActivityWatch MCP** - Collects and processes activity data
2. **Claude CLI** - Generates rich analysis and insights
3. **TimeStory MCP** - Stores both structured data and original analysis
4. **Combined Workflow** - Seamless end-to-end productivity tracking

## Version History
Scripts evolved from simple data collection to comprehensive analysis with markdown preservation, matching the development of the rich import functionality in timestory-mcp v1.8.0+.