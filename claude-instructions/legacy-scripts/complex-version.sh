#!/bin/bash

# Claude Activity Summary Tool
# Collects ActivityWatch and related data, analyzes with Claude CLI, 
# and outputs timestory-compatible JSON format
#
# Usage: ./claude-activity-summary.sh [date]
# Examples:
#   ./claude-activity-summary.sh           # Today
#   ./claude-activity-summary.sh today     # Today  
#   ./claude-activity-summary.sh yesterday # Yesterday
#   ./claude-activity-summary.sh "3 days ago" # 3 days ago

set -euo pipefail

# Configuration
SCRIPT_NAME="claude-activity-summary"
VERSION="1.0.0"
ANALYSIS_ONLY=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --analysis-only)
            ANALYSIS_ONLY=true
            shift
            ;;
        -h|--help)
            show_help() {
                cat << EOF
$SCRIPT_NAME v$VERSION

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
            }
            show_help
            exit 0
            ;;
        *)
            DATE_PARAM="$1"
            shift
            ;;
    esac
done

DATE_PARAM="${DATE_PARAM:-today}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

# Function to call MCP servers safely
call_mcp() {
    local server="$1"
    local tool="$2" 
    local args="$3"
    local description="${4:-Calling $tool}"
    
    log_info "$description"
    
    # Configure server command based on type
    local cmd="$server"
    case "$server" in
        activitywatch-mcp|aw-context-mcp|git-mcp|gitlab-mcp-swift|timestory-mcp|vital-flow-mcp)
            cmd="$server --log-level error"
            ;;
        wispr-flow-mcp)
            cmd="$server"
            ;;
    esac
    
    # Send MCP request
    local result=$(printf '%s\n%s\n' \
        '{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{}}}' \
        "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"$tool\",\"arguments\":$args}}" | \
        $cmd 2>/dev/null | \
        grep '^{' | \
        tail -n 1 | \
        jq -r '.result.content[0].text // empty' 2>/dev/null || echo "null")
    
    if [ "$result" = "null" ] || [ -z "$result" ]; then
        log_warn "No data from $server/$tool"
        echo "null"
    else
        # Check if it's valid JSON, if not, wrap it as text
        if echo "$result" | jq . >/dev/null 2>&1; then
            echo "$result"
        else
            # If it's not JSON, treat it as text content and wrap it safely
            log_info "Text response from $server/$tool (not JSON), treating as string"
            echo "$result" | jq -Rs .
        fi
    fi
}

# Data collection functions
collect_activitywatch_data() {
    log_info "Collecting ActivityWatch data..."
    
    # Get comprehensive folder activity
    local folder_activity=$(call_mcp "activitywatch-mcp" "get-folder-activity" \
        "{\"start\":\"$DATE_PARAM\"}" \
        "Getting folder activity for $DATE_PARAM")
    
    # Get active buckets  
    local active_buckets=$(call_mcp "activitywatch-mcp" "active-buckets" \
        "{\"start\":\"$DATE_PARAM\"}" \
        "Getting active buckets for $DATE_PARAM")
    
    # Get window events for timeline analysis
    local window_query=$(call_mcp "activitywatch-mcp" "run-query" \
        "{\"timeperiods\":[\"$DATE_PARAM\"],\"query\":[\"events = query_bucket(find_bucket('aw-watcher-window')); RETURN = events;\"]}" \
        "Getting window events for timeline")
        
    # Get AFK events for break time analysis
    local afk_query=$(call_mcp "activitywatch-mcp" "run-query" \
        "{\"timeperiods\":[\"$DATE_PARAM\"],\"query\":[\"afk_events = query_bucket(find_bucket('aw-watcher-afk')); not_afk = filter_keyvals(afk_events, 'status', ['not-afk']); RETURN = not_afk;\"]}" \
        "Getting AFK events for active time")
    
    # Combine ActivityWatch data, handling null values
    jq -n \
        --argjson folderActivity "${folder_activity:-null}" \
        --argjson activeBuckets "${active_buckets:-null}" \
        --argjson windowEvents "${window_query:-null}" \
        --argjson afkEvents "${afk_query:-null}" \
        '{
            folderActivity: $folderActivity,
            activeBuckets: $activeBuckets,
            windowEvents: $windowEvents,
            afkEvents: $afkEvents
        }'
}

