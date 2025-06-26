#!/bin/bash

# Claude Activity Summary with Markdown Import
# This tool combines the two-step process and imports both JSON and markdown content

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATE_INPUT="${1:-today}"

# Logging functions
log_info() {
    echo "[INFO] $1" >&2
}

log_error() {
    echo "[ERROR] $1" >&2
}

# Help text
show_help() {
    cat << EOF
Usage: $0 [date] [--help]

Generate activity summary with both structured JSON and markdown content.

Arguments:
  date          Date to analyze (default: today)
                Supports: today, yesterday, 2025-06-26, "3 days ago", etc.

Options:
  --help        Show this help message

Examples:
  $0                      # Analyze today
  $0 yesterday           # Analyze yesterday  
  $0 2025-06-25         # Analyze specific date
  $0 "3 days ago"       # Analyze relative date

The tool will:
1. Collect ActivityWatch data for the specified date
2. Generate comprehensive analysis with Claude CLI (-p mode)
3. Convert analysis to JSON format
4. Import both JSON structure AND original markdown to timestory-mcp
5. Preserve the rich narrative while enabling structured queries

Output files:
  - {date}.md     Original Claude analysis in markdown
  - {date}.json   Structured data for database import
EOF
}

# Parse arguments
if [[ "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# Normalize date to YYYY-MM-DD format
normalize_date() {
    local input_date="$1"
    
    case "$input_date" in
        "today")
            date '+%Y-%m-%d'
            ;;
        "yesterday")
            date -v-1d '+%Y-%m-%d' 2>/dev/null || date -d yesterday '+%Y-%m-%d' 2>/dev/null
            ;;
        [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9])
            echo "$input_date"
            ;;
        *)
            # Try parsing with date command for relative dates
            if date -j -f "%Y-%m-%d" "$input_date" '+%Y-%m-%d' 2>/dev/null; then
                echo "$input_date"
            elif date -d "$input_date" '+%Y-%m-%d' 2>/dev/null; then
                date -d "$input_date" '+%Y-%m-%d'
            else
                log_error "Could not parse date: $input_date"
                log_error "Try formats like: today, yesterday, 2025-06-26, '3 days ago'"
                exit 1
            fi
            ;;
    esac
}

# Get normalized date
NORMALIZED_DATE=$(normalize_date "$DATE_INPUT")
if [[ -z "$NORMALIZED_DATE" ]]; then
    log_error "Failed to normalize date: $DATE_INPUT"
    exit 1
fi

log_info "Analyzing date: $NORMALIZED_DATE"

# File paths
MARKDOWN_FILE="$SCRIPT_DIR/${NORMALIZED_DATE}.md"
JSON_FILE="$SCRIPT_DIR/${NORMALIZED_DATE}.json"

# Step 1: Generate comprehensive analysis if markdown doesn't exist
if [[ ! -f "$MARKDOWN_FILE" ]]; then
    log_info "Generating comprehensive Claude analysis..."
    
    # Get ActivityWatch data
    ACTIVITY_DATA=$(jq -n \
        --arg date "$NORMALIZED_DATE" \
        '{
            "method": "mcp__activitywatch__get-folder-activity",
            "params": {
                "start": $date
            }
        }' | \
        claude --no-cache 2>/dev/null || echo '{"error": "No ActivityWatch data available"}')
    
    # Create comprehensive prompt
    PROMPT="You are an expert productivity analyst. Analyze the following ActivityWatch data for $NORMALIZED_DATE and provide a comprehensive daily summary.

ACTIVITY DATA:
$ACTIVITY_DATA

Please provide a detailed analysis covering:

## 🎯 **Daily Achievements**
- Primary accomplishments (major features, fixes, milestones)
- Secondary tasks completed
- Key deliverables and impacts

## ⏱️ **Timeline & Work Phases**  
- Detailed breakdown of work sessions with times
- Project focus areas and context switching
- Meeting and collaboration time

## 📊 **Activity Distribution**
- Time spent on different activity types (development, testing, communication, etc.)
- Productivity patterns and focus quality
- Tool and application usage insights

## 📁 **Project & Folder Activity**
- Primary projects worked on with time allocation
- Folder/repository activity patterns
- Code organization insights

## 💼 **Work Summary**
- Client work vs. side projects breakdown
- Billable hours and project categorization
- Version control activity and commits

## 🧠 **Insights & Patterns**
- Productivity observations and recommendations
- Focus quality and context switching analysis
- Optimal work time identification

## 📈 **Metrics & Scores**
- Productivity score (0-100)
- Focus score (0-100) 
- Achievement level (1-5)
- Context switches count
- Wellness score (0-100)

## 📝 **Tomorrow's Planning**
- Priority tasks for next day
- Recommended focus areas
- Optimal work schedule suggestions

Be specific, data-driven, and provide actionable insights. Include actual time ranges, specific achievements, and concrete recommendations."

    # Generate analysis with Claude
    echo "$PROMPT" | claude -p > "$MARKDOWN_FILE" 2>/dev/null
    
    if [[ ! -s "$MARKDOWN_FILE" ]]; then
        log_error "Failed to generate Claude analysis"
        exit 1
    fi
    
    log_info "Analysis saved to: $MARKDOWN_FILE"
