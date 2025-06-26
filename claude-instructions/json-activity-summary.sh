#!/bin/bash

# Direct MCP activity summary - outputs pure JSON

# Function to call MCP tools
call_mcp() {
    local server=$1
    local tool=$2
    local args=$3
    
    # Different servers have different CLI flags
    local cmd="$server"
    case "$server" in
        activitywatch-mcp|aw-context-mcp|git-mcp)
            cmd="$server --log-level error"
            ;;
    esac
    
    # Send initialization and tool call
    result=$(printf '%s\n%s\n' \
        '{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{}}}' \
        "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"$tool\",\"arguments\":$args}}" | \
        $cmd 2>/dev/null | \
        grep '^{' | \
        tail -n 1 | \
        jq -r '.result.content[0].text // empty' 2>/dev/null)
    
    echo "${result:-[]}"
}

# Get current date/time
DATE=$(date +%Y-%m-%d)
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Collect data from all sources
echo "Collecting activity data..." >&2

# ActivityWatch data
FOLDER_ACTIVITY=$(call_mcp "activitywatch-mcp" "get-folder-activity" '{"start":"today"}')

# Context annotations
CONTEXTS=$(call_mcp "aw-context-mcp" "query-contexts" '{"date":"today"}')

# Wispr transcriptions
TRANSCRIPTIONS=$(call_mcp "wispr-flow-mcp" "list" '{"limit":20}')

# Process folder activity to extract key metrics
FOLDER_COUNT=0
CLIENT_WORK_TIME=0
SIDE_PROJECT_TIME=0
CLIENT_ACTIVITIES=()
SIDE_ACTIVITIES=()
APPLICATIONS=()

if [ -n "$FOLDER_ACTIVITY" ] && [ "$FOLDER_ACTIVITY" != "[]" ]; then
    # Extract folder names and categorize them
    while IFS= read -r line; do
        if [[ "$line" =~ ^\*\*(.+)\*\*$ ]]; then
            folder="${BASH_REMATCH[1]}"
            # Check if it's a side project based on keywords
            if [[ "$folder" =~ "side-project"|"side project"|"opens-time-chat"|"swift-date-parser"|"claude-notify"|"activitywatch-mcp"|"wispr-flow" ]]; then
                SIDE_ACTIVITIES+=("$folder")
            else
                CLIENT_ACTIVITIES+=("$folder")
            fi
        fi
    done <<< "$FOLDER_ACTIVITY"
    
    FOLDER_COUNT=$(echo "$FOLDER_ACTIVITY" | grep -c "^\*\*" || echo 0)
fi

# Process contexts
CONTEXT_COUNT=0
CONTEXT_JSON="[]"
if [ -n "$CONTEXTS" ] && echo "$CONTEXTS" | jq -e . >/dev/null 2>&1; then
    CONTEXT_JSON="$CONTEXTS"
    CONTEXT_COUNT=$(echo "$CONTEXTS" | jq 'length' 2>/dev/null || echo 0)
fi

# Process transcriptions
WISPR_COUNT=0
WISPR_JSON="[]"
if [ -n "$TRANSCRIPTIONS" ] && echo "$TRANSCRIPTIONS" | jq -e . >/dev/null 2>&1; then
    WISPR_COUNT=$(echo "$TRANSCRIPTIONS" | jq 'length' 2>/dev/null || echo 0)
    WISPR_JSON=$(echo "$TRANSCRIPTIONS" | jq '[.[] | {
        id: .id,
        text: (if (.text | length) > 100 then .text[0:100] + "..." else .text end),
        app: .app,
        timestamp: .timestamp
    }]' 2>/dev/null || echo "[]")
fi

# Convert arrays to JSON
CLIENT_JSON=$(printf '%s\n' "${CLIENT_ACTIVITIES[@]}" | jq -R . | jq -s 'unique | .[0:5]')
SIDE_JSON=$(printf '%s\n' "${SIDE_ACTIVITIES[@]}" | jq -R . | jq -s 'unique | .[0:5]')

# Build final JSON output
jq -n \
    --arg date "$DATE" \
    --arg timestamp "$TIMESTAMP" \
    --argjson clientWork "$CLIENT_JSON" \
    --argjson sideProjects "$SIDE_JSON" \
    --argjson folderCount "$FOLDER_COUNT" \
    --argjson contextCount "$CONTEXT_COUNT" \
    --argjson wisprCount "$WISPR_COUNT" \
    '{
        summary: {
            totalActiveTime: "Data available",
            clientWork: {
                totalTime: "See folder activity",
                activities: $clientWork
            },
            sideProjects: {
                totalTime: "See folder activity",
                activities: $sideProjects
            },
            applications: ["Warp", "Claude", "Safari", "Slack", "Xcode"],
            insights: {
                peakActivity: "Check ActivityWatch dashboard",
                contextSwitches: "N/A",
                achievements: []
            }
        },
        rawData: {
            folderCount: $folderCount,
            contextCount: $contextCount,
            transcriptionCount: $wisprCount
        },
        metadata: {
            date: $date,
            generatedAt: $timestamp,
            version: "1.0"
        }
    }'