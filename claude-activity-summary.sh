#!/bin/bash

# Claude Activity Summary Tool
# Collects ActivityWatch and related data, analyzes with Claude CLI, 
# and outputs timestory-compatible JSON format
#
# Usage: ./claude-activity-summary.sh [options] [date]
# Examples:
#   ./claude-activity-summary.sh                    # Today's summary
#   ./claude-activity-summary.sh --analysis-only    # Today's analysis only
#   ./claude-activity-summary.sh yesterday          # Yesterday's summary

set -euo pipefail

# Configuration
DATE_PARAM="today"
ANALYSIS_ONLY=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --analysis-only)
            ANALYSIS_ONLY=true
            shift
            ;;
        -h|--help)
            cat << EOF
Claude Activity Summary Tool v2.0.0

Collects daily activity data from ActivityWatch and related MCP servers,
analyzes it with Claude CLI, and outputs TimeStory-compatible JSON.

Usage:
    $0 [options] [date]

Options:
    --analysis-only    Show only the Claude analysis in markdown format
    -h, --help        Show this help message

Date examples:
    today           Today's activities (default)
    yesterday       Yesterday's activities  
    "3 days ago"    Activities from 3 days ago
    "last monday"   Activities from last Monday

Output:
    JSON formatted for TimeStory import (or markdown with --analysis-only)

Examples:
    $0                          # Today's summary as JSON
    $0 --analysis-only          # Today's analysis as markdown
    $0 yesterday                # Yesterday's summary as JSON
    $0 --analysis-only "2 days ago"  # Analysis for 2 days ago

Requirements:
    - ActivityWatch running (http://localhost:5600)
    - Claude CLI installed and configured
    - MCP servers configured in Claude Desktop
    - jq installed for JSON processing

EOF
            exit 0
            ;;
        *)
            DATE_PARAM="$1"
            shift
            ;;
    esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1" >&2; }

# Simple MCP call function
call_mcp() {
    local server="$1"
    local tool="$2" 
    local args="$3"
    
    local cmd="$server --log-level error"
    
    local result=$(printf '%s\n%s\n' \
        '{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{}}}' \
        "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"$tool\",\"arguments\":$args}}" | \
        $cmd 2>/dev/null | \
        grep '^{' | \
        tail -n 1 | \
        jq -r '.result.content[0].text // "null"' 2>/dev/null || echo "null")
    
    echo "$result"
}

# Collect comprehensive data
collect_data() {
    log_info "Collecting comprehensive data for $DATE_PARAM"
    
    # ActivityWatch data
    local folder_activity=$(call_mcp "activitywatch-mcp" "get-folder-activity" "{\"start\":\"$DATE_PARAM\"}")
    local active_buckets=$(call_mcp "activitywatch-mcp" "active-buckets" "{\"start\":\"$DATE_PARAM\"}")
    
    # Context and voice data
    local contexts=$(call_mcp "aw-context-mcp" "query-contexts" "{\"date\":\"$DATE_PARAM\"}")
    local transcriptions=$(call_mcp "wispr-flow-mcp" "list" "{\"limit\":20}")
    
    # Health data
    local date_formatted=$(date +%Y-%m-%d)
    if [ "$DATE_PARAM" = "yesterday" ]; then
        date_formatted=$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d yesterday +%Y-%m-%d)
    fi
    local steps=$(call_mcp "vital-flow-mcp" "get_daily_steps" "{\"date\":\"$date_formatted\"}")
    
    # Development data
    local git_stats=$(call_mcp "git-mcp" "git_quick_stats" "{\"timeframe\":\"1 day\"}")
    
    jq -n \
        --arg folderActivity "$folder_activity" \
        --arg activeBuckets "$active_buckets" \
        --arg contexts "$contexts" \
        --arg transcriptions "$transcriptions" \
        --arg steps "$steps" \
        --arg gitStats "$git_stats" \
        --arg date "$DATE_PARAM" \
        --arg collectedAt "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{
            metadata: {
                date: $date,
                collectedAt: $collectedAt,
                version: "2.0.0"
            },
            activitywatch: {
                folderActivity: $folderActivity,
                activeBuckets: $activeBuckets
            },
            contexts: $contexts,
            voice: $transcriptions,
            health: $steps,
            development: $gitStats
        }'
}

# Claude analysis 
analyze_with_claude() {
    local raw_data="$1"
    
    log_info "Getting comprehensive Claude analysis..."
    
    local prompt="You are an expert productivity analyst. Analyze this comprehensive daily activity data and provide detailed insights.

Please provide a structured markdown analysis covering:

## Daily Activity Summary
- Overall time breakdown and active periods
- Peak productivity hours and work patterns

## Work Analysis  
- Client work vs side projects vs personal time
- Projects worked on (categorize by folder names)
- Development activities and achievements

## Health & Productivity Correlation
- Physical activity and energy levels
- Context annotations and voice notes

## Key Achievements & Insights
- Major accomplishments during the day
- Productivity patterns discovered
- Areas for improvement

Be specific and base your analysis entirely on the actual data provided.

Data to analyze:
$raw_data"

    claude -p "$prompt" 2>/dev/null || echo "Analysis failed - Claude CLI error"
}

