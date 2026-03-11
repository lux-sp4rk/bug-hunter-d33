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

	if is_test_file "$file"; then
		result="excluded"
	else
		result="included"
	fi

	if [ "$result" = "$expected" ]; then
		echo "✓ $file → $expected ${description:+($description)}"
		TESTS_PASSED=$((TESTS_PASSED + 1))
	else
		echo "✗ $file → expected $expected, got $result ${description:+($description)}"
		TESTS_FAILED=$((TESTS_FAILED + 1))
	fi
}

# Import the is_test_file function from summon.sh
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
	__tests__/* | test/* | tests/* | spec/* | specs/*)
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
