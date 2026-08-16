#! /usr/bin/env bash
#
# Unit tests for do-init/main.sh, do-init/init-repo.sh and
# do-init/copy-local-repo.sh
#
# Everything runs against a local git repo playing the role of the upstream, so
# no network access is needed.
#

source "${REPO_ROOT}/tests/lib/stubs.sh"

function git_quiet()
{
    GIT_AUTHOR_NAME=tester GIT_AUTHOR_EMAIL=tester@example.com \
    GIT_COMMITTER_NAME=tester GIT_COMMITTER_EMAIL=tester@example.com \
    git -c init.defaultBranch=master -c advice.detachedHead=false "$@" > /dev/null 2>&1
}

# make_upstream_repo [notag]
# Creates a repo with two commits and, unless 'notag' is given, the tag v1.0 on
# the last one, then echoes its path.
function make_upstream_repo()
{
    local repo="${TEST_TMP_DIR}/upstream/opus"
    mkdir -p "$repo"
    git_quiet init "$repo"
    echo "int main(){return 0;}" > "${repo}/main.c"
    git_quiet -C "$repo" add main.c
    git_quiet -C "$repo" commit -m "first commit"
    echo "// v1.0" >> "${repo}/main.c"
    git_quiet -C "$repo" add main.c
    git_quiet -C "$repo" commit -m "second commit"
    [[ "$1" == "notag" ]] || git_quiet -C "$repo" tag v1.0
    echo "$repo"
}

# make_patch_dir <dir> <file name>
# Creates a git formatted patch adding <file name> in <dir>.
function make_patch_dir()
{
    local dir="$1" file="${2:-feature.txt}"
    local scratch="${TEST_TMP_DIR}/patch-scratch-$RANDOM"
    mkdir -p "$dir" "$scratch"
    git_quiet init "$scratch"
    echo "base" > "${scratch}/base.txt"
    git_quiet -C "$scratch" add base.txt
    git_quiet -C "$scratch" commit -m "base"
    echo "patched" > "${scratch}/${file}"
    git_quiet -C "$scratch" add "$file"
    git_quiet -C "$scratch" commit -m "add ${file}"
    git_quiet -C "$scratch" format-patch -1 -o "$dir"
    echo "$dir"
}

# run_init_repo [env assignments...]
function run_init_repo()
{
    define_env_assert
    define_make_absolute_path
    define_echo_env

    run env \
        GIT_AUTHOR_NAME=tester GIT_AUTHOR_EMAIL=tester@example.com \
        GIT_COMMITTER_NAME=tester GIT_COMMITTER_EMAIL=tester@example.com \
        MR_PLAT=ios \
        MR_WORKSPACE="${TEST_TMP_DIR}/build" \
        MR_SRC_ROOT="${TEST_TMP_DIR}/build/src/ios" \
        MR_SHELL_ROOT_DIR="$TEST_TMP_DIR" \
        MR_ACTIVE_ARCHS="arm64" \
        REPO_DIR="opus" \
        GIT_COMMIT="v1.0" \
        GIT_REPO_VERSION="1.6.1" \
        GIT_LOCAL_REPO="extra/opus" \
        SKIP_PULL_BASE=0 \
        SMART_APPLY=0 \
        PATH="$PATH" \
        "$@" \
        "${REPO_ROOT}/do-init/init-repo.sh"
}

# echo_env is exported by parse-arguments.sh; init-repo.sh calls it directly
function define_echo_env()
{
    echo_env() {
        local name="$1"
        local value
        value=$(eval echo "\$$name")
        [[ -n "$value" ]] && echo "$name : [${value}]" >&2
        return 0
    }
    export -f echo_env
}

function test_copy_local_repo_requires_two_arguments()
{
    run "${REPO_ROOT}/do-init/copy-local-repo.sh"
    assert_failure "$status"
    assert_contains "$output" "invalid argvs"

    run "${REPO_ROOT}/do-init/copy-local-repo.sh" "${TEST_TMP_DIR}/only-src"
    assert_failure "$status"
}

function test_copy_local_repo_copies_only_the_last_commit_of_local_branch()
{
    local upstream
    upstream=$(make_upstream_repo)
    git_quiet -C "$upstream" checkout -B localBranch v1.0

    run env GIT_AUTHOR_NAME=tester GIT_AUTHOR_EMAIL=tester@example.com \
        GIT_COMMITTER_NAME=tester GIT_COMMITTER_EMAIL=tester@example.com \
        "${REPO_ROOT}/do-init/copy-local-repo.sh" "$upstream" "${TEST_TMP_DIR}/dest/opus-arm64"

    assert_success "$status"
    assert_file_exists "${TEST_TMP_DIR}/dest/opus-arm64/main.c"
    assert_equals "1" "$(git -C "${TEST_TMP_DIR}/dest/opus-arm64" rev-list --count HEAD)"
    assert_equals "localBranch" "$(git -C "${TEST_TMP_DIR}/dest/opus-arm64" rev-parse --abbrev-ref HEAD)"
}

