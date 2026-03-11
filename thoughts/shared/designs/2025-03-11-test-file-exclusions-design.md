# Test File Exclusions — Design Document

**Status:** Draft  
**Date:** 2025-03-11  
**Scope:** Add configurable test file exclusion to Bug Hunter D33  
**Driver:** Implementation Planner  
**Approver:** (User review)

---

## 1. Problem Statement

**Current Behavior:**
- Bug Hunter reviews ALL files matching supported extensions (`*.js`, `*.ts`, `*.py`, etc.)
- No filtering for test files (`*.test.js`, `*.spec.ts`, `__tests__/`, etc.)
- This wastes API tokens reviewing test code that rarely contains production bugs worth hunting

**Impact:**
- Wasted API calls = wasted money
- Longer hunt times
- False positives in test utilities/mocks

---

## 2. Goals & Non-Goals

### Goals
- Add configurable test file exclusion (default: enabled/exclude tests)
- Support common test file patterns across 7+ languages
- Make it configurable via environment variable AND GitHub Action input
- Keep it simple — no complex regex, use glob patterns
- Log excluded files for transparency

### Non-Goals
- Complex regex-based exclusion (keep it simple)
- Per-language granular control (not needed for MVP)
- Excluding inline test code (e.g., Rust `#[cfg(test)]` blocks in same file)
- Custom user-defined patterns (future enhancement)

---

## 3. Requirements

### R1: Default Behavior
Test file exclusion should be **enabled by default** (exclude tests). Users can opt-in to reviewing tests.

### R2: Configuration via Environment Variable
```bash
EXCLUDE_TESTS=true   # Default - exclude test files
EXCLUDE_TESTS=false  # Include test files in review
```

### R3: Configuration via GitHub Action Input
```yaml
- uses: lux-sp4rk/bug-hunter-d33@main
  with:
    arcee-api-key: ${{ secrets.ARCEE_API_KEY }}
    exclude-tests: 'true'  # Default
```

### R4: Test File Pattern Coverage
Support patterns for these languages:

| Language | File Patterns | Directory Patterns |
|----------|---------------|-------------------|
| JavaScript/TypeScript | `*.test.*`, `*.spec.*` | `__tests__/`, `test/`, `tests/`, `spec/`, `specs/` |
| Python | `test_*.py`, `*_test.py` | `tests/`, `test/` |
| Go | `*_test.go` | — |
| Rust | — | `tests/` directory |
| Java | `*Test.java`, `Test*.java` | `test/`, `tests/` |
| Ruby | `*_spec.rb`, `*_test.rb` | `spec/`, `test/`, `tests/` |
| PHP | `*Test.php`, `*Spec.php` | `tests/`, `test/`, `spec/` |
| General | — | Any path containing `/test/` or `/tests/` |

### R5: Logging
Log how many files were excluded and why:
```
[Bug Hunter D33] Excluded 5 test files (EXCLUDE_TESTS=true)
[Bug Hunter D33] Tracking 12 files...
```

### R6: Transparency
When files are excluded, report the count in final output.

---

## 4. Design

### 4.1 Architecture

```
┌─────────────────────────────────────────┐
│  GitHub Action / Environment Config     │
│  EXCLUDE_TESTS=true|false              │
└─────────────────┬───────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│  action.yml → Export to env             │
│  inputs.exclude-tests → $EXCLUDE_TESTS │
└─────────────────┬───────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│  scripts/summon.sh                      │
│  ┌─────────────────────────────────┐   │
│  │ get_changed_files()             │   │
│  │ ┌─────────────────────────────┐ │   │
│  │ │ filter_test_files()         │ │   │
│  │ │ - Check env var             │ │   │
│  │ │ - Match patterns            │ │   │
│  │ │ - Return filtered list      │ │   │
│  │ └─────────────────────────────┘ │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

### 4.2 Pattern Matching Strategy

Use **simple bash glob patterns** (not regex) for maintainability:

```bash
# File name patterns (basename check)
*.test.*       # JavaScript/TypeScript tests
*.spec.*       # JavaScript/Ruby tests
test_*.py      # Python tests (pytest style)
*_test.py      # Python tests (unittest style)
*_test.go      # Go tests
*Test.java     # Java tests (JUnit style)
Test*.java     # Java tests (alternative)
*_spec.rb      # Ruby RSpec
*_test.rb      # Ruby Minitest
*Test.php      # PHP PHPUnit
*Spec.php      # PHP PHPSpec

