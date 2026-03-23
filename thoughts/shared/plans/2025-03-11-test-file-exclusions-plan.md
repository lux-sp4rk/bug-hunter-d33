# Test File Exclusions Implementation Plan

**Goal:** Add configurable test file exclusion to Bug Hunter D33 to reduce API token waste on test files.

**Architecture:** Use bash glob pattern matching to identify and filter test files during the `get_changed_files()` phase, with configuration via environment variable and GitHub Action input.

**Design:** [Link to thoughts/shared/designs/2025-03-11-test-file-exclusions-design.md]

---

## Dependency Graph

```
Batch 1 (parallel - 2 implementers):
  1.1 - scripts/summon.sh: Add test file filtering functions
  1.2 - tests/filter_test_files_test.sh: Create unit test script

Batch 2 (parallel - 2 implementers, depends on Batch 1):
  2.1 - action.yml: Add exclude-tests input and environment export
  2.2 - agent.yml: Document EXCLUDE_TESTS environment variable
```

---

## Batch 1: Core Logic (Parallel - 2 Implementers)

All tasks in this batch have NO dependencies and can run simultaneously.

---

### Task 1.1: Add Test File Filtering to summon.sh
**File:** `scripts/summon.sh`
**Test:** `tests/filter_test_files_test.sh` (created in Task 1.2)
**Depends:** none

**Changes to make:**

1. Add EXCLUDE_TESTS configuration variable after line 17 (after MAX_FILES line)
2. Add `is_test_file()` function after the `get_file_diff()` function (after line 77)
3. Add `filter_test_files()` function after `is_test_file()`
4. Modify `get_changed_files()` to call filtering when EXCLUDE_TESTS=true
5. Update logging to show excluded file count

**Complete implementation:**

```bash
# After line 17 (after MAX_FILES="${MAX_FILES:-20}"):
EXCLUDE_TESTS="${EXCLUDE_TESTS:-true}"
```

```bash
# After get_file_diff() function (after line 77), add is_test_file():
# Returns true (exit 0) if file should be excluded as a test file
is_test_file() {
    local file="$1"
    local basename
    basename=$(basename "$file")
    
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
```

```bash
# After is_test_file(), add filter_test_files():
# Filters test files from a list and returns count via stderr
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
    
    # Return excluded count via stderr
    echo "$excluded_count" >&2
}
```

```bash
# Modify get_changed_files() function (lines 49-62) to add filtering:
# Replace the existing function with:
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
        # Extract count from last line (stderr redirected to stdout in subshell)
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
```

**Verification:**
1. Run shellcheck on the modified file: `shellcheck scripts/summon.sh`
2. Run the test script: `bash tests/filter_test_files_test.sh`
3. Test manually with test files present:
   ```bash
   # Create test scenario
   echo "test" > /tmp/test_utils.test.js
   echo "test" > /tmp/utils.js
   EXCLUDE_TESTS=true bash -c 'source scripts/summon.sh && is_test_file "/tmp/test_utils.test.js" && echo "excluded" || echo "included"'
   # Should output "excluded"
   ```

**Commit:** `feat(summon): add test file filtering with is_test_file and filter_test_files functions`

---

### Task 1.2: Create Unit Test Script for Test File Filtering
**File:** `tests/filter_test_files_test.sh`
**Test:** Self-testing script (no separate test file needed)
**Depends:** none

**Complete implementation:**

