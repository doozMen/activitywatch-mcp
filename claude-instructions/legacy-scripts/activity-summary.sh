#!/bin/bash

# Exit on any error
set -e

# Function to validate JSON output
validate_json() {
    local json="$1"
    if echo "$json" | jq . >/dev/null 2>&1; then
        echo "$json"
    else
        echo "Error: Invalid JSON output" >&2
        echo "$json" >&2
        exit 1
    fi
}

# Function to extract and parse the result from Claude output
extract_result() {
    local output="$1"
    # Extract the "result" field from the JSON response
    echo "$output" | jq -r '.result' 2>/dev/null || echo "$output"
}

# Function to create standardized JSON structure
create_standardized_json() {
    local raw_result="$1"
    local today=$(date +"%Y-%m-%d")
    
    # Create a standardized JSON structure
    cat <<EOF
{
  "date": "$today",
  "summary": {
    "totalActiveTime": null,
    "clientWork": {
      "totalTime": null,
      "activities": []
    },
    "sideProjects": {
      "totalTime": null,
      "activities": []
    },
    "applications": [],
    "insights": {
      "peakActivity": null,
      "contextSwitches": null,
      "achievements": []
    }
  },
  "rawData": {
    "folderActivity": null,
    "contextAnnotations": null,
    "transcriptions": null
  },
  "metadata": {
    "generatedAt": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "version": "1.0"
  }
}
EOF
}

# MCP configuration
MCP_CONFIG='{
  "mcpServers": {
    "activitywatch": {
      "command": "activitywatch-mcp",
      "args": ["--log-level", "error"],
      "env": {
        "PATH": "$HOME/.swiftpm/bin:/usr/local/bin:/usr/bin:/bin"
      }
    },
    "aw-context": {
      "command": "aw-context-mcp",
      "args": ["--log-level", "error"],
      "env": {
        "PATH": "$HOME/.swiftpm/bin:/usr/local/bin:/usr/bin:/bin"
      }
    },
    "wispr-flow": {
      "command": "wispr-flow-mcp",
      "args": ["--log-level", "error"],
      "env": {
        "PATH": "$HOME/.swiftpm/bin:/usr/local/bin:/usr/bin:/bin"
      }
    }
  }
}'

# Prompt for generating activity summary
PROMPT='CRITICAL: You MUST respond with ONLY a valid JSON object. NO markdown, NO explanations, NO text before or after.

Your response MUST start with { and end with }

Use these MCP tools to gather data:
1. Use get-folder-activity from activitywatch with start="today"
2. Use query-contexts from aw-context with date="today"  
3. Use list from wispr-flow with limit=20

Then format the data into this EXACT JSON structure:
{
  "summary": {
    "totalActiveTime": "X hours Y minutes",
    "clientWork": {
      "totalTime": "X hours Y minutes",
      "activities": ["Daily Schedule", "CA-4456 implementation", "chameleon MR updates"]
    },
    "sideProjects": {
      "totalTime": "X hours Y minutes",
      "activities": ["swift-date-parser", "activity-watch-mcp", "claude notify"]
    },
    "applications": ["Warp", "Claude", "Safari", "Slack", "Xcode"],
    "insights": {
      "peakActivity": "09:00-11:00",
      "contextSwitches": 15,
      "achievements": ["Completed X", "Fixed Y", "Reviewed Z"]
    }
  },
  "rawData": {
    "folderCount": 25,
    "contextCount": 10,
    "transcriptionCount": 20
  }
}

REMEMBER: Start with { and end with }. Output ONLY JSON.'

# Execute the command and capture output
echo "Generating activity summary..." >&2
RESULT=$(claude --dangerously-skip-permissions --print --output-format json --mcp-config mcp-activity-config.json "$PROMPT")

# Extract the actual result content
EXTRACTED_RESULT=$(extract_result "$RESULT")

# Try to parse as JSON, if it fails, use direct MCP approach
if echo "$EXTRACTED_RESULT" | jq . >/dev/null 2>&1; then
    # If it's already valid JSON, output it
    echo "$EXTRACTED_RESULT"
else
    # If Claude returns markdown, fall back to direct MCP calls
    echo "Warning: Claude returned non-JSON output, falling back to direct MCP calls..." >&2
    exec ./json-activity-summary.sh
fi