function test_copy_local_repo_replaces_an_existing_destination()
{
    local upstream
    upstream=$(make_upstream_repo)
    git_quiet -C "$upstream" checkout -B localBranch v1.0
    mkdir -p "${TEST_TMP_DIR}/dest/opus-arm64"
    echo "stale" > "${TEST_TMP_DIR}/dest/opus-arm64/stale.txt"

    run env GIT_AUTHOR_NAME=tester GIT_AUTHOR_EMAIL=tester@example.com \
        GIT_COMMITTER_NAME=tester GIT_COMMITTER_EMAIL=tester@example.com \
        "${REPO_ROOT}/do-init/copy-local-repo.sh" "$upstream" "${TEST_TMP_DIR}/dest/opus-arm64"

    assert_success "$status"
    [[ ! -f "${TEST_TMP_DIR}/dest/opus-arm64/stale.txt" ]] || fail "stale destination was not removed"
}

function test_init_repo_clones_the_base_repo_and_checks_out_the_commit()
{
    local upstream
    upstream=$(make_upstream_repo)
    define_echo_env

    run_init_repo GIT_UPSTREAM="$upstream"
    assert_success "$status"
    assert_file_exists "${TEST_TMP_DIR}/build/extra/opus/main.c"
    assert_equals "localBranch" "$(git -C "${TEST_TMP_DIR}/build/extra/opus" rev-parse --abbrev-ref HEAD)"
}

function test_init_repo_creates_one_source_dir_per_arch()
{
    local upstream
    upstream=$(make_upstream_repo)
    define_echo_env

    run_init_repo GIT_UPSTREAM="$upstream" MR_ACTIVE_ARCHS="arm64 x86_64_simulator"
    assert_success "$status"
    assert_file_exists "${TEST_TMP_DIR}/build/src/ios/opus-arm64/main.c"
    assert_file_exists "${TEST_TMP_DIR}/build/src/ios/opus-x86_64_simulator/main.c"
}

function test_init_repo_keeps_a_tag_inherited_from_upstream()
{
    local upstream
    upstream=$(make_upstream_repo)

    run_init_repo GIT_UPSTREAM="$upstream"
    assert_success "$status"
    assert_contains "$output" "current tag:v1.0"
}

function test_init_repo_tags_an_untagged_repo_with_the_lib_version()
{
    local upstream
    upstream=$(make_upstream_repo notag)

    run_init_repo GIT_UPSTREAM="$upstream" GIT_COMMIT="master"
    assert_success "$status"
    assert_contains "$output" "current tag:1.6.1"
    assert_equals "1.6.1" "$(git -C "${TEST_TMP_DIR}/build/src/ios/opus-arm64" describe --tags)"
}

function test_init_repo_without_patch_dir_reports_no_patch()
{
    local upstream
    upstream=$(make_upstream_repo)
    define_echo_env

    run_init_repo GIT_UPSTREAM="$upstream"
    assert_contains "$output" "opus hasn't any patch"
}

function test_init_repo_applies_patches()
{
    local upstream
    upstream=$(make_upstream_repo)
    define_echo_env
    mkdir -p "${TEST_TMP_DIR}/configs/libs"
    make_patch_dir "${TEST_TMP_DIR}/patches/opus" "feature.txt" > /dev/null

    run_init_repo GIT_UPSTREAM="$upstream" \
        MR_LIB_CONFIG_PATH="${TEST_TMP_DIR}/configs/libs/opus.sh" \
        PATCH_DIR="../../patches/opus"

    assert_success "$status"
    assert_file_exists "${TEST_TMP_DIR}/build/src/ios/opus-arm64/feature.txt"
}

function test_init_repo_applies_platform_specific_patches()
{
    local upstream
    upstream=$(make_upstream_repo)
    define_echo_env
    mkdir -p "${TEST_TMP_DIR}/configs/libs"
    make_patch_dir "${TEST_TMP_DIR}/patches/opus" "common.txt" > /dev/null
    make_patch_dir "${TEST_TMP_DIR}/patches/opus-ios" "ios-only.txt" > /dev/null

    run_init_repo GIT_UPSTREAM="$upstream" \
        MR_LIB_CONFIG_PATH="${TEST_TMP_DIR}/configs/libs/opus.sh" \
        PATCH_DIR="../../patches/opus"

    assert_success "$status"
    assert_file_exists "${TEST_TMP_DIR}/build/src/ios/opus-arm64/common.txt"
    assert_file_exists "${TEST_TMP_DIR}/build/src/ios/opus-arm64/ios-only.txt"
    # the -pro dir is optional and simply skipped
    assert_contains "$output" "patch dir not exist"
    assert_contains "$output" "opus-pro"
}

