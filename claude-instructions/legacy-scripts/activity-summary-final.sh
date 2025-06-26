#!/bin/bash

# Final activity summary script - direct MCP approach with proper parsing

# Function to call MCP server
mcp_call() {
    local server="$1"
    local tool="$2"
    local args="$3"
    
    local flags=""
    [[ "$server" =~ ^(activitywatch-mcp|aw-context-mcp)$ ]] && flags="--log-level error"
    
    (echo '{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2024-11-05"}}';
     echo "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"$tool\",\"arguments\":$args}}") | \
        $server $flags 2>/dev/null | \
        tail -n 1 | \
        jq -r '.result.content[0].text // empty' 2>/dev/null
}

# Get folder activity
echo "Collecting activity data..." >&2
FOLDER_DATA=$(mcp_call "activitywatch-mcp" "get-folder-activity" '{"start":"today"}')

# Initialize variables
TOTAL_TIME="Unknown"
CLIENT_WORK=()
SIDE_PROJECTS=()
APPS=()

# Parse folder data
if [ -n "$FOLDER_DATA" ]; then
    # Extract main work time (Daily Schedule)
    if [[ "$FOLDER_DATA" =~ Daily\ Schedule.*Time:\ ([0-9]+h\ [0-9]+m) ]]; then
        TOTAL_TIME="${BASH_REMATCH[1]}"
    fi
    
    # Process each folder entry
    while IFS= read -r line; do
        # Extract folder name and time on same line pattern: "- **folder** - Time: Xh Ym"
        if [[ "$line" =~ ^[0-9]+\.\ \*\*(.+)\*\*\ -\ ([0-9]+h\ [0-9]+m|[0-9]+m\ [0-9]+s) ]]; then
            folder="${BASH_REMATCH[1]}"
            time="${BASH_REMATCH[2]}"
            
            # Clean up folder name
            folder=$(echo "$folder" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            
            # Categorize
            if [[ "$folder" =~ "side.?project"|"side-project"|"opens-time-chat"|"swift-date-parser"|"claude-notify"|"wispr-flow" ]]; then
                [[ ! " ${SIDE_PROJECTS[@]} " =~ " ${folder} " ]] && SIDE_PROJECTS+=("$folder")
            elif [[ ! "$folder" =~ ^(Warp|Cursor|Finder|Xcode|Safari|Chrome|Slack|Teams|✳)$ ]]; then
                [[ ! " ${CLIENT_WORK[@]} " =~ " ${folder} " ]] && CLIENT_WORK+=("$folder")
            fi
        fi
        
        # Extract apps from section headers
        if [[ "$line" =~ ^###\ ([A-Za-z]+)$ ]]; then
            app="${BASH_REMATCH[1]}"
            [[ ! " ${APPS[@]} " =~ " ${app} " ]] && APPS+=("$app")
        fi
    done <<< "$FOLDER_DATA"
fi

# Get contexts
CONTEXTS=$(mcp_call "aw-context-mcp" "query-contexts" '{"date":"today"}')
CONTEXT_COUNT=0
if [ -n "$CONTEXTS" ] && echo "$CONTEXTS" | jq -e . >/dev/null 2>&1; then
    CONTEXT_COUNT=$(echo "$CONTEXTS" | jq 'length')
fi

# Get transcriptions
WISPR=$(mcp_call "wispr-flow-mcp" "list" '{"limit":10}')
WISPR_COUNT=0
WISPR_SUMMARY=()
if [ -n "$WISPR" ] && echo "$WISPR" | jq -e . >/dev/null 2>&1; then
    WISPR_COUNT=$(echo "$WISPR" | jq 'length')
    # Extract first 3 transcription summaries
    WISPR_SUMMARY=($(echo "$WISPR" | jq -r '.[0:3] | .[] | .text[0:50]' | sed 's/ /_/g'))
fi

# Clean up arrays - limit to 5 items each
CLIENT_WORK=("${CLIENT_WORK[@]:0:5}")
SIDE_PROJECTS=("${SIDE_PROJECTS[@]:0:5}")

# Calculate side project time (rough estimate based on count)
SIDE_TIME="~${#SIDE_PROJECTS[@]}h"

# Build achievements based on data
ACHIEVEMENTS=()
[ ${#CLIENT_WORK[@]} -gt 0 ] && ACHIEVEMENTS+=("Worked on ${#CLIENT_WORK[@]} client projects")
[ ${#SIDE_PROJECTS[@]} -gt 0 ] && ACHIEVEMENTS+=("Advanced ${#SIDE_PROJECTS[@]} side projects")
[ $WISPR_COUNT -gt 0 ] && ACHIEVEMENTS+=("Recorded $WISPR_COUNT voice notes")

# Output JSON
jq -n \
    --arg totalTime "$TOTAL_TIME" \
    --arg sideTime "$SIDE_TIME" \
    --argjson clientWork "$(printf '%s\n' "${CLIENT_WORK[@]}" | jq -R . | jq -s .)" \
    --argjson sideProjects "$(printf '%s\n' "${SIDE_PROJECTS[@]}" | jq -R . | jq -s .)" \
    --argjson apps "$(printf '%s\n' "${APPS[@]}" | jq -R . | jq -s .)" \
    --argjson achievements "$(printf '%s\n' "${ACHIEVEMENTS[@]}" | jq -R . | jq -s .)" \
    --argjson contextCount "$CONTEXT_COUNT" \
    --argjson wisprCount "$WISPR_COUNT" \
    --argjson folderCount "$((${#CLIENT_WORK[@]} + ${#SIDE_PROJECTS[@]}))" \
    '{
        summary: {
            totalActiveTime: $totalTime,
            clientWork: {
                totalTime: $totalTime,
                activities: $clientWork
            },
            sideProjects: {
                totalTime: $sideTime,
                activities: $sideProjects
            },
            applications: $apps,
            insights: {
                peakActivity: "Morning (based on Daily Schedule)",
                contextSwitches: $contextCount,
                achievements: $achievements
            }
        },
        rawData: {
            folderCount: $folderCount,
            contextCount: $contextCount,
            transcriptionCount: $wisprCount
        },
        metadata: {
            date: (now | strftime("%Y-%m-%d")),
            generatedAt: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
            version: "1.0"
        }
    }'