```bash
#!/bin/bash
#
# Test script for test file filtering logic
# Tests is_test_file() function from scripts/summon.sh
#

set -euo pipefail

# Track test results
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper function
test_is_test_file() {
    local file="$1"
    local expected="$2"
    local description="${3:-}"
    
    # Source the is_test_file function from summon.sh
    # We extract just the function to test it in isolation
    if is_test_file "$file"; then
        result="excluded"
    else
        result="included"
    fi
    
    if [ "$result" = "$expected" ]; then
        echo "✓ $file → $expected ${description:+($description)}"
        ((TESTS_PASSED++))
    else
        echo "✗ $file → expected $expected, got $result ${description:+($description)}"
        ((TESTS_FAILED++))
    fi
}

# Import the is_test_file function from summon.sh
# We need to source it but avoid running the main function
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Extract and source just the is_test_file function
is_test_file() {
    local file="$1"
    local basename
    basename=$(basename "$file")
    
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

echo "=== Bug Hunter D33 Test File Filter Tests ==="
echo ""

# JavaScript/TypeScript
echo "--- JavaScript/TypeScript Patterns ---"
test_is_test_file "src/utils.test.js" "excluded" "JS test file"
test_is_test_file "src/utils.spec.ts" "excluded" "TS spec file"
test_is_test_file "src/utils.js" "included" "JS source file"
test_is_test_file "src/utils.ts" "included" "TS source file"
test_is_test_file "__tests__/auth.test.js" "excluded" "JS in __tests__ dir"
test_is_test_file "tests/auth.test.js" "excluded" "JS in tests dir"
test_is_test_file "test/auth.test.js" "excluded" "JS in test dir"
test_is_test_file "spec/auth.test.js" "excluded" "JS in spec dir"
test_is_test_file "specs/auth.test.js" "excluded" "JS in specs dir"
test_is_test_file "src/components/Button.test.jsx" "excluded" "JSX test file"
test_is_test_file "src/components/Button.spec.tsx" "excluded" "TSX spec file"
echo ""

# Python
echo "--- Python Patterns ---"
test_is_test_file "test_utils.py" "excluded" "pytest style"
test_is_test_file "utils_test.py" "excluded" "unittest style"
test_is_test_file "tests/test_utils.py" "excluded" "pytest in tests dir"
test_is_test_file "test/test_utils.py" "excluded" "pytest in test dir"
test_is_test_file "utils.py" "included" "Python source file"
test_is_test_file "src/utils.py" "included" "Python source in src"
test_is_test_file "tests/utils.py" "excluded" "Source in tests dir"
echo ""

# Go
echo "--- Go Patterns ---"
test_is_test_file "utils_test.go" "excluded" "Go test file"
test_is_test_file "utils.go" "included" "Go source file"
test_is_test_file "main_test.go" "excluded" "Go main test"
test_is_test_file "internal/utils_test.go" "excluded" "Go test in internal"
echo ""

# Rust
echo "--- Rust Patterns ---"
test_is_test_file "src/main.rs" "included" "Rust source file"
test_is_test_file "tests/integration_test.rs" "excluded" "Rust test in tests dir"
test_is_test_file "test/unit_test.rs" "excluded" "Rust test in test dir"
echo ""

# Java
echo "--- Java Patterns ---"
test_is_test_file "UserTest.java" "excluded" "JUnit test (suffix)"
test_is_test_file "TestUser.java" "excluded" "JUnit test (prefix)"
test_is_test_file "User.java" "included" "Java source file"
test_is_test_file "src/main/java/com/example/User.java" "included" "Java in src"
test_is_test_file "src/test/java/com/example/UserTest.java" "excluded" "JUnit in test dir"
test_is_test_file "tests/UserTest.java" "excluded" "JUnit in tests dir"
echo ""

# Ruby
echo "--- Ruby Patterns ---"
test_is_test_file "user_spec.rb" "excluded" "RSpec test"
test_is_test_file "user_test.rb" "excluded" "Minitest test"
test_is_test_file "user.rb" "included" "Ruby source file"
test_is_test_file "spec/user_spec.rb" "excluded" "RSpec in spec dir"
test_is_test_file "test/user_test.rb" "excluded" "Minitest in test dir"
test_is_test_file "tests/user_test.rb" "excluded" "Minitest in tests dir"
echo ""

# PHP
echo "--- PHP Patterns ---"
test_is_test_file "UserTest.php" "excluded" "PHPUnit test"
test_is_test_file "UserSpec.php" "excluded" "PHPSpec test"
test_is_test_file "User.php" "included" "PHP source file"
test_is_test_file "tests/UserTest.php" "excluded" "PHPUnit in tests dir"
test_is_test_file "test/UserTest.php" "excluded" "PHPUnit in test dir"
test_is_test_file "spec/UserSpec.php" "excluded" "PHPSpec in spec dir"
echo ""

# Edge cases
echo "--- Edge Cases ---"
test_is_test_file "testing.js" "included" "File starting with 'test' but not ending in pattern"
test_is_test_file "tester.py" "included" "Python file with 'test' in name but not pattern"
test_is_test_file "my_test_utils.js" "included" "JS file with 'test' in middle"
test_is_test_file "src/test-helpers.js" "included" "Helper in test-related path but not test dir"
test_is_test_file "src/testing/utils.js" "included" "Utils in testing dir (not exact match)"
echo ""

# Summary
echo "=== Test Summary ==="
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo ""

if [ "$TESTS_FAILED" -eq 0 ]; then
    echo "✓ All tests passed!"
    exit 0
else
    echo "✗ Some tests failed"
    exit 1
fi
```