else
    log_info "Using existing analysis: $MARKDOWN_FILE"
fi

# Step 2: Convert to JSON if it doesn't exist
if [[ ! -f "$JSON_FILE" ]]; then
    log_info "Converting analysis to structured JSON..."
    
    CONVERSION_PROMPT="Convert the following activity analysis to valid JSON format matching the TimeStory import schema.

ANALYSIS TO CONVERT:
$(cat "$MARKDOWN_FILE")

Return ONLY valid JSON with this exact structure:
{
  \"date\": \"$NORMALIZED_DATE\",
  \"timezone\": \"Europe/Brussels\",
  \"timeSummary\": {
    \"startTime\": \"HH:MM\",
    \"endTime\": \"HH:MM\", 
    \"totalDurationMinutes\": 0,
    \"billableHours\": 0,
    \"sideProjectHours\": 0
  },
  \"achievements\": [{\"type\": \"primary\", \"title\": \"\", \"description\": \"\"}],
  \"timelinePhases\": [{\"startTime\": \"\", \"endTime\": \"\", \"durationMinutes\": 0, \"title\": \"\", \"category\": \"side_project\"}],
  \"activityDistribution\": {\"development\": 0, \"terminal\": 0, \"testing\": 0, \"communication\": 0, \"documentation\": 0, \"other\": 0},
  \"insights\": [{\"category\": \"productivity\", \"title\": \"\", \"description\": \"\", \"priority\": \"high\"}],
  \"metrics\": {\"productivityScore\": 0, \"focusScore\": 0, \"achievementLevel\": 0, \"contextSwitches\": 0, \"wellnessScore\": 0},
  \"folderActivity\": {\"activeFolders\": [{\"path\": \"\", \"durationMinutes\": 0}]},
  \"workSummary\": {\"clientWork\": {\"totalMinutes\": 0, \"totalHours\": 0, \"projects\": []}, \"sideProjects\": {\"totalMinutes\": 0, \"totalHours\": 0, \"projects\": []}},
  \"productivityMetrics\": {\"completionRate\": 0.0, \"efficiencyRatio\": 0.0, \"ticketsClosed\": 0, \"codeCommits\": 0},
  \"tomorrowPlanning\": {\"priorities\": []}
}

Extract data accurately from the analysis. Use realistic values based on the content."

    echo "$CONVERSION_PROMPT" | claude -p 2>/dev/null | \
        grep -E '^\s*\{.*\}\s*$' | \
        head -1 > "$JSON_FILE"
    
    # Validate JSON
    if ! jq . "$JSON_FILE" >/dev/null 2>&1; then
        log_error "Generated invalid JSON, trying to extract from Claude response..."
        
        # Try to extract JSON from Claude response
        echo "$CONVERSION_PROMPT" | claude -p 2>/dev/null | \
            sed -n '/```json/,/```/p' | \
            sed '1d;$d' > "$JSON_FILE"
        
        if ! jq . "$JSON_FILE" >/dev/null 2>&1; then
            log_error "Could not generate valid JSON. Check $JSON_FILE"
            exit 1
        fi
    fi
    
    log_info "JSON conversion saved to: $JSON_FILE"
else
    log_info "Using existing JSON: $JSON_FILE"
fi

# Step 3: Import both JSON and markdown to timestory-mcp
log_info "Importing structured data with markdown content to TimeStory..."

# Read JSON content
JSON_CONTENT=$(cat "$JSON_FILE")

# Read markdown content
MARKDOWN_CONTENT=$(cat "$MARKDOWN_FILE")

# Create import request
IMPORT_REQUEST=$(jq -n \
    --argjson jsonData "$JSON_CONTENT" \
    --arg markdownContent "$MARKDOWN_CONTENT" \
    '{
        "method": "mcp__timestory-mcp__import_with_markdown",
        "params": {
            "jsonData": $jsonData,
            "markdownContent": $markdownContent
        }
    }')

# Execute import
IMPORT_RESULT=$(echo "$IMPORT_REQUEST" | claude --no-cache 2>/dev/null)

if echo "$IMPORT_RESULT" | jq -e '.success' >/dev/null 2>&1; then
    TIMESHEET_ID=$(echo "$IMPORT_RESULT" | jq -r '.id')
    MARKDOWN_SIZE=$(echo "$IMPORT_RESULT" | jq -r '.markdownSize')
    
    log_info "✅ Import successful!"
    log_info "   Timesheet ID: $TIMESHEET_ID"
    log_info "   Markdown size: $MARKDOWN_SIZE characters"
    log_info "   JSON file: $JSON_FILE"
    log_info "   Markdown file: $MARKDOWN_FILE"
else
    log_error "Import failed:"
    echo "$IMPORT_RESULT" | jq -r '.error // .message // .' >&2
    exit 1
fi

log_info "🎉 Complete! Both structured data and rich markdown are now stored in TimeStory."
log_info "   Use timestory-mcp tools for structured queries"
log_info "   Access full narrative through the stored markdown content"