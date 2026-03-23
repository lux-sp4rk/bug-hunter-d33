#!/bin/bash
#
# 🔒 Security Hunt Skill
# The tracker of vulnerabilities and data leaks
#
# Usage: ./skills/security_hunt.sh <file> <diff_content> [model]
# Outputs: JSON array of findings to stdout
#

set -euo pipefail

FILE="${1:-}"
DIFF_CONTENT="${2:-}"
MODEL="${3:-${MODEL:-trinity-mini}}"
ARCEE_API_KEY="${ARCEE_API_KEY:-}"

if [ -z "$FILE" ] || [ -z "$DIFF_CONTENT" ]; then
	echo "[]"
	exit 0
fi

# Get the directory where this script lives
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPT_FILE="${SKILL_DIR}/../prompts/security-hunter.md"

# Load prompt
PROMPT=$(cat "$PROMPT_FILE" 2>/dev/null || echo "Find security vulnerabilities in this code.")
PROMPT="${PROMPT}

File: $FILE"

# Truncate diff if too large
TRUNCATED_DIFF=$(head -c 15000 <<<"$DIFF_CONTENT")

FULL_PROMPT="${PROMPT}

=== CODE CHANGES ===
${TRUNCATED_DIFF}

=== OUTPUT FORMAT ===
Return ONLY a JSON array of findings. Each finding must have:
- file: string (filename)
- line: number or null
- severity: \"critical\", \"warning\", or \"note\"
- message: string (description of the vulnerability)
- suggestion: string (remediation advice)

Example: [{\"file\":\"auth.py\",\"line\":23,\"severity\":\"critical\",\"message\":\"SQL injection vulnerability in query construction\",\"suggestion\":\"Use parameterized queries instead of string concatenation\"}]

If no issues found, return empty array: []"

# Call Arcee API
attempt=0
max_attempts=3

# Build JSON payload using jq for proper escaping
JSON_PAYLOAD=$(jq -n \
	--arg model "$MODEL" \
	--arg system "You are the Security Hunter. Find SQL injection, XSS, auth bypasses, hardcoded secrets, and all security vulnerabilities. Be thorough. When in doubt, report." \
	--arg prompt "$FULL_PROMPT" \
	'{
		model: $model,
		messages: [
			{role: "system", content: $system},
			{role: "user", content: $prompt}
		],
		temperature: 0.1,
		max_tokens: 4000
	}')

while [ $attempt -lt $max_attempts ]; do
	RESPONSE=$(curl -s -w "\n%{http_code}" \
		-X POST "https://api.arcee.ai/api/v1/chat/completions" \
		-H "Authorization: Bearer $ARCEE_API_KEY" \
		-H "Content-Type: application/json" \
		-d "$JSON_PAYLOAD" 2>/dev/null || echo -e "\n000")

	HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
	BODY=$(echo "$RESPONSE" | sed '$d')

	if [ "$HTTP_CODE" = "200" ]; then
		CONTENT=$(echo "$BODY" | jq -r '.choices[0].message.content // .choices[0].message.reasoning_content // empty' 2>/dev/null || echo "")

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