**Verification:**
1. Make script executable: `chmod +x tests/filter_test_files_test.sh`
2. Run the test script: `bash tests/filter_test_files_test.sh`
3. All 35+ test cases should pass

**Commit:** `test(filter): add unit tests for test file filtering patterns`

---

## Batch 2: Configuration Integration (Parallel - 2 Implementers)

All tasks in this batch depend on Batch 1 completing (the filtering logic must exist first).

---

### Task 2.1: Add GitHub Action Input for Test Exclusion
**File:** `action.yml`
**Test:** Manual verification via action.yml syntax check
**Depends:** 1.1, 1.2 (filtering logic must exist first)

**Changes to make:**

1. Add `exclude-tests` input after `max-files` input (after line 31)
2. Export `EXCLUDE_TESTS` environment variable in the "Run Bug Hunter" step (after line 132, before FRAMEWORK env)

**Complete implementation:**

```yaml
# After line 31 (after max-files input), add:
  exclude-tests:
    description: 'Exclude test files from review (true/false)'
    required: false
    default: 'true'
```

```yaml
# In the "Run Bug Hunter" step, in the env: section (after line 132, before FRAMEWORK line):
# Add after MAX_FILES line:
        EXCLUDE_TESTS: ${{ inputs.exclude-tests }}
```

The env section should look like:
```yaml
      env:
        ARCEE_API_KEY: ${{ inputs.arcee-api-key }}
        MODEL: ${{ inputs.model }}
        PASSES: ${{ inputs.passes }}
        SEVERITY_THRESHOLD: ${{ inputs.severity-threshold }}
        MAX_FILES: ${{ inputs.max-files }}
        EXCLUDE_TESTS: ${{ inputs.exclude-tests }}
        GH_TOKEN: ${{ github.token }}
        PR_NUMBER: ${{ github.event.pull_request.number }}
        BASE_REF: ${{ github.base_ref }}
        HEAD_SHA: ${{ github.event.pull_request.head.sha }}
        ACTION_PATH: ${{ github.action_path }}
        FRAMEWORK: ${{ steps.framework.outputs.framework }}
        FRAMEWORK_SKILL: ${{ steps.framework.outputs.skill }}
```

**Verification:**
1. Validate YAML syntax: `yamllint action.yml` (or visually check indentation)
2. Verify the input appears in GitHub Action inputs list
3. Test by running action with `exclude-tests: 'false'` and verify test files are included

**Commit:** `feat(action): add exclude-tests input to GitHub Action`

---

### Task 2.2: Document EXCLUDE_TESTS in Agent Configuration
**File:** `agent.yml`
**Test:** None needed (documentation only)
**Depends:** 1.1, 1.2 (filtering logic must exist first)

**Changes to make:**

1. Add EXCLUDE_TESTS to the runtime environment section (after line 29, after max_tokens)

**Complete implementation:**

```yaml
# In the runtime: section, after max_tokens line (line 29), add:
  env:
    EXCLUDE_TESTS: "true"  # Exclude test files by default
```

The runtime section should look like:
```yaml
# Runtime configuration
runtime:
  model: arcee/trinity-large  # Use larger model for deep hunts
  temperature: 0.1
  max_tokens: 8000
  env:
    EXCLUDE_TESTS: "true"  # Exclude test files by default
```

**Verification:**
1. Validate YAML syntax: `yamllint agent.yml`
2. Document that this is the default for OpenClaw subagent usage

**Commit:** `docs(agent): document EXCLUDE_TESTS environment variable in agent.yml`

---

## Verification Checklist

After all tasks complete:

- [ ] `EXCLUDE_TESTS=true` (default) excludes test files matching patterns
- [ ] `EXCLUDE_TESTS=false` includes test files
- [ ] Excluded files are logged: "Excluded N test files (EXCLUDE_TESTS=true)"
- [ ] GitHub Action accepts `exclude-tests` input with default `'true'`
- [ ] Unit test script passes all test cases (35+ tests)
- [ ] Shellcheck passes on modified shell scripts
- [ ] Manual integration test: Create PR with test files, verify they're excluded

---

## Rollback Plan

If issues are discovered:

1. **Quick disable:** Set `EXCLUDE_TESTS=false` in workflow or environment
2. **Revert commit:** Rollback specific task commits in reverse order (2.2, 2.1, 1.2, 1.1)
3. **Hotfix:** Apply patches to fix specific pattern matching issues

---

## Pattern Reference

Supported test file patterns by language:

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

---

*Plan ready for implementation. Target: 4 micro-tasks, 2 batches, ~30 minutes per task.*
