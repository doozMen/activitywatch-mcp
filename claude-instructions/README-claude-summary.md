# Claude Activity Summary Tool

A comprehensive daily activity summarization tool that collects data from ActivityWatch and related MCP servers, analyzes it with Claude CLI, and outputs TimeStory-compatible JSON for productivity tracking.

## 🌟 Features

- **Multi-Source Data Collection**: Integrates ActivityWatch, health metrics, development tools, voice transcriptions, and context annotations
- **AI-Powered Analysis**: Uses Claude CLI to intelligently analyze activity patterns and generate insights
- **TimeStory Compatible**: Outputs JSON that matches the TimeStory import schema exactly
- **Natural Language Dates**: Supports "today", "yesterday", "3 days ago", "last monday"
- **Robust Error Handling**: Gracefully handles missing services and produces valid output
- **Comprehensive Validation**: Ensures schema compliance and data integrity

## 🛠️ Prerequisites

### Required
- **macOS 15.0+** (for date parsing and MCP servers)
- **jq** - JSON processor (`brew install jq`)
- **Claude CLI** - Anthropic's command-line interface
- **ActivityWatch** - Running locally (http://localhost:5600)

### Optional MCP Servers
The tool will work with any subset of these MCP servers:
- `activitywatch-mcp` - Core ActivityWatch integration
- `aw-context-mcp` - Context annotations
- `wispr-flow-mcp` - Voice transcriptions
- `git-mcp` - Local Git activity
- `gitlab-mcp-swift` - GitLab integration  
- `vital-flow-mcp` - Health metrics from Apple Health

## 📦 Installation

1. **Download the tool**:
   ```bash
   # The script is located in the activitywatch-mcp directory
   cd /path/to/activitywatch-mcp
   ```

2. **Make executable**:
   ```bash
   chmod +x claude-activity-summary.sh
   ```

3. **Verify prerequisites**:
   ```bash
   ./claude-activity-summary.sh --help
   ```

## 🚀 Usage

### Basic Usage
```bash
# Today's summary
./claude-activity-summary.sh

# Yesterday's summary  
./claude-activity-summary.sh yesterday

# Custom date
./claude-activity-summary.sh "3 days ago"
./claude-activity-summary.sh "last monday"
```

### Save to File
```bash
# Generate and save summary
./claude-activity-summary.sh today > daily_summary_2025-06-26.json

# Import into TimeStory (via MCP)
# Use the timestory-mcp import_timestory tool with the generated JSON
```

### Verbose Output
```bash
# See detailed collection process
./claude-activity-summary.sh today 2>&1 | tee collection.log
```

## 📋 Output Structure

The tool generates JSON matching the TimeStory import schema:

```json
{
  "date": "2025-06-26",
  "timezone": "Europe/Brussels",
  "timeSummary": {
    "startTime": "09:00",
    "endTime": "18:30",
    "totalDurationMinutes": 570,
    "billableHours": 7.5,
    "sideProjectHours": 1.5,
    "breakTimeMinutes": 60
  },
  "healthMetrics": {
    "steps": 8500,
    "restingHeartRate": 65,
    "healthScore": 82,
    "dataAvailable": true
  },
  "gitlabActivity": {
    "commits": [...],
    "totalCommits": 3,
    "projectsWorkedOn": ["project-a", "project-b"]
  },
  "timelinePhases": [
    {
      "startTime": "09:00",
      "endTime": "10:30",
      "title": "ActivityWatch MCP Development",
      "category": "side_project",
      "durationMinutes": 90
    }
  ],
  "achievements": [
    {
      "type": "primary",
      "title": "Completed Claude Summary Tool",
      "description": "Built comprehensive activity analysis tool"
    }
  ],
  "activityDistribution": {
    "development": 240,
    "communication": 60,
    "documentation": 30
  },
  "folderActivity": {
    "activeFolders": [...]
  },
  "insights": [
    {
      "title": "High Focus Period",
      "category": "productivity",
      "description": "Peak productivity 10:00-12:00"
    }
  ]
}
```

## 🔧 Configuration

### Environment Variables
```bash
# Optional: Override ActivityWatch server
export ACTIVITYWATCH_HOST="http://localhost:5600"

# Optional: Set timezone  
export TZ="Europe/Brussels"
```

### MCP Server Configuration
Ensure MCP servers are configured in Claude Desktop:
```json
{
  "mcpServers": {
    "activitywatch-mcp": {
      "command": "~/.swiftpm/bin/activitywatch-mcp",
      "args": ["--log-level", "info"]
    },
    "timestory-mcp": {
      "command": "~/.swiftpm/bin/timestory-mcp",
      "args": ["--log-level", "info"]
    }
  }
}
```

## 🧠 Analysis Process

1. **Data Collection**:
   - ActivityWatch: Folder activity, window events, AFK data
   - Context: Timestamped annotations and tags
   - Health: Steps, heart rate, sleep quality
   - Development: Git commits, GitLab activity
   - Voice: Transcriptions and commands

2. **Claude Analysis**:
   - Categorizes activities (client work vs side projects)
   - Identifies productivity patterns
   - Generates achievements and insights
   - Calculates time distributions
   - Creates timeline phases

3. **Schema Mapping**:
   - Validates TimeStory compatibility
   - Ensures required fields
   - Formats dates/times correctly
   - Adds metadata and versioning

## 🔍 Troubleshooting

### Common Issues

**"Missing required dependencies"**
```bash
# Install jq
brew install jq

# Install Claude CLI
# See: https://docs.anthropic.com/en/docs/claude-code
```

**"Invalid JSON from [server]"**
- Check MCP server configuration in Claude Desktop
- Verify servers are running and accessible
- Review server logs in `~/Library/Logs/Claude/`

**"Claude analysis failed"**
- Verify Claude CLI is authenticated
- Check internet connection
- The tool will fallback to minimal structure

**"No data from [server]"**
- Normal when services aren't available
- Tool gracefully handles missing data
- Check specific server documentation

### Validation Errors

**"Invalid date format"**
- Ensure YYYY-MM-DD format in output
- Check system date settings

**"Schema validation failed"**
- Review TimeStory requirements
- Check field naming (snake_case required)
- Verify numeric ranges (scores 0-100, levels 1-5)

## 📈 Integration Workflow

### Daily Routine
```bash
# Morning: Generate yesterday's summary
./claude-activity-summary.sh yesterday > "summary_$(date -v-1d +%Y-%m-%d).json"

# Evening: Generate today's summary  
./claude-activity-summary.sh today > "summary_$(date +%Y-%m-%d).json"
```

### Automation
```bash
# Add to crontab for daily automation
# Generate yesterday's summary at 8 AM
0 8 * * * /path/to/claude-activity-summary.sh yesterday > /path/to/summaries/$(date -v-1d +%Y-%m-%d).json
```

### TimeStory Import
```bash
# 1. Check if data exists
# Use get_timesheet_by_date via timestory-mcp

# 2. Import or update
# Use import_timestory or update_timesheet via timestory-mcp
```

## 🏗️ Architecture

### Components
- **claude-activity-summary.sh** - Main orchestration script
- **claude-prompt-template.md** - Analysis prompt for Claude
- **call_mcp()** - MCP server communication function
- **validate_timestory_schema()** - Output validation
- **format_timestory_output()** - Schema compliance formatting

### Data Flow
```
ActivityWatch → collect_activitywatch_data() →
Health APIs  → collect_health_data()        →  combine_data() →
Git/GitLab   → collect_development_data()   →  
Voice/Context→ collect_voice_data()         →  
                                             ↓
                                     analyze_with_claude() →
                                             ↓
                                     validate_timestory_schema() →
                                             ↓  
                                     format_timestory_output()
```

## 🤝 Contributing

1. Test changes with various date parameters
2. Ensure schema compliance for all outputs  
3. Handle MCP server failures gracefully
4. Update documentation for new features
5. Validate with actual TimeStory imports

## 📄 License

This tool is part of the Opens Time Chat ecosystem. See repository license for details.

## 🔗 Related Projects

- [ActivityWatch MCP](./README.md) - Core ActivityWatch integration
- [TimeStory MCP](../timestory-mcp/) - TimeStory database interface
- [Opens Time Chat](../) - Complete productivity tracking ecosystem