#!/bin/bash
#
# 🧛‍♂️ Bug Hunter D33 — The Summoning
# Main entry point that delegates to specialized skills
#

set -euo pipefail

# Configuration
ARCEE_API_KEY="${ARCEE_API_KEY:-}"
MODEL="${MODEL:-trinity-mini}"
PASSES="${PASSES:-logic,security,judge}"
SEVERITY_THRESHOLD="${SEVERITY_THRESHOLD:-warning}"
MAX_FILES="${MAX_FILES:-20}"
PR_NUMBER="${PR_NUMBER:-}"
BASE_REF="${BASE_REF:-main}"
HEAD_SHA="${HEAD_SHA:-}"
EXCLUDE_TESTS="${EXCLUDE_TESTS:-true}"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="${SCRIPT_DIR}/../skills"

# Output files
FINDINGS_FILE=".bug-hunter/findings.json"
STATUS_FILE=".bug-hunter/status"

# Track if outputs have been set
OUTPUTS_SET="${GITHUB_OUTPUT}.set"

# Ensure outputs are always written, even on crash
cleanup() {
	local exit_code=$?
	if [ -n "${GITHUB_OUTPUT:-}" ] && [ ! -f "$OUTPUTS_SET" ]; then
		echo "status=error" >>"$GITHUB_OUTPUT"
		echo "findings=[]" >>"$GITHUB_OUTPUT"
		echo "critical-count=0" >>"$GITHUB_OUTPUT"
		echo "warning-count=0" >>"$GITHUB_OUTPUT"
		log "⚠️ Hunt ended unexpectedly. Setting safe defaults."
	fi
	exit $exit_code
}
trap cleanup EXIT

log() {
	echo "[Bug Hunter D33] $1" >&2
}

# Get changed files
get_changed_files() {
	local files
	if [ -n "$PR_NUMBER" ]; then
		files=$(git diff --name-only "origin/$BASE_REF...HEAD" -- '*.py' '*.js' '*.ts' '*.jsx' '*.tsx' '*.go' '*.rs' '*.java' '*.rb' '*.php' 2>/dev/null || true)
	else
		files=$(git diff --name-only HEAD -- '*.py' '*.js' '*.ts' '*.jsx' '*.tsx' '*.go' '*.rs' '*.java' '*.rb' '*.php' 2>/dev/null || true)
	fi

	# Filter test files if enabled
	if [ "$EXCLUDE_TESTS" = "true" ]; then
		local filter_output
		local filtered_files
		local excluded_count

		filter_output=$(filter_test_files "$files")
		# Extract count from last line
		excluded_count=$(echo "$filter_output" | tail -n 1)
		# Get filtered files (all lines except last)
		filtered_files=$(echo "$filter_output" | sed '$d')

		if [ "$excluded_count" -gt 0 ] 2>/dev/null; then
			log "Excluded $excluded_count test files (EXCLUDE_TESTS=true)"
		fi
		files="$filtered_files"
	fi

	if [ "$MAX_FILES" -gt 0 ]; then
		echo "$files" | head -n "$MAX_FILES"
	else
		echo "$files"
	fi
}

# Get file diff
get_file_diff() {
	local file="$1"
	if [ -n "$PR_NUMBER" ]; then
		git diff "origin/$BASE_REF...HEAD" -- "$file" 2>/dev/null || cat "$file" 2>/dev/null || echo ""
	else
		git diff HEAD -- "$file" 2>/dev/null || cat "$file" 2>/dev/null || echo ""
	fi
}

