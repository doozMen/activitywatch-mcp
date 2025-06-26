#!/bin/bash

# Claude Activity Analysis Tool
# Collects ActivityWatch data and generates comprehensive markdown analysis with Claude CLI
#
# Usage: ./claude-activity-analysis.sh [date]
# Examples:
#   ./claude-activity-analysis.sh           # Today's analysis
#   ./claude-activity-analysis.sh yesterday # Yesterday's analysis

set -euo pipefail

# Configuration
DATE_PARAM="${1:-today}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Logging functions
log_info() {
    echo "[INFO] $1" >&2
}

log_error() {
    echo "[ERROR] $1" >&2
}

log_debug() {
    echo "[DEBUG] $1" >&2
}

# Help function
show_help() {
    cat << EOF
Claude Activity Analysis Tool v3.0.0

Collects daily activity data from ActivityWatch and generates comprehensive 
markdown analysis using Claude CLI.

Usage:
    $0 [date]

Date examples:
    today           Today's activities (default)
    yesterday       Yesterday's activities  
    "3 days ago"    Activities from 3 days ago
    "last monday"   Activities from last Monday

Output:
    Comprehensive markdown analysis written to stdout

Examples:
    $0                     # Today's analysis
    $0 yesterday          # Yesterday's analysis
    $0 "3 days ago"       # Analysis from 3 days ago
    
    # Save to file
    $0 today > today-analysis.md
    
    # Pipe to conversion tool
    $0 yesterday | convert-analysis-to-json.sh > yesterday.json

EOF
}

# Parse help argument
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    show_help
    exit 0
fi

# Collect data from ActivityWatch MCP
collect_data() {
    log_info "Collecting ActivityWatch data for $DATE_PARAM"
    
    # Get comprehensive activity data
    local folder_activity=$(claude --no-cache << 'EOF'
{
    "method": "mcp__activitywatch__get-folder-activity",
    "params": {
        "start": "DATE_PARAM_PLACEHOLDER"
    }
}
EOF
)
    
    local active_buckets=$(claude --no-cache << 'EOF'  
{
    "method": "mcp__activitywatch__active-buckets", 
    "params": {
        "start": "DATE_PARAM_PLACEHOLDER"
    }
}
EOF
)

    local bucket_list=$(claude --no-cache << 'EOF'
{
    "method": "mcp__activitywatch__list-buckets",
    "params": {}
}
EOF
)

    # Replace placeholder with actual date
    folder_activity=$(echo "$folder_activity" | sed "s/DATE_PARAM_PLACEHOLDER/$DATE_PARAM/g")
    active_buckets=$(echo "$active_buckets" | sed "s/DATE_PARAM_PLACEHOLDER/$DATE_PARAM/g")
    
    # Combine into comprehensive dataset
    cat << EOF
{
    "date": "$DATE_PARAM",
    "folderActivity": $folder_activity,
    "activeBuckets": $active_buckets,
    "availableBuckets": $bucket_list
}
EOF
}

# Generate analysis with Claude
analyze_with_claude() {
    local raw_data="$1"
    
    log_info "Generating comprehensive Claude analysis for $DATE_PARAM..."
    
    local prompt="You are an expert productivity analyst. Analyze the following ActivityWatch data for $DATE_PARAM and provide a comprehensive daily summary.

ACTIVITY DATA:
$raw_data

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

    # Generate analysis with Claude CLI
    echo "$prompt" | claude -p 2>/dev/null || {
        log_error "Claude analysis failed"
        echo "# Analysis Failed"
        echo ""
        echo "Could not generate analysis for $DATE_PARAM. Please check:"
        echo "- Claude CLI is installed and working"
        echo "- ActivityWatch MCP server is running"
        echo "- Date parameter is valid: $DATE_PARAM"
        echo ""
        echo "Raw data collected:"
        echo '```json'
        echo "$raw_data"
        echo '```'
        return 1
    }
}

# Main execution
main() {
    log_info "Starting Claude Activity Analysis v3.0.0 for $DATE_PARAM"
    
    local raw_data
    raw_data=$(collect_data) || {
        log_error "Failed to collect data"
        exit 1
    }
    
    analyze_with_claude "$raw_data" || {
        log_error "Analysis failed"
        exit 1
    }
    
    log_info "Analysis complete"
}

# Run main function
main