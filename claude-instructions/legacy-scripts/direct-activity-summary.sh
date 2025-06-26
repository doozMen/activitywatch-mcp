#!/bin/bash

# Direct activity summary using MCP servers only (no Claude LLM)

# Function to call MCP server and get response
mcp_request() {
    local server="$1"
    local method="$2"
    local params="$3"
    
    local flags=""
    [[ "$server" == "activitywatch-mcp" || "$server" == "aw-context-mcp" ]] && flags="--log-level error"
    
    # Send both initialization and tool call
    (echo '{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{}}}';
     echo "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"$method\",\"arguments\":$params}}") | \
        $server $flags 2>/dev/null | \
        grep '^{' | tail -n 1 | \
        jq -r '.result.content[0].text // empty' 2>/dev/null
}

# Get today's data
echo "Gathering activity data..." >&2

# Get folder activity
FOLDERS=$(mcp_request "activitywatch-mcp" "get-folder-activity" '{"start":"today"}')

# Parse folder data
TOTAL_TIME="0 hours"
CLIENT_WORK=()
SIDE_PROJECTS=()
APPS=()

if [ -n "$FOLDERS" ]; then
    # Extract total time
    if [[ "$FOLDERS" =~ Time\ range:.*Total\ events\ analyzed:\ ([0-9]+) ]]; then
        EVENT_COUNT="${BASH_REMATCH[1]}"
    fi
    
    # Extract folders and categorize
    current_folder=""
    current_time=""
    
    while IFS= read -r line; do
        # Match folder names in bold
        if [[ "$line" =~ ^-\ \*\*(.+)\*\* ]] || [[ "$line" =~ ^\*\*(.+)\*\*$ ]]; then
            current_folder="${BASH_REMATCH[1]}"
        fi
        
        # Match time lines
        if [[ "$line" =~ Time:\ ([0-9]+h\ [0-9]+m|[0-9]+m\ [0-9]+s) ]]; then
            current_time="${BASH_REMATCH[1]}"
            
            if [ -n "$current_folder" ]; then
                # Check if this is the main work (Daily Schedule)
                if [[ "$current_folder" == *"Daily Schedule"* ]]; then
                    TOTAL_TIME="$current_time"
                fi
                
                # Categorize folder
                if [[ "$current_folder" =~ "side.?project"|"= side-project"|"opens-time-chat"|"swift-date-parser"|"claude-notify"|"mcp"|"wispr-flow" ]]; then
                    SIDE_PROJECTS+=("$current_folder")
                elif [[ ! "$current_folder" =~ ^(Warp|Cursor|Finder|Xcode|Safari|Chrome|Slack|Teams)$ ]]; then
                    CLIENT_WORK+=("$current_folder")
                fi
            fi
            
            current_folder=""
            current_time=""
        fi
        
        # Extract application names from section headers
        if [[ "$line" =~ ^###\ (.+)$ ]]; then
            app="${BASH_REMATCH[1]}"
            [[ ! " ${APPS[@]} " =~ " ${app} " ]] && APPS+=("$app")
        fi
    done <<< "$FOLDERS"
fi

# Get contexts
CONTEXTS=$(mcp_request "aw-context-mcp" "query-contexts" '{"date":"today"}')
CONTEXT_COUNT=0
if [ -n "$CONTEXTS" ] && echo "$CONTEXTS" | jq -e . >/dev/null 2>&1; then
    CONTEXT_COUNT=$(echo "$CONTEXTS" | jq 'length' 2>/dev/null || echo 0)
fi

# Get transcriptions
WISPR=$(mcp_request "wispr-flow-mcp" "list" '{"limit":10}')
WISPR_COUNT=0
if [ -n "$WISPR" ] && echo "$WISPR" | jq -e . >/dev/null 2>&1; then
    WISPR_COUNT=$(echo "$WISPR" | jq 'length' 2>/dev/null || echo 0)
fi

# Remove duplicates and limit arrays
CLIENT_WORK=($(printf '%s\n' "${CLIENT_WORK[@]}" | sort -u | head -5))
SIDE_PROJECTS=($(printf '%s\n' "${SIDE_PROJECTS[@]}" | sort -u | head -5))
APPS=($(printf '%s\n' "${APPS[@]}" | sort -u | head -5))

# Default apps if none found
[ ${#APPS[@]} -eq 0 ] && APPS=("Warp" "Claude" "Safari" "Slack" "Xcode")

# Output JSON
cat <<EOF | jq '.'
{
  "summary": {
    "totalActiveTime": "${TOTAL_TIME:-Unknown}",
    "clientWork": {
      "totalTime": "See folder details",
      "activities": $(printf '%s\n' "${CLIENT_WORK[@]}" | jq -R . | jq -s .)
    },
    "sideProjects": {
      "totalTime": "See folder details", 
      "activities": $(printf '%s\n' "${SIDE_PROJECTS[@]}" | jq -R . | jq -s .)
    },
    "applications": $(printf '%s\n' "${APPS[@]}" | jq -R . | jq -s .),
    "insights": {
      "peakActivity": "Check ActivityWatch",
      "contextSwitches": ${CONTEXT_COUNT},
      "achievements": []
    }
  },
  "rawData": {
    "folderCount": $((${#CLIENT_WORK[@]} + ${#SIDE_PROJECTS[@]})),
    "contextCount": ${CONTEXT_COUNT},
    "transcriptionCount": ${WISPR_COUNT}
  },
  "metadata": {
    "date": "$(date +%Y-%m-%d)",
    "generatedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "version": "1.0"
  }
}
EOF