# Directory patterns (path substring check)
*/__tests__/*   # JavaScript __tests__ directories
*/test/*        # Generic test directories  
*/tests/*       # Generic tests directories
*/spec/*        # RSpec-style directories
*/specs/*       # Alternative spec directory
```

### 4.3 Implementation Location

Modify `scripts/summon.sh`:

1. **Add configuration variable** (near line 10-17):
   ```bash
   EXCLUDE_TESTS="${EXCLUDE_TESTS:-true}"
   ```

2. **Add filtering function** (after line 62):
   ```bash
   # Returns true if file should be excluded
   is_test_file() {
       local file="$1"
       local basename=$(basename "$file")
       
       # Check file name patterns
       case "$basename" in
           *.test.*|*.spec.*) return 0 ;;
           test_*.py) return 0 ;;
           *_test.py|*_test.go) return 0 ;;
           *Test.java|Test*.java) return 0 ;;
           *_spec.rb|*_test.rb) return 0 ;;
           *Test.php|*Spec.php) return 0 ;;
       esac
       
       # Check directory patterns
       case "$file" in
           */__tests__/*|*/test/*|*/tests/*|*/spec/*|*/specs/*)
               return 0
               ;;
       esac
       
       return 1
   }
   
   filter_test_files() {
       local files="$1"
       local excluded_count=0
       
       while IFS= read -r file; do
           [ -z "$file" ] && continue
           if is_test_file "$file"; then
               ((excluded_count++))
               log "  → Excluded test file: $file"
           else
               echo "$file"
           fi
       done <<< "$files"
       
       # Return excluded count via global or echo to stderr
       echo "$excluded_count" >&2
   }
   ```

3. **Modify `get_changed_files()`** (line 49-62):
   Add filtering after getting files:
   ```bash
   get_changed_files() {
       local files
       # ... existing code to get files ...
       
       if [ "$EXCLUDE_TESTS" = "true" ]; then
           local filtered_files
           filtered_files=$(filter_test_files "$files")
           local excluded=$(echo "$filtered_files" | tail -1)  # Last line is count
           filtered_files=$(echo "$filtered_files" | head -n -1)  # Remove count line
           [ "$excluded" -gt 0 ] && log "Excluded $excluded test files (EXCLUDE_TESTS=true)"
           files="$filtered_files"
       fi
       
       # ... rest of function ...
   }
   ```

### 4.4 GitHub Action Integration

Modify `action.yml`:

1. **Add input** (after line 31):
   ```yaml
   exclude-tests:
     description: 'Exclude test files from review (true/false)'
     required: false
     default: 'true'
   ```

2. **Export to environment** (in Run Bug Hunter step, line 117-129):
   Add:
   ```yaml
   EXCLUDE_TESTS: ${{ inputs.exclude-tests }}
   ```

### 4.5 Agent.yml Integration

Modify `agent.yml`:

Add environment variable documentation in runtime section:
```yaml
runtime:
  env:
    EXCLUDE_TESTS: "true"  # Exclude test files by default
```

---

## 5. Test Plan

### Unit Tests (scripts/filter_tests.sh)

Create a standalone test script to verify pattern matching:

```bash
#!/bin/bash
# Test script for test file filtering logic

# Test cases
test_is_test_file() {
    local file="$1"
    local expected="$2"
    
    # Call is_test_file and check result
    if is_test_file "$file"; then
        result="excluded"
    else
        result="included"
    fi
    
    if [ "$result" = "$expected" ]; then
        echo "✓ $file → $expected"
    else
        echo "✗ $file → expected $expected, got $result"
        exit 1
    fi
}

# JavaScript/TypeScript
test_is_test_file "src/utils.test.js" "excluded"
test_is_test_file "src/utils.spec.ts" "excluded"
test_is_test_file "src/utils.js" "included"
test_is_test_file "__tests__/auth.test.js" "excluded"
test_is_test_file "tests/auth.test.js" "excluded"

# Python
test_is_test_file "test_utils.py" "excluded"
test_is_test_file "utils_test.py" "excluded"
test_is_test_file "tests/test_utils.py" "excluded"
test_is_test_file "utils.py" "included"

# Go
test_is_test_file "utils_test.go" "excluded"
test_is_test_file "utils.go" "included"

# And so on...
```

### Integration Tests

Test scenarios:
1. Default behavior (EXCLUDE_TESTS not set) → excludes tests
2. EXCLUDE_TESTS=true → excludes tests  
3. EXCLUDE_TESTS=false → includes tests
4. Mixed repository (test + source files) → only source reviewed

---

## 6. User Documentation

### GitHub Action Usage

```yaml
- uses: lux-sp4rk/bug-hunter-d33@main
  with:
    arcee-api-key: ${{ secrets.ARCEE_API_KEY }}
    exclude-tests: 'true'  # Default - skip test files
    
# To review tests as well:
- uses: lux-sp4rk/bug-hunter-d33@main
  with:
    arcee-api-key: ${{ secrets.ARCEE_API_KEY }}
    exclude-tests: 'false'  # Include test files
```

### Local/Subagent Usage

```bash
# Default (exclude tests)
ARCEE_API_KEY=xxx ./scripts/summon.sh

# Include tests in review
EXCLUDE_TESTS=false ARCEE_API_KEY=xxx ./scripts/summon.sh
```

### What Gets Excluded

Test files matching these patterns are excluded:
- `*.test.*`, `*.spec.*` (JavaScript/TypeScript)
- `test_*.py`, `*_test.py` (Python)
- `*_test.go` (Go)
- `*Test.java` (Java)
- `*_spec.rb`, `*_test.rb` (Ruby)
- Files in `test/`, `tests/`, `spec/`, `__tests__/` directories

---

## 7. Future Enhancements

- Custom exclusion patterns via `EXCLUDE_PATTERNS` env var
- Per-language toggle (`EXCLUDE_JS_TESTS=false`)
- Include/exclude specific directories
- Configuration file (`.bug-hunter-config`)

---

## 8. Acceptance Criteria

- [ ] EXCLUDE_TESTS env var controls filtering (default: true)
- [ ] GitHub Action has `exclude-tests` input (default: true)
- [ ] All documented patterns are excluded
- [ ] Excluded files are logged
- [ ] Test script validates all patterns
- [ ] Documentation updated in README

---

*Design complete. Ready for implementation planning.*
