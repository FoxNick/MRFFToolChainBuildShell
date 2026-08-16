#! /usr/bin/env bash
#
# Helpers shared by the unit tests: fake host tool chains, fake NDK, stub
# commands and a few small wrappers around the scripts under test.
#

# Creates $TEST_TMP_DIR/bin, puts it at the front of PATH and sets
# $STUB_BIN_DIR. Must not be called from a subshell, it exports PATH.
function stub_bin_dir()
{
    STUB_BIN_DIR="${TEST_TMP_DIR}/bin"
    mkdir -p "$STUB_BIN_DIR"
    if [[ ":$PATH:" != *":$STUB_BIN_DIR:"* ]]; then
        export PATH="${STUB_BIN_DIR}:$PATH"
    fi
}

# stub_command <name> <body>
# Creates an executable named <name> in the stub bin dir running <body>.
function stub_command()
{
    local name="$1" body="$2"
    stub_bin_dir
    {
        echo '#! /usr/bin/env bash'
        echo "$body"
    } > "${STUB_BIN_DIR}/${name}"
    chmod +x "${STUB_BIN_DIR}/${name}"
}

# macOS only command used by the apple host env script.
function stub_sysctl()
{
    stub_command sysctl 'echo 8'
}

# Creates a minimal NDK layout and echoes its path.
function make_fake_ndk()
{
    local rel="${1:-27c}"
    local ndk="${TEST_TMP_DIR}/ndk"
    mkdir -p "${ndk}/toolchains/llvm/prebuilt/linux-x86_64/bin"
    mkdir -p "${ndk}/toolchains/llvm/prebuilt/darwin-x86_64/bin"
    mkdir -p "${ndk}/prebuilt/linux-x86_64/bin"
    mkdir -p "${ndk}/prebuilt/darwin-x86_64/bin"
    printf '# Changelog\n\n## r%s\n\nsome notes\n' "$rel" > "${ndk}/CHANGELOG.md"
    echo "$ndk"
}

# Creates a tools dir holding fake host env scripts, so that parse-arguments.sh
# can be exercised without Xcode or the Android NDK. Echoes its path.
function make_stub_tools_dir()
{
    local dir="${TEST_TMP_DIR}/stub-tools"
    mkdir -p "$dir"

    cat << 'EOF' > "${dir}/export-apple-host-env.sh"
export MR_DEFAULT_ARCHS="arm64 arm64_simulator x86_64_simulator"
[[ "$MR_PLAT" == 'macos' ]] && export MR_DEFAULT_ARCHS="x86_64 arm64"
export MR_HOST_NPROC="${MR_HOST_NPROC:-8}"
export MR_TAGET_OS="darwin"
EOF

    cat << 'EOF' > "${dir}/export-android-host-env.sh"
export MR_DEFAULT_ARCHS="armv7a arm64 x86 x86_64"
export MR_HOST_NPROC="${MR_HOST_NPROC:-8}"
export MR_TAGET_OS="android"
EOF
    echo "$dir"
}

# my_sed_i is exported by the host env scripts; the scripts under test rely on
# it being present in the environment.
function define_my_sed_i()
{
    my_sed_i() {
        if [[ "$(uname)" == "Darwin" ]]; then
            sed -i '' "$@"
        else
            sed -i "$@"
        fi
    }
    export -f my_sed_i
}

# env_assert is defined by tools/parse-arguments.sh and exported to child
# scripts; mirrored here for scripts that are tested standalone.
function define_env_assert()
{
    env_assert() {
        local name="$1"
        local value
        value=$(eval echo "\$$name")
        if [[ "x$value" == "x" ]]; then
            echo "$name is nil,eg: export $name=xx" >&2
            exit 1
        else
            echo "$name : [${value}]" >&2
        fi
    }
    export -f env_assert
}

# make_absolute_path is defined by tools/parse-arguments.sh and exported to
# child scripts; mirrored here for scripts that are tested standalone.
function define_make_absolute_path()
{
    make_absolute_path() {
        local p="$1"
        if [[ $p == /* ]]; then
            echo "$(cd "$(dirname "$p")" && pwd)/$(basename "$p")"
        else
            echo "$(cd "$(dirname "$MR_SHELL_ROOT_DIR/$p")" && pwd)/$(basename "$p")"
        fi
    }
    export -f make_absolute_path
}

# run_parse_arguments <args...>
# Sources tools/parse-arguments.sh in a child bash with the stub host env
# scripts, then dumps the resulting MR_* environment. Output and exit status
# land in $output / $status.
function run_parse_arguments()
{
    local tools_dir
    tools_dir=$(make_stub_tools_dir)
    run env \
        MR_SHELL_ROOT_DIR="${MR_SHELL_ROOT_DIR:-$REPO_ROOT}" \
        MR_SHELL_TOOLS_DIR="$tools_dir" \
        bash -c 'source "$MR_PARSE_ARGUMENTS_PATH"; env | grep "^MR_" | sort' \
        parse-arguments.sh "$@"
}

export MR_PARSE_ARGUMENTS_PATH="${REPO_ROOT}/tools/parse-arguments.sh"

# eval_with_parse_arguments <code> [args...]
# Sources tools/parse-arguments.sh with [args...] (discarding its output) and
# then evaluates <code>, so that its helper functions can be called directly.
function eval_with_parse_arguments()
{
    local code="$1"
    shift
    local tools_dir
    tools_dir=$(make_stub_tools_dir)
    run env \
        MR_SHELL_ROOT_DIR="${MR_SHELL_ROOT_DIR:-$REPO_ROOT}" \
        MR_SHELL_TOOLS_DIR="$tools_dir" \
        MR_EVAL_CODE="$code" \
        bash -c 'source "$MR_PARSE_ARGUMENTS_PATH" > /dev/null; eval "$MR_EVAL_CODE"' \
        parse-arguments.sh "$@"
}

# Creates a product dir layout with one pc file per lib and echoes the
# product root, eg: <root>/universal/opus/lib/pkgconfig/opus.pc
function make_product_tree()
{
    local root="$1" universal="${2:-universal}" lib="${3:-opus}"
    local pkgconfig="${root}/${universal}/${lib}/lib/pkgconfig"
    mkdir -p "$pkgconfig"
    echo "${root}/${universal}/${lib}"
}
