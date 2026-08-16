#! /usr/bin/env bash
#
# Runs the unit tests of the build shell scripts.
#
# usage: ./tests/run-tests.sh [test-file-or-pattern ...]
#
#   ./tests/run-tests.sh                       # run everything
#   ./tests/run-tests.sh parse-arguments       # run tests/test-parse-arguments.sh
#   ./tests/run-tests.sh tests/test-correct-pc.sh
#

THIS_DIR=$(cd "$(dirname "$0")" && pwd)

source "${THIS_DIR}/lib/harness.sh"

files=()

if [[ $# -eq 0 ]]; then
    while IFS= read -r f; do
        files+=("$f")
    done < <(find "$THIS_DIR" -maxdepth 1 -name 'test-*.sh' | sort)
else
    for pattern in "$@"; do
        if [[ -f "$pattern" ]]; then
            files+=("$(cd "$(dirname "$pattern")" && pwd)/$(basename "$pattern")")
        elif [[ -f "${THIS_DIR}/test-${pattern}.sh" ]]; then
            files+=("${THIS_DIR}/test-${pattern}.sh")
        else
            while IFS= read -r f; do
                files+=("$f")
            done < <(find "$THIS_DIR" -maxdepth 1 -name "test-*${pattern}*.sh" | sort)
        fi
    done
fi

if [[ ${#files[@]} -eq 0 ]]; then
    echo "no test files matched: $*" >&2
    exit 1
fi

echo "bash $BASH_VERSION on $(uname -s)"
echo

for file in "${files[@]}"; do
    run_test_file "$file"
done

print_summary