# Returns true (exit 0) if file should be excluded as a test file
is_test_file() {
	local file="$1"
	local basename
	basename=$(basename "$file")

	# Check file name patterns
	case "$basename" in
	*.test.* | *.spec.*) return 0 ;;
	test_*.py) return 0 ;;
	*_test.py | *_test.go) return 0 ;;
	*Test.java | Test*.java) return 0 ;;
	*_spec.rb | *_test.rb) return 0 ;;
	*Test.php | *Spec.php) return 0 ;;
	esac

	# Check directory patterns
	case "$file" in
	*/__tests__/* | */test/* | */tests/* | */spec/* | */specs/*)
		return 0
		;;
	esac

	return 1
}

# Filters test files from a list and returns count via stdout (last line)
filter_test_files() {
	local files="$1"
	local excluded_count=0
	local excluded_files=""

	while IFS= read -r file; do
		[ -z "$file" ] && continue
		if is_test_file "$file"; then
			((excluded_count++))
			excluded_files="$excluded_files$file
"
		else
			echo "$file"
		fi
	done <<<"$files"

	# Log excluded files to stderr
	if [ -n "$excluded_files" ]; then
		while IFS= read -r file; do
			[ -n "$file" ] && log "  → Excluded test file: $file"
		done <<<"$excluded_files"
	fi

	# Return excluded count via stdout (last line)
	echo "$excluded_count"
}

# Run a specific skill
run_skill() {
	local skill_name="$1"
	local file="$2"
	local diff_content="$3"
	local skill_model="${4:-$MODEL}"

	local skill_script="${SKILLS_DIR}/${skill_name}_hunt.sh"

	if [ ! -f "$skill_script" ]; then
		log "⚠️ Skill not found: $skill_script"
		echo "[]"
		return
	fi

	if [ ! -x "$skill_script" ]; then
		chmod +x "$skill_script"
	fi

	# Call the skill with file, diff content, and model
	# Skills output JSON findings to stdout
	"$skill_script" "$file" "$diff_content" "$skill_model"
}

# Main hunt
main() {
	log "🧛‍♂️ Bug Hunter D33 awakens..."
	log "Skills directory: $SKILLS_DIR"
	log "Model: $MODEL | Passes: $PASSES | Max files: $MAX_FILES"

	# Validate API key
	if [ -z "$ARCEE_API_KEY" ]; then
		log "🔴 ARCEE_API_KEY not set. The hunter cannot hunt without tools."
		echo "failure" >"$STATUS_FILE"
		echo "[]" | jq '.' >"$FINDINGS_FILE"
		exit 1
	fi

	# Get changed files
	local files
	files=$(get_changed_files)

	if [ -z "$files" ]; then
		log "No code files changed. The night is quiet."
		echo "success" >"$STATUS_FILE"
		echo "[]" | jq '.' >"$FINDINGS_FILE"

		# Set outputs for GitHub Actions
		if [ -n "${GITHUB_OUTPUT:-}" ]; then
			echo "status=success" >>"$GITHUB_OUTPUT"
			echo "findings=[]" >>"$GITHUB_OUTPUT"
			echo "critical-count=0" >>"$GITHUB_OUTPUT"
			echo "warning-count=0" >>"$GITHUB_OUTPUT"
			touch "$OUTPUTS_SET"
		fi
		exit 0
	fi

	log "Tracking $(echo "$files" | wc -l) files..."

	# Initialize findings array
	local all_findings="[]"

	# Parse passes
	IFS=',' read -ra PASS_ARRAY <<<"$PASSES"

	# Process each file
	while IFS= read -r file; do
		[ -z "$file" ] && continue
		[ ! -f "$file" ] && continue

		log "Hunting in: $file"

		local diff_content
		diff_content=$(get_file_diff "$file")

		if [ -z "$diff_content" ]; then
			continue
		fi

		# Run each skill (except judge - judge runs once at the end)
		for pass in "${PASS_ARRAY[@]}"; do
			pass=$(echo "$pass" | xargs) # trim whitespace

			# Skip judge in per-file loop - it runs once at the end
			if [ "$pass" = "judge" ]; then
				continue
			fi

			# Map pass name to skill
			local skill_name="$pass"

			# Allow per-skill model overrides via environment
			local skill_model="$MODEL"
			case "$pass" in
			security)
				skill_model="${SECURITY_MODEL:-$MODEL}"
				;;
			logic)
				skill_model="${LOGIC_MODEL:-$MODEL}"
				;;
			performance)
				skill_model="${PERFORMANCE_MODEL:-$MODEL}"
				;;
			esac

			log "  → Summoning ${pass} hunter (${skill_model})..."

			local findings
			findings=$(run_skill "$skill_name" "$file" "$diff_content" "$skill_model")

			# Validate and sanitize findings JSON
			if echo "$findings" | jq -e '.' >/dev/null 2>&1; then
				findings=$(echo "$findings" | jq --arg file "$file" '[.[] | .file = ($file // .file)]')
				# Merge into all_findings with defensive parsing
				all_findings=$(echo "$all_findings" "$findings" | jq -s 'add // []' 2>/dev/null || echo "[]")
			else
				log "  ⚠️ Invalid JSON from ${pass} hunter, skipping"
			fi
		done
	done <<<"$files"

	# Count severities
	local critical_count
	local warning_count
	# Defensive: ensure all_findings is valid JSON before parsing
	all_findings=$(echo "$all_findings" | jq '.' 2>/dev/null || echo "[]")
	critical_count=$(echo "$all_findings" | jq '[.[] | select(.severity == "critical")] | length' 2>/dev/null || echo "0")
	warning_count=$(echo "$all_findings" | jq '[.[] | select(.severity == "warning")] | length' 2>/dev/null || echo "0")

	log "Hunt complete. Found: $critical_count critical, $warning_count warnings"

	# === TWO-PASS VERIFICATION ===
	# Run the Judge to verify findings, remove false positives, deduplicate
	if [ "$all_findings" != "[]" ] && [ "$all_findings" != "null" ]; then
		# Check if judge is enabled (default: enabled if findings exist)
		if [[ "$PASSES" == *"judge"* ]] || [ -z "${DISABLE_JUDGE:-}" ]; then
			log "⚖️ Summoning the Judge for verification..."

			local judge_model="${JUDGE_MODEL:-trinity-mini}"
			local verified_findings
			verified_findings=$("$SKILLS_DIR/judge_hunt.sh" "$all_findings" "$judge_model")

			if [ -n "$verified_findings" ] && echo "$verified_findings" | jq -e '.' >/dev/null 2>&1; then
				# Filter to only verified findings
				all_findings=$(echo "$verified_findings" | jq '[.[] | select(.verified == true)]' 2>/dev/null || echo "$verified_findings")
				log "⚖️ Judge verified. $(echo "$all_findings" | jq 'length') findings remain."
			else
				log "⚖️ Judge verification failed, keeping original findings."
			fi
		fi
	fi

	# Recount after verification (defensive)
	all_findings=$(echo "$all_findings" | jq '.' 2>/dev/null || echo "[]")
	critical_count=$(echo "$all_findings" | jq '[.[] | select(.severity == "critical")] | length' 2>/dev/null || echo "0")
	warning_count=$(echo "$all_findings" | jq '[.[] | select(.severity == "warning")] | length' 2>/dev/null || echo "0")

	# Determine status
	local status="success"
	if [ "$critical_count" -gt 0 ]; then
		status="failure"
	elif [ "$warning_count" -gt 0 ]; then
		status="warning"
	fi

	# Save outputs (defensive)
	echo "$status" >"$STATUS_FILE"
	echo "$all_findings" | jq '.' 2>/dev/null >"$FINDINGS_FILE" || echo "[]" >"$FINDINGS_FILE"

	# Set GitHub Actions outputs
	if [ -n "${GITHUB_OUTPUT:-}" ]; then
		echo "status=$status" >>"$GITHUB_OUTPUT"
		echo "findings=$all_findings" >>"$GITHUB_OUTPUT"
		echo "critical-count=$critical_count" >>"$GITHUB_OUTPUT"
		echo "warning-count=$warning_count" >>"$GITHUB_OUTPUT"
		touch "$OUTPUTS_SET"
	fi

	log "🧛‍♂️ The hunter rests. Status: $status"

	if [ "$status" = "failure" ]; then
		exit 1
	fi
}

main "$@"
