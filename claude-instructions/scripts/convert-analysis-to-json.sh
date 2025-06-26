#!/bin/bash

# Convert existing Claude analysis to TimeStory JSON format
# Usage: cat analysis.md | ./convert-analysis-to-json.sh > output.json
# Or: ./convert-analysis-to-json.sh analysis.md > output.json

set -euo pipefail

# Colors for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1" >&2; }

# Get input - either from file argument or stdin
if [ $# -gt 0 ] && [ -f "$1" ]; then
    analysis_content=$(cat "$1")
    log_info "Converting analysis from file: $1"
elif [ ! -t 0 ]; then
    analysis_content=$(cat)
    log_info "Converting analysis from stdin"
else
    echo "Usage: $0 [analysis_file.md]" >&2
    echo "   or: cat analysis.md | $0" >&2
    exit 1
fi

# Check prerequisites
if ! command -v claude >/dev/null 2>&1; then
    log_error "Claude CLI is required. See: https://docs.anthropic.com/en/docs/claude-code"
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    log_error "jq is required. Install with: brew install jq"
    exit 1
fi

log_info "Converting analysis to TimeStory JSON format..."

# Create conversion prompt
conversion_prompt="Convert this daily productivity analysis into a valid JSON object that matches the TimeStory import schema exactly.

Requirements:
- Use snake_case for all field names
- Date in YYYY-MM-DD format (use today's date: $(date +%Y-%m-%d))
- Times in HH:MM format (24-hour)
- Duration in minutes
- Health scores 0-100, achievement levels 1-5
- Include timezone as \"Europe/Brussels\"
- Base all data on the analysis provided - don't invent information

Required structure:
{
  \"date\": \"$(date +%Y-%m-%d)\",
  \"timezone\": \"Europe/Brussels\", 
  \"timeSummary\": {
    \"startTime\": \"09:00\",
    \"endTime\": \"17:30\",
    \"totalDurationMinutes\": 510
  }
}

Optional sections to include based on the analysis:
- achievements: array of accomplishments with type (primary/secondary), title, description
- timelinePhases: work blocks with startTime, endTime, title, category (client_work/side_project)
- activityDistribution: time in minutes by category (development, documentation, etc)
- folderActivity: projects worked on with time spent
- workSummary: breakdown of clientWork vs sideProjects
- insights: productivity patterns and recommendations
- productivityMetrics: scores and completion rates

Output only valid JSON, no markdown formatting or explanations.

Analysis to convert:

$analysis_content"

# Send to Claude and extract JSON
log_info "Sending to Claude for conversion..."
claude_output=$(claude -p "$conversion_prompt" 2>/dev/null)

if [ $? -ne 0 ]; then
    log_error "Claude conversion failed"
    exit 1
fi

# Extract JSON from Claude's response
# Try multiple extraction methods
json_result=""

# Method 1: Look for ```json blocks
if echo "$claude_output" | grep -q '```json'; then
    json_result=$(echo "$claude_output" | sed -n '/```json/,/```/p' | sed '1d;$d')
    log_info "Found JSON in code block"
elif echo "$claude_output" | grep -q '{'; then
    # Method 2: Extract from first { to last }
    json_result=$(echo "$claude_output" | sed -n '/{/,/}/p')
    log_info "Extracted JSON from braces"
else
    # Method 3: Use entire output
    json_result="$claude_output"
    log_info "Using entire Claude output"
fi

# Validate and output JSON
if echo "$json_result" | jq . >/dev/null 2>&1; then
    echo "$json_result" | jq .
    log_success "Successfully converted analysis to valid TimeStory JSON"
else
    log_error "Generated invalid JSON, outputting raw result:"
    echo "$json_result" >&2
    
    # Fallback: create minimal valid structure
    log_info "Creating fallback minimal structure..."
    cat << EOF | jq .
{
  "date": "$(date +%Y-%m-%d)",
  "timezone": "Europe/Brussels",
  "timeSummary": {
    "startTime": "09:00",
    "endTime": "17:30",
    "totalDurationMinutes": 510
  },
  "metadata": {
    "note": "Conversion failed, minimal structure provided",
    "originalAnalysis": "See stderr for original analysis"
  }
}
EOF
fi