collect_context_data() {
    log_info "Collecting context data..."
    
    local contexts=$(call_mcp "aw-context-mcp" "query-contexts" \
        "{\"date\":\"$DATE_PARAM\"}" \
        "Getting context annotations")
    
    echo "$contexts"
}

collect_health_data() {
    log_info "Collecting health data..."
    
    # Convert date parameter to YYYY-MM-DD format for VitalFlow
    local date_formatted
    if [ "$DATE_PARAM" = "today" ]; then
        date_formatted=$(date +%Y-%m-%d)
    elif [ "$DATE_PARAM" = "yesterday" ]; then
        date_formatted=$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d yesterday +%Y-%m-%d)
    else
        # Try to parse the date - this is a simplified approach
        date_formatted=$(date +%Y-%m-%d)
    fi
    
    local steps=$(call_mcp "vital-flow-mcp" "get_daily_steps" \
        "{\"date\":\"$date_formatted\"}" \
        "Getting daily steps")
    
    local heart_rate=$(call_mcp "vital-flow-mcp" "get_heart_rate_trends" \
        "{\"days\":1}" \
        "Getting heart rate data")
    
    local sleep_quality=$(call_mcp "vital-flow-mcp" "get_sleep_quality" \
        "{\"date\":\"$date_formatted\"}" \
        "Getting sleep quality")
    
    jq -n \
        --argjson steps "${steps:-null}" \
        --argjson heartRate "${heart_rate:-null}" \
        --argjson sleepQuality "${sleep_quality:-null}" \
        '{
            steps: $steps,
            heartRate: $heartRate,
            sleepQuality: $sleepQuality
        }'
}

collect_development_data() {
    log_info "Collecting development data..."
    
    # Git activity (local)
    local git_stats=$(call_mcp "git-mcp" "git_quick_stats" \
        "{\"timeframe\":\"1 day\"}" \
        "Getting Git statistics")
    
    # GitLab activity (remote) - get recent merge requests and commits
    local gitlab_mrs=$(call_mcp "gitlab-mcp-swift" "glab_mr" \
        "{\"subcommand\":\"list\",\"args\":[\"--assignee=@me\",\"--state=all\",\"--created-after=$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d yesterday +%Y-%m-%d)\"]}" \
        "Getting recent GitLab merge requests")
    
    jq -n \
        --argjson gitStats "${git_stats:-null}" \
        --argjson gitlabMRs "${gitlab_mrs:-null}" \
        '{
            local: $gitStats,
            remote: $gitlabMRs
        }'
}

collect_voice_data() {
    log_info "Collecting voice transcription data..."
    
    local transcriptions=$(call_mcp "wispr-flow-mcp" "list" \
        "{\"limit\":50}" \
        "Getting recent voice transcriptions")
    
    echo "$transcriptions"
}

# Main data collection orchestrator
collect_all_data() {
    log_info "Starting comprehensive data collection for $DATE_PARAM"
    
    # Collect data from all sources in parallel for efficiency
    local activitywatch_data=$(collect_activitywatch_data)
    local context_data=$(collect_context_data) 
    local health_data=$(collect_health_data)
    local development_data=$(collect_development_data)
    local voice_data=$(collect_voice_data)
    
    # Combine all raw data, ensuring all values are valid JSON
    jq -n \
        --argjson activitywatch "${activitywatch_data:-null}" \
        --argjson contexts "${context_data:-null}" \
        --argjson health "${health_data:-null}" \
        --argjson development "${development_data:-null}" \
        --argjson voice "${voice_data:-null}" \
        --arg date "$DATE_PARAM" \
        --arg collectedAt "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{
            metadata: {
                date: $date,
                collectedAt: $collectedAt,
                version: "1.0.0"
            },
            activitywatch: $activitywatch,
            contexts: $contexts,
            health: $health,
            development: $development,
            voice: $voice
        }'
}

