#!/bin/bash
#
# ⚡ Performance Hunt Skill
# The tracker of inefficiency and resource waste
#
# Usage: ./skills/performance_hunt.sh <file> <diff_content> [model]
# Outputs: JSON array of findings to stdout
#

set -euo pipefail

FILE="${1:-}"
DIFF_CONTENT="${2:-}"
MODEL="${3:-${MODEL:-arcee/trinity-mini}}"
ARCEE_API_KEY="${ARCEE_API_KEY:-}"

if [ -z "$FILE" ] || [ -z "$DIFF_CONTENT" ]; then
  echo "[]"
  exit 0
fi

# Get the directory where this script lives
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPT_FILE="${SKILL_DIR}/../prompts/performance-hunter.md"

# Load prompt
PROMPT=$(cat "$PROMPT_FILE" 2>/dev/null || echo "Find performance issues in this code.")
PROMPT="${PROMPT}

File: $FILE"

# Truncate diff if too large
TRUNCATED_DIFF=$(echo "$DIFF_CONTENT" | head -c 15000)

FULL_PROMPT="${PROMPT}

=== CODE CHANGES ===
${TRUNCATED_DIFF}

=== OUTPUT FORMAT ===
Return ONLY a JSON array of findings. Each finding must have:
- file: string (filename)
- line: number or null
- severity: \"critical\", \"warning\", or \"note\"
- message: string (description of the performance issue)
- suggestion: string (optimization advice)

Example: [{\"file\":\"db.py\",\"line\":45,\"severity\":\"warning\",\"message\":\"N+1 query pattern detected in loop\",\"suggestion\":\"Use eager loading or batch queries\"}]

If no issues found, return empty array: []"

# Call Arcee API
attempt=0
max_attempts=3

while [ $attempt -lt $max_attempts ]; do
  RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST "https://api.arcee.ai/api/v1/chat/completions" \
    -H "Authorization: Bearer $ARCEE_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{
      \"model\": \"$MODEL\",
      \"messages\": [
        {\"role\": \"system\", \"content\": \"You are the Performance Hunter. Find N+1 queries, memory leaks, inefficient algorithms, and resource waste. Focus on issues that matter at scale.\"},
        {\"role\": \"user\", \"content\": $(echo "$FULL_PROMPT" | jq -Rs .)}
      ],
      \"temperature\": 0.1,
      \"max_tokens\": 4000
    }" 2>/dev/null || echo -e "\n000")
  
  HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
  BODY=$(echo "$RESPONSE" | sed '$d')
  
  if [ "$HTTP_CODE" = "200" ]; then
    CONTENT=$(echo "$BODY" | jq -r '.choices[0].message.content // empty' 2>/dev/null || echo "")
    
    if [ -n "$CONTENT" ]; then
      if echo "$CONTENT" | jq -e 'if type == "array" then . else error("not array") end' >/dev/null 2>&1; then
        echo "$CONTENT"
        exit 0
      fi
      
      EXTRACTED=$(echo "$CONTENT" | grep -oP '\[.*\]' | tail -1)
      if [ -n "$EXTRACTED" ] && echo "$EXTRACTED" | jq -e '.' >/dev/null 2>&1; then
        echo "$EXTRACTED"
        exit 0
      fi
    fi
  fi
  
  attempt=$((attempt + 1))
  sleep 2
done

echo "[]"