function test_init_repo_smart_apply_applies_patches_too()
{
    local upstream
    upstream=$(make_upstream_repo)
    define_echo_env
    mkdir -p "${TEST_TMP_DIR}/configs/libs"
    make_patch_dir "${TEST_TMP_DIR}/patches/opus" "feature.txt" > /dev/null

    run_init_repo GIT_UPSTREAM="$upstream" \
        SMART_APPLY=1 \
        MR_LIB_CONFIG_PATH="${TEST_TMP_DIR}/configs/libs/opus.sh" \
        PATCH_DIR="../../patches/opus"

    assert_success "$status"
    assert_contains "$output" "Successfully applied"
    assert_file_exists "${TEST_TMP_DIR}/build/src/ios/opus-arm64/feature.txt"
}

function test_init_repo_skip_pull_base_without_local_repo_fails()
{
    local upstream
    upstream=$(make_upstream_repo)
    define_echo_env

    run_init_repo GIT_UPSTREAM="$upstream" SKIP_PULL_BASE=1
    assert_failure "$status"
    assert_contains "$output" "must clone by net firstly"
}

function test_init_repo_skip_pull_base_reuses_the_local_repo()
{
    local upstream
    upstream=$(make_upstream_repo)
    define_echo_env

    run_init_repo GIT_UPSTREAM="$upstream"
    assert_success "$status"

    # a second run must not need the network any more
    run_init_repo GIT_UPSTREAM="$upstream" SKIP_PULL_BASE=1
    assert_success "$status"
    assert_contains "$output" "skip pull opus"
}

function test_init_repo_requires_its_environment()
{
    define_echo_env
    define_env_assert
    define_make_absolute_path
    run env MR_PLAT=ios REPO_DIR=opus PATH="$PATH" "${REPO_ROOT}/do-init/init-repo.sh"
    assert_failure "$status"
    assert_contains "$output" "GIT_COMMIT is nil"
}

function test_init_repo_rejects_an_unknown_platform()
{
    local upstream
    upstream=$(make_upstream_repo)
    define_echo_env

    run_init_repo GIT_UPSTREAM="$upstream" MR_PLAT=windows
    assert_failure "$status"
}

# do-init/main.sh: sourcing it runs parse_args + main, with no libs to init
function run_do_init_main()
{
    define_make_absolute_path
    run env MR_PLAT=ios MR_VENDOR_LIBS="" MR_SHELL_ROOT_DIR="$TEST_TMP_DIR" \
        "$BASH" -c "source '${REPO_ROOT}/do-init/main.sh' $* > /dev/null; echo \"SKIP_PULL_BASE=[\$SKIP_PULL_BASE] SMART_APPLY=[\$SMART_APPLY] LIB_CONFIG_PATH=[\$LIB_CONFIG_PATH]\""
}

function test_do_init_main_defaults()
{
    run_do_init_main
    assert_success "$status"
    assert_contains "$output" "SKIP_PULL_BASE=[0]"
    assert_contains "$output" "SMART_APPLY=[0]"
    assert_contains "$output" "LIB_CONFIG_PATH=[]"
}

function test_do_init_main_flags()
{
    run_do_init_main --skip-pull-base --smart-apply
    assert_success "$status"
    assert_contains "$output" "SKIP_PULL_BASE=[1]"
    assert_contains "$output" "SMART_APPLY=[1]"
}

function test_do_init_main_stops_on_a_missing_lib_config()
{
    define_make_absolute_path
    run env MR_PLAT=ios MR_VENDOR_LIBS="ghost" MR_SHELL_ROOT_DIR="$TEST_TMP_DIR" \
        "${REPO_ROOT}/do-init/main.sh"
    assert_failure "$status"
    assert_contains "$output" "config not exist"
}

function test_do_init_main_stops_on_a_missing_specific_lib_config()
{
    define_make_absolute_path
    run env MR_PLAT=ios MR_VENDOR_LIBS="" MR_SHELL_ROOT_DIR="$TEST_TMP_DIR" \
        "${REPO_ROOT}/do-init/main.sh" -lib-config "${TEST_TMP_DIR}/nope.sh"
    assert_failure "$status"
    assert_contains "$output" "init specific lib config"
    assert_contains "$output" "config not exist"
}