# Claude analysis functions - two step process
analyze_data_with_claude() {
    local raw_data="$1"
    
    log_info "Step 1: Analyzing data with Claude CLI..."
    
    # Create analysis prompt
    local analysis_prompt=$(cat << 'EOF'
You are an expert productivity analyst. I have collected comprehensive daily activity data from multiple sources (ActivityWatch, health metrics, development tools, voice transcriptions, etc.) and need you to analyze it.

Please provide a detailed markdown analysis covering:

## Daily Activity Summary
- Overall time breakdown and active periods
- Peak productivity hours
- Break patterns and work-life balance

## Work Analysis  
- Client work vs side projects vs personal time
- Projects worked on (categorize by folder names and activities)
- Development activities (Git commits, coding time, tools used)

## Health & Productivity Correlation
- Physical activity and energy levels
- Sleep quality impact on productivity
- Heart rate patterns during work

## Achievements & Insights
- Key accomplishments during the day
- Productivity patterns discovered
- Areas for improvement
- Notable activities or milestones

## Context & Voice Analysis
- Important annotations or notes made
- Voice commands or transcriptions captured
- Communication and collaboration activities

Please be specific and base your analysis entirely on the actual data provided. Don't make assumptions about activities not present in the data.

Here's the raw activity data to analyze:

EOF
    )
    
    # Create temporary file for analysis
    local temp_file=$(mktemp)
    echo "$analysis_prompt" > "$temp_file"
    echo '```json' >> "$temp_file"
    echo "$raw_data" >> "$temp_file"
    echo '```' >> "$temp_file"
    
    # Get Claude's analysis
    log_info "Getting Claude's analysis..."
    local analysis_output=$(claude -p "$(cat "$temp_file")" 2>&1)
    local exit_code=$?
    
    rm -f "$temp_file"
    
    if [ $exit_code -ne 0 ]; then
        log_error "Claude analysis failed with exit code $exit_code"
        echo "null"
        return
    fi
    
    echo "$analysis_output"
}

