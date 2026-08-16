#! /usr/bin/env bash
#
# Minimal, dependency free unit test harness for the shell scripts of this repo.
#
# A test file is a bash script named tests/test-*.sh which defines functions
# starting with 'test_'. Every test function runs in its own subshell with a
# private temp dir ($TEST_TMP_DIR) as working directory, so tests can freely
# change directories, export variables and create files.
#
# Available assertions:
#   assert_equals      expected actual [message]
#   assert_contains    haystack needle [message]
#   assert_not_contains haystack needle [message]
#   assert_success     status [message]
#   assert_failure     status [message]
#   assert_file_exists path [message]
#   fail               message
#
# Available helpers:
#   run  cmd...        runs cmd, stores output in $output and status in $status
#

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
TESTS_DIR="${REPO_ROOT}/tests"
FIXTURES_DIR="${TESTS_DIR}/fixtures"

TESTS_RUN=0
TESTS_FAILED=0
FAILED_NAMES=()

function fail()
{
    echo "        $1" >&2
    return 1
}

function assert_equals()
{
    local expected="$1" actual="$2" message="${3:-}"
    if [[ "$expected" != "$actual" ]]; then
        fail "${message:+$message: }expected [$expected] but got [$actual]"
        return 1
    fi
}

function assert_contains()
{
    local haystack="$1" needle="$2" message="${3:-}"
    if [[ "$haystack" != *"$needle"* ]]; then
        fail "${message:+$message: }expected to find [$needle] in [$haystack]"
        return 1
    fi
}

function assert_not_contains()
{
    local haystack="$1" needle="$2" message="${3:-}"
    if [[ "$haystack" == *"$needle"* ]]; then
        fail "${message:+$message: }expected not to find [$needle] in [$haystack]"
        return 1
    fi
}

function assert_success()
{
    local status="$1" message="${2:-}"
    if [[ "$status" != "0" ]]; then
        fail "${message:+$message: }expected success but exit status was $status"
        return 1
    fi
}

function assert_failure()
{
    local status="$1" message="${2:-}"
    if [[ "$status" == "0" ]]; then
        fail "${message:+$message: }expected failure but exit status was 0"
        return 1
    fi
}

function assert_file_exists()
{
    local path="$1" message="${2:-}"
    if [[ ! -f "$path" ]]; then
        fail "${message:+$message: }expected file [$path] to exist"
        return 1
    fi
}

# runs a command capturing stdout+stderr into $output and its exit code into $status
function run()
{
    set +e
    output=$("$@" 2>&1)
    status=$?
    set -e
}

function run_test_function()
{
    local file="$1" fn="$2"
    local name="$(basename "$file"):$fn"

    TESTS_RUN=$((TESTS_RUN + 1))

    local tmp_dir
    tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/mrff-test.XXXXXX")

    local log="${tmp_dir}/.harness-output"
    (
        set -e
        export TEST_TMP_DIR="$tmp_dir"
        cd "$tmp_dir"
        # shellcheck disable=SC1090
        source "$file"
        if declare -F setup > /dev/null; then
            setup
        fi
        "$fn"
    ) > "$log" 2>&1
    local st=$?

    if [[ $st -eq 0 ]]; then
        echo "    ok   $fn"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        FAILED_NAMES+=("$name")
        echo "    FAIL $fn"
        sed 's/^/        /' "$log"
    fi

    rm -rf "$tmp_dir"
}

function run_test_file()
{
    local file="$1"
    echo "$(basename "$file")"

    local fns
    # list the test functions in declaration order without polluting this shell
    fns=$(grep -Eo '^[[:space:]]*(function[[:space:]]+)?test_[a-zA-Z0-9_]+' "$file" \
        | sed -E 's/^[[:space:]]*(function[[:space:]]+)?//' | awk '!seen[$0]++')

    if [[ -z "$fns" ]]; then
        echo "    no test_* functions found" >&2
        TESTS_FAILED=$((TESTS_FAILED + 1))
        FAILED_NAMES+=("$(basename "$file"): no tests")
        return
    fi

    local fn
    for fn in $fns; do
        run_test_function "$file" "$fn"
    done
}

function print_summary()
{
    echo
    echo "===================================="
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo "all ${TESTS_RUN} tests passed"
        return 0
    fi
    echo "${TESTS_FAILED} of ${TESTS_RUN} tests failed:"
    local name
    for name in "${FAILED_NAMES[@]}"; do
        echo "  - $name"
    done
    return 1
}
