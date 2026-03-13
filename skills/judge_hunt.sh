#!/bin/bash
#
# ⚖️ Judge Hunt Skill
# The verifier - cross-checks findings, removes false positives, ranks by severity
#
# Usage: ./skills/judge_hunt.sh <findings_json> [model]
# Input: JSON array of findings from all hunters
# Output: Verified, deduplicated, ranked JSON array
#

set -euo pipefail

FINDINGS_JSON="${1:-}"
MODEL="${2:-${MODEL:-trinity-mini}}"
ARCEE_API_KEY="${ARCEE_API_KEY:-}"

if [ -z "$FINDINGS_JSON" ] || [ "$FINDINGS_JSON" = "[]" ]; then
	echo "[]"
	exit 0
fi

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPT_FILE="${SKILL_DIR}/../prompts/judge-hunter.md"

PROMPT=$(cat "$PROMPT_FILE" 2>/dev/null || echo "Verify and rank these code review findings.")
PROMPT="${PROMPT}

=== FINDINGS TO VERIFY ===
$FINDINGS_JSON

=== YOUR TASK ===
1. Read each finding carefully
2. Determine if it's a real issue or likely false positive
3. For real issues, verify the severity rating is appropriate
4. Look for duplicates (same issue reported multiple times)
5. Rank remaining findings by true severity

=== OUTPUT FORMAT ===
Return a verified JSON array with this structure:
- file: string
- line: number or null
- severity: \"critical\", \"warning\", or \"note\" (adjusted if needed)
- message: string (clarified if vague)
- suggestion: string (refined if needed)
- verified: boolean (true if real issue, false if likely false positive)
- duplicate_of: string or null (if duplicate, reference original file:line)

Only include findings where verified=true.

Example: [{\"file\":\"main.py\",\"line\":42,\"severity\":\"critical\",\"message\":\"Potential null dereference\",\"suggestion\":\"Add null check\",\"verified\":true,\"duplicate_of\":null}]

If all findings are false positives, return: []"

attempt=0
max_attempts=3

# Build JSON payload using jq for proper escaping
JSON_PAYLOAD=$(jq -n \
	--arg model "$MODEL" \
	--arg system "You are the Judge. A senior code reviewer who verifies findings, catches false positives, and ensures only real issues are reported. Be skeptical but fair. Prioritize signal over noise." \
	--arg prompt "$PROMPT" \
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
		CONTENT=$(echo "$BODY" | jq -r '.choices[0].message.content // empty' 2>/dev/null || echo "")

		if [ -n "$CONTENT" ]; then
			if echo "$CONTENT" | jq -e 'if type == \"array\" then . else error(\"not array\") end' >/dev/null 2>&1; then
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

# On failure, return original findings (trust but verify)
echo "$FINDINGS_JSON"