convert_analysis_to_json() {
    local analysis="$1"
    local date_param="$2"
    
    log_info "Step 2: Converting analysis to TimeStory JSON format..."
    
    # Create conversion prompt
    local conversion_prompt=$(cat << 'EOF'
Convert the following activity analysis into a valid JSON object that matches the TimeStory import schema exactly.

Requirements:
- Use snake_case for all field names
- Date in YYYY-MM-DD format
- Times in HH:MM format (24-hour)
- Duration in minutes
- Health scores 0-100, achievement levels 1-5
- Include timezone as "Europe/Brussels"
- Base all data on the analysis provided - don't invent information

Required structure:
{
  "date": "YYYY-MM-DD",
  "timezone": "Europe/Brussels", 
  "timeSummary": {
    "startTime": "HH:MM",
    "endTime": "HH:MM",
    "totalDurationMinutes": number
  }
}

Optional sections to include if data is available:
- healthMetrics, gitlabActivity, timelinePhases, achievements, activityDistribution, contextAnnotations, voiceCommands, productivityMetrics, metrics, folderActivity, workSummary, insights

Output only valid JSON, no markdown formatting or explanations.

Analysis to convert:

EOF
    )
    
    local temp_file=$(mktemp)
    echo "$conversion_prompt" > "$temp_file"
    echo "$analysis" >> "$temp_file"
    
    log_info "Converting to JSON format..."
    local json_output=$(claude -p "$(cat "$temp_file")" 2>&1)
    local exit_code=$?
    
    rm -f "$temp_file"
    
    if [ $exit_code -ne 0 ]; then
        log_error "Claude JSON conversion failed"
        echo "null"
        return
    fi
    
    # Extract JSON from response - simplified approach
    local result="$json_output"
    
    # If it contains code blocks, try to extract JSON
    if echo "$json_output" | grep -q 'json'; then
        # Save to temp file and extract
        local temp_json=$(mktemp)
        echo "$json_output" > "$temp_json"
        result=$(python3 -c "
import re
with open('$temp_json', 'r') as f:
    text = f.read()
# Try to find JSON in code blocks first
json_match = re.search(r'\`\`\`json\s*\n(.*?)\n\`\`\`', text, re.DOTALL)
if json_match:
    print(json_match.group(1))
else:
    # Fall back to finding { } blocks
    brace_match = re.search(r'\{.*\}', text, re.DOTALL)
    if brace_match:
        print(brace_match.group(0))
    else:
        print(text)
" 2>/dev/null || echo "$json_output")
        rm -f "$temp_json"
    fi
    
    # Validate and return JSON
    if echo "$result" | jq . >/dev/null 2>&1; then
        log_success "Successfully converted analysis to valid JSON"
        echo "$result"
    else
        log_error "Generated invalid JSON"
        echo "null"
    fi
}

# Combined analysis function
analyze_with_claude() {
    local raw_data="$1"
    
    # Step 1: Get analysis
    local analysis=$(analyze_data_with_claude "$raw_data")
    
    if [ "$analysis" = "null" ] || [ -z "$analysis" ]; then
        log_error "Failed to get analysis from Claude"
        echo "null"
        return
    fi
    
    # Step 2: Convert to JSON
    local json_result=$(convert_analysis_to_json "$analysis" "$DATE_PARAM")
    
    if [ "$json_result" = "null" ] || [ -z "$json_result" ]; then
        log_warn "Failed to convert analysis to JSON, but analysis was successful"
        log_info "Saving analysis for manual review..."
        echo "$analysis" > "claude_analysis_$(date +%Y%m%d_%H%M%S).md"
        echo "null"
        return
    fi
    
    echo "$json_result"
}

# Validation and formatting functions
validate_timestory_schema() {
    local json_data="$1"
    
    log_info "Validating TimeStory schema compliance..."
    
    # Check required fields
    local required_fields=("date" "timezone" "timeSummary")
    local time_summary_fields=("startTime" "endTime" "totalDurationMinutes")
    
    for field in "${required_fields[@]}"; do
        if ! echo "$json_data" | jq -e ".$field" >/dev/null 2>&1; then
            log_error "Missing required field: $field"
            return 1
        fi
    done
    
    # Check timeSummary required fields
    for field in "${time_summary_fields[@]}"; do
        if ! echo "$json_data" | jq -e ".timeSummary.$field" >/dev/null 2>&1; then
            log_error "Missing required timeSummary field: $field"
            return 1
        fi
    done
    
    # Validate date format (YYYY-MM-DD)
    local date_value=$(echo "$json_data" | jq -r '.date')
    if ! [[ "$date_value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        log_error "Invalid date format: $date_value (expected YYYY-MM-DD)"
        return 1
    fi
    
    # Validate time formats (HH:MM)
    local start_time=$(echo "$json_data" | jq -r '.timeSummary.startTime')
    local end_time=$(echo "$json_data" | jq -r '.timeSummary.endTime')
    
    for time in "$start_time" "$end_time"; do
        if ! [[ "$time" =~ ^[0-9]{2}:[0-9]{2}$ ]]; then
            log_error "Invalid time format: $time (expected HH:MM)"
            return 1
        fi
    done
    
    # Validate numeric ranges
    local health_score=$(echo "$json_data" | jq -r '.healthMetrics.healthScore // 0')
    local achievement_level=$(echo "$json_data" | jq -r '.metrics.achievementLevel // 1')
    
    if [ "$health_score" -lt 0 ] || [ "$health_score" -gt 100 ]; then
        log_warn "Health score out of range (0-100): $health_score"
    fi
    
    if [ "$achievement_level" -lt 1 ] || [ "$achievement_level" -gt 5 ]; then
        log_warn "Achievement level out of range (1-5): $achievement_level"
    fi
    
    log_success "Schema validation passed"
    return 0
}

format_timestory_output() {
    local analysis_result="$1"
    local fallback_date="$2"
    
    log_info "Formatting output for TimeStory import..."
    
    # If Claude analysis failed, create a minimal valid structure
    if [ "$analysis_result" = "null" ] || [ -z "$analysis_result" ]; then
        log_warn "No Claude analysis available, creating minimal structure"
        
        local current_date
        if [ "$fallback_date" = "today" ]; then
            current_date=$(date +%Y-%m-%d)
        elif [ "$fallback_date" = "yesterday" ]; then
            current_date=$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d yesterday +%Y-%m-%d)
        else
            current_date=$(date +%Y-%m-%d)
        fi
        
        local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        
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
    "generatedBy": "claude-activity-summary",
    "version": "1.0.0",
    "generatedAt": "$timestamp",
    "note": "Minimal structure due to analysis failure"
  }
}
EOF
        return
    fi
    
    # Validate the analysis result and add metadata
    if validate_timestory_schema "$analysis_result"; then
        local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        echo "$analysis_result" | jq --arg ts "$timestamp" '. + {metadata: {generatedBy: "claude-activity-summary", version: "1.0.0", generatedAt: $ts}}'
    else
        log_error "Schema validation failed, outputting analysis with warnings"
        echo "$analysis_result"
    fi
}