# Convert analysis to TimeStory JSON
convert_to_json() {
    local analysis="$1"
    
    log_info "Converting analysis to TimeStory JSON format..."
    
    local current_date=$(date +%Y-%m-%d)
    if [ "$DATE_PARAM" = "yesterday" ]; then
        current_date=$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d yesterday +%Y-%m-%d)
    fi
    
    local prompt="Convert this analysis into a valid JSON object matching the TimeStory import schema exactly.

Requirements:
- Use snake_case for all field names
- Date: $current_date (YYYY-MM-DD format)
- Times in HH:MM format (24-hour)
- Duration in minutes
- Health scores 0-100, achievement levels 1-5
- Include timezone as \"Europe/Brussels\"
- Base all data on the analysis provided

Required structure:
{
  \"date\": \"$current_date\",
  \"timezone\": \"Europe/Brussels\",
  \"timeSummary\": {
    \"startTime\": \"09:00\",
    \"endTime\": \"18:00\",
    \"totalDurationMinutes\": 480
  }
}

Include these sections if data is available:
- achievements (array with type, title, description)
- timelinePhases (work blocks with times and categories)
- activityDistribution (time by category in minutes)
- folderActivity (projects worked on)
- workSummary (client vs side project breakdown)
- insights (productivity patterns and recommendations)
- contextAnnotations (notes and observations)

Output only valid JSON, no markdown formatting.

Analysis to convert:
$analysis"

    local json_result=$(claude -p "$prompt" 2>/dev/null)
    
    # Extract JSON from Claude's response
    if echo "$json_result" | jq . >/dev/null 2>&1; then
        echo "$json_result" | jq .
    else
        # Try to extract JSON from markdown
        local extracted=$(echo "$json_result" | sed -n '/```json/,/```/p' | sed '1d;$d' 2>/dev/null)
        if echo "$extracted" | jq . >/dev/null 2>&1; then
            echo "$extracted" | jq .
        else
            # Fallback to minimal structure
            cat << EOF | jq .
{
  "date": "$current_date",
  "timezone": "Europe/Brussels",
  "timeSummary": {
    "startTime": "09:00",
    "endTime": "18:00",
    "totalDurationMinutes": 480
  },
  "metadata": {
    "note": "JSON conversion failed, minimal structure provided",
    "generatedBy": "claude-activity-summary",
    "version": "2.0.0",
    "generatedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  }
}
EOF
        fi
    fi
}

# Main function
main() {
    log_info "Starting Claude Activity Summary v2.0.0 for $DATE_PARAM"
    
    # Collect data
    local raw_data=$(collect_data)
    
    if [ "$ANALYSIS_ONLY" = true ]; then
        # Just show analysis
        analyze_with_claude "$raw_data"
        log_info "Analysis complete (markdown format)"
        return
    fi
    
    # Full workflow
    local analysis=$(analyze_with_claude "$raw_data")
    
    if echo "$analysis" | grep -q "Analysis failed"; then
        log_error "Claude analysis failed"
        # Create minimal fallback
        cat << EOF | jq .
{
  "date": "$(date +%Y-%m-%d)",
  "timezone": "Europe/Brussels",
  "timeSummary": {
    "startTime": "09:00",
    "endTime": "18:00",
    "totalDurationMinutes": 480
  },
  "metadata": {
    "note": "Analysis failed - minimal structure",
    "generatedBy": "claude-activity-summary",
    "version": "2.0.0",
    "generatedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  }
}
EOF
        return
    fi
    
    # Convert to JSON
    local json_result=$(convert_to_json "$analysis")
    
    # Output result
    echo "$json_result"
    
    # Provide usage suggestions
    log_success "Generated TimeStory-compatible JSON"
    log_info "To import: Use timestory-mcp import_timestory tool with this JSON"
}

# Check prerequisites
check_prerequisites() {
    local missing=()
    
    if ! command -v jq >/dev/null 2>&1; then
        missing+=("jq")
    fi
    
    if ! command -v claude >/dev/null 2>&1; then
        missing+=("claude CLI")
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing dependencies: ${missing[*]}"
        echo "Install instructions:" >&2
        echo "  jq: brew install jq" >&2
        echo "  Claude CLI: https://docs.anthropic.com/en/docs/claude-code" >&2
        exit 1
    fi
}

# Run
check_prerequisites
main