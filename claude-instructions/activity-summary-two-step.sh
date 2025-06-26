#!/bin/bash

# Two-step activity summary: First get data, then convert to JSON

# Step 1: Get activity data in any format
echo "Step 1: Collecting activity data..." >&2

ACTIVITY_DATA=$(claude --dangerously-skip-permissions --print --mcp-config mcp-activity-config.json "
Analyze my activity for today using:
1. get-folder-activity from activitywatch (start='today')
2. query-contexts from aw-context (date='today')
3. list from wispr-flow (limit=20)

Summarize:
- Total active time
- Client work activities and time
- Side project activities and time
- Top applications used
- Key insights
")

# Save the markdown/text response
echo "$ACTIVITY_DATA" > /tmp/activity-data.txt

# Step 2: Convert to JSON using Claude
echo "Step 2: Converting to JSON..." >&2

JSON_OUTPUT=$(claude --dangerously-skip-permissions --print --output-format json "
Convert this activity summary to JSON:

$ACTIVITY_DATA

Output ONLY this exact JSON structure (no markdown):
{
  \"summary\": {
    \"totalActiveTime\": \"extracted total time\",
    \"clientWork\": {
      \"totalTime\": \"extracted client time\",
      \"activities\": [\"list of client activities\"]
    },
    \"sideProjects\": {
      \"totalTime\": \"extracted side project time\",
      \"activities\": [\"list of side projects\"]
    },
    \"applications\": [\"list of applications\"],
    \"insights\": {
      \"peakActivity\": \"peak hours\",
      \"contextSwitches\": 0,
      \"achievements\": [\"list of achievements\"]
    }
  },
  \"rawData\": {
    \"folderCount\": 0,
    \"contextCount\": 0,
    \"transcriptionCount\": 0
  }
}

Start with { and end with }. JSON only.
")

# Extract result from Claude's JSON response
if echo "$JSON_OUTPUT" | jq -e '.result' >/dev/null 2>&1; then
    # Extract the result field
    FINAL_JSON=$(echo "$JSON_OUTPUT" | jq -r '.result')
    
    # Check if the result is valid JSON
    if echo "$FINAL_JSON" | jq . >/dev/null 2>&1; then
        echo "$FINAL_JSON"
    else
        # If not valid JSON, try to extract JSON from the text
        echo "$FINAL_JSON" | grep -o '{.*}' | jq . 2>/dev/null || ./json-activity-summary.sh
    fi
else
    # Fallback to direct MCP calls
    echo "Warning: Failed to get JSON from Claude, using direct MCP calls..." >&2
    ./json-activity-summary.sh
fi