# Import helper function
suggest_import_command() {
    local output_file="$1"
    local date_param="$2"
    
    log_info "Generated TimeStory-compatible JSON"
    echo "" >&2
    log_info "To import into TimeStory, you can:"
    echo "  1. Save output to file: $0 $date_param > daily_summary.json" >&2
    echo "  2. Import via timestory-mcp: Use the import_timestory tool" >&2
    echo "  3. Check for existing data first: get_timesheet_by_date" >&2
    echo "" >&2
}

# Main execution function
main() {
    log_info "Starting $SCRIPT_NAME v$VERSION"
    log_info "Target date: $DATE_PARAM"
    
    # Collect all raw data
    local raw_data=$(collect_all_data)
    
    if [ "$raw_data" = "null" ] || [ -z "$raw_data" ]; then
        log_error "Failed to collect data"
        exit 1
    fi
    
    # Handle analysis-only mode
    if [ "$ANALYSIS_ONLY" = true ]; then
        log_info "Analysis-only mode: generating markdown analysis"
        local analysis=$(analyze_data_with_claude "$raw_data")
        
        if [ "$analysis" = "null" ] || [ -z "$analysis" ]; then
            log_error "Failed to get analysis from Claude"
            exit 1
        fi
        
        echo "$analysis"
        log_info "Analysis complete (markdown format)"
        return
    fi
    
    # Full JSON workflow
    local analysis=$(analyze_with_claude "$raw_data")
    
    # Format output for TimeStory import
    local final_output=$(format_timestory_output "$analysis" "$DATE_PARAM")
    
    # Output the result
    echo "$final_output"
    
    # Provide import suggestions
    suggest_import_command "daily_summary.json" "$DATE_PARAM"
}


# Prerequisites check function
check_prerequisites() {
    local missing_deps=()
    
    # Check for required commands
    if ! command -v jq >/dev/null 2>&1; then
        missing_deps+=("jq")
    fi
    
    if ! command -v claude >/dev/null 2>&1; then
        missing_deps+=("claude CLI")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        echo "Please install the missing dependencies:" >&2
        for dep in "${missing_deps[@]}"; do
            case "$dep" in
                "jq")
                    echo "  - Install jq: brew install jq (macOS) or apt install jq (Linux)" >&2
                    ;;
                "claude CLI")
                    echo "  - Install Claude CLI: See https://docs.anthropic.com/en/docs/claude-code" >&2
                    ;;
            esac
        done
        exit 1
    fi
}

# Check prerequisites before running
check_prerequisites

# Run main function with error handling
if ! main; then
    log_error "Script execution failed"
    exit 1
fi