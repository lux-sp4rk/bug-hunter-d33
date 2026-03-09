#!/bin/bash
#
# 🧛‍♂️ Bug Hunter D33 — The Summoning
# Main entry point that delegates to specialized skills
#

set -euo pipefail

# Configuration
ARCEE_API_KEY="${ARCEE_API_KEY:-}"
MODEL="${MODEL:-arcee/trinity-mini}"
PASSES="${PASSES:-logic,security}"
SEVERITY_THRESHOLD="${SEVERITY_THRESHOLD:-warning}"
MAX_FILES="${MAX_FILES:-20}"
PR_NUMBER="${PR_NUMBER:-}"
BASE_REF="${BASE_REF:-main}"
HEAD_SHA="${HEAD_SHA:-}"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="${SCRIPT_DIR}/../skills"

# Output files
FINDINGS_FILE=".bug-hunter/findings.json"
STATUS_FILE=".bug-hunter/status"

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
    echo "failure" > "$STATUS_FILE"
    echo "[]" | jq '.' > "$FINDINGS_FILE"
    exit 1
  fi
  
  # Get changed files
  local files
  files=$(get_changed_files)
  
  if [ -z "$files" ]; then
    log "No code files changed. The night is quiet."
    echo "success" > "$STATUS_FILE"
    echo "[]" | jq '.' > "$FINDINGS_FILE"
    
    # Set outputs for GitHub Actions
    if [ -n "${GITHUB_OUTPUT:-}" ]; then
      echo "status=success" >> "$GITHUB_OUTPUT"
      echo "findings=[]" >> "$GITHUB_OUTPUT"
      echo "critical-count=0" >> "$GITHUB_OUTPUT"
      echo "warning-count=0" >> "$GITHUB_OUTPUT"
    fi
    exit 0
  fi
  
  log "Tracking $(echo "$files" | wc -l) files..."
  
  # Initialize findings array
  local all_findings="[]"
  
  # Parse passes
  IFS=',' read -ra PASS_ARRAY <<< "$PASSES"
  
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
    
    # Run each skill
    for pass in "${PASS_ARRAY[@]}"; do
      pass=$(echo "$pass" | xargs)  # trim whitespace
      
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
      
      # Add file to each finding if missing
      findings=$(echo "$findings" | jq --arg file "$file" '[.[] | .file = ($file // .file)]')
      
      # Merge into all_findings
      all_findings=$(echo "$all_findings" "$findings" | jq -s 'add // []')
    done
  done <<< "$files"
  
  # Count severities
  local critical_count
  local warning_count
  critical_count=$(echo "$all_findings" | jq '[.[] | select(.severity == "critical")] | length')
  warning_count=$(echo "$all_findings" | jq '[.[] | select(.severity == "warning")] | length')
  
  log "Hunt complete. Found: $critical_count critical, $warning_count warnings"
  
  # Determine status
  local status="success"
  if [ "$critical_count" -gt 0 ]; then
    status="failure"
  elif [ "$warning_count" -gt 0 ]; then
    status="warning"
  fi
  
  # Save outputs
  echo "$status" > "$STATUS_FILE"
  echo "$all_findings" | jq '.' > "$FINDINGS_FILE"
  
  # Set GitHub Actions outputs
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "status=$status" >> "$GITHUB_OUTPUT"
    echo "findings=$all_findings" >> "$GITHUB_OUTPUT"
    echo "critical-count=$critical_count" >> "$GITHUB_OUTPUT"
    echo "warning-count=$warning_count" >> "$GITHUB_OUTPUT"
  fi
  
  log "🧛‍♂️ The hunter rests. Status: $status"
  
  if [ "$status" = "failure" ]; then
    exit 1
  fi
}

main "$@"
