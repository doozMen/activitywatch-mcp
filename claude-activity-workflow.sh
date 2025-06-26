#!/bin/bash

# Claude Activity Workflow
# Complete workflow: Analysis → JSON → Import to TimeStory
#
# Usage: ./claude-activity-workflow.sh [date]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATE_INPUT="${1:-today}"

# Logging functions
log_info() {
    echo "[INFO] $1" >&2
}

log_error() {
    echo "[ERROR] $1" >&2
}

log_success() {
    echo "[SUCCESS] $1" >&2
}

# Help function
show_help() {
    cat << EOF
Claude Activity Workflow v3.0.0

Complete workflow for ActivityWatch analysis and TimeStory import:
1. Generate markdown analysis with Claude
2. Convert to structured JSON
3. Import to TimeStory MCP with both formats

Usage:
    $0 [date]

Date examples:
    today, yesterday, "3 days ago", "last monday"

Output files:
    {date}-analysis.md  - Comprehensive markdown analysis
    {date}-data.json    - Structured JSON for import

Examples:
    $0                  # Today's complete workflow
    $0 yesterday       # Yesterday's workflow
    $0 "3 days ago"    # Custom date workflow

EOF
}

# Parse help
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    show_help
    exit 0
fi

# Normalize date for filenames
normalize_date_for_filename() {
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
            # Try parsing with date command
            if date -d "$input_date" '+%Y-%m-%d' 2>/dev/null; then
                date -d "$input_date" '+%Y-%m-%d'
            else
                echo "invalid-date"
            fi
            ;;
    esac
}

main() {
    local date_normalized
    date_normalized=$(normalize_date_for_filename "$DATE_INPUT")
    
    if [[ "$date_normalized" == "invalid-date" ]]; then
        log_error "Could not parse date: $DATE_INPUT"
        exit 1
    fi
    
    local analysis_file="${date_normalized}-analysis.md"
    local json_file="${date_normalized}-data.json"
    
    log_info "Starting complete workflow for $DATE_INPUT ($date_normalized)"
    
    # Step 1: Generate analysis
    log_info "Step 1: Generating markdown analysis..."
    if ./claude-activity-analysis.sh "$DATE_INPUT" > "$analysis_file"; then
        log_success "Analysis saved to: $analysis_file"
    else
        log_error "Failed to generate analysis"
        exit 1
    fi
    
    # Step 2: Convert to JSON
    log_info "Step 2: Converting to structured JSON..."
    if ./claude-instructions/scripts/convert-analysis-to-json.sh "$analysis_file" > "$json_file"; then
        log_success "JSON saved to: $json_file"
    else
        log_error "Failed to convert to JSON"
        exit 1
    fi
    
    # Step 3: Import to TimeStory (if available)
    log_info "Step 3: Importing to TimeStory..."
    local json_content markdown_content
    json_content=$(cat "$json_file")
    markdown_content=$(cat "$analysis_file")
    
    # Create import request
    local import_request
    import_request=$(cat << EOF
{
    "method": "mcp__timestory-mcp__import_with_markdown",
    "params": {
        "jsonData": $json_content,
        "markdownContent": $(echo "$markdown_content" | jq -Rs .)
    }
}
EOF
)
    
    # Execute import
    if echo "$import_request" | claude --no-cache 2>/dev/null | jq -e '.success' >/dev/null 2>&1; then
        log_success "Successfully imported to TimeStory!"
        log_info "Files generated:"
        log_info "  📄 Analysis: $analysis_file"
        log_info "  📊 JSON: $json_file"
        log_info "  💾 Imported to TimeStory database"
    else
        log_error "TimeStory import failed (but files were generated successfully)"
        log_info "Files available:"
        log_info "  📄 Analysis: $analysis_file"  
        log_info "  📊 JSON: $json_file"
    fi
    
    log_success "Workflow complete!"
}

main