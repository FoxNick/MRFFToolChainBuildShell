#! /usr/bin/env bash
#
# Unit tests for tools/parse-arguments.sh
#

source "${REPO_ROOT}/tests/lib/stubs.sh"

function setup()
{
    # keep parse_path/make_absolute_path away from the working copy
    export MR_SHELL_ROOT_DIR="$TEST_TMP_DIR"
}

function test_without_action_prints_main_usage()
{
    run_parse_arguments
    assert_success "$status"
    assert_contains "$output" "usage: ./main.sh [options]"
    assert_contains "$output" "+compile"
}

function test_unknown_action_prints_main_usage()
{
    run_parse_arguments notaction -p ios -l opus
    assert_success "$status"
    assert_contains "$output" "usage: ./main.sh [options]"
    assert_not_contains "$output" "MR_ACTION=notaction"
}

function test_missing_platform_fails()
{
    run_parse_arguments init -l opus
    assert_failure "$status"
    assert_contains "$output" "platform can't empty"
    # the usage of the requested action is printed as a hint
    assert_contains "$output" "usage: ./main.sh init [options]"
}

function test_invalid_platform_fails()
{
    run_parse_arguments init -p windows -l opus
    assert_failure "$status"
    assert_contains "$output" "platform must be: [ios|macos|tvos|android]"
}

function test_missing_libs_fails()
{
    run_parse_arguments init -p ios
    assert_failure "$status"
    assert_contains "$output" "libs can't be nil"
}

function test_lib_config_replaces_libs_requirement()
{
    run_parse_arguments init -p ios -lib-config "${TEST_TMP_DIR}/ffmpeg.sh"
    assert_success "$status"
    assert_contains "$output" "MR_UNKNOWN_OPTIONS"
}

function test_correct_pc_replaces_libs_requirement()
{
    run_parse_arguments install -p macos -correct-pc "${TEST_TMP_DIR}/product"
    assert_success "$status"
}

function test_init_action_exports_expected_env()
{
    run_parse_arguments init -p ios -l "opus ffmpeg7"
    assert_success "$status"
    assert_contains "$output" "MR_ACTION=init"
    assert_contains "$output" "MR_PLAT=ios"
    assert_contains "$output" "MR_VENDOR_LIBS=opus ffmpeg7"
    # no sub command for init
    assert_contains "$output" "MR_CMD="
}

function test_compile_defaults_to_build_command()
{
    run_parse_arguments compile -p macos -l opus
    assert_success "$status"
    assert_contains "$output" "MR_CMD=build"
}

function test_compile_command_can_be_overridden()
{
    run_parse_arguments compile -p macos -l opus -c rebuild
    assert_success "$status"
    assert_contains "$output" "MR_CMD=rebuild"
}

function test_release_cflags_by_default()
{
    run_parse_arguments compile -p macos -l opus
    assert_contains "$output" "MR_INIT_CFLAGS=-O3 -DNDEBUG"
    assert_not_contains "$output" "MR_DEBUG=debug"
}

function test_debug_flag_switches_cflags()
{
    run_parse_arguments compile -p macos -l opus --debug
    assert_contains "$output" "MR_DEBUG=debug"
    assert_contains "$output" "MR_INIT_CFLAGS=-g -O0 -D_DEBUG"
}

function test_fmwk_flag_is_exported()
{
    run_parse_arguments compile -p ios -l opus --fmwk
    assert_contains "$output" "MR_MAKE_XCFRAMEWORK=1"
}

function test_archs_default_to_platform_defaults()
{
    run_parse_arguments compile -p macos -l opus
    assert_contains "$output" "MR_ACTIVE_ARCHS=x86_64 arm64"
}

function test_valid_arch_subset_is_kept()
{
    run_parse_arguments compile -p macos -l opus -a arm64
    assert_contains "$output" "MR_ACTIVE_ARCHS=arm64"
}

function test_arch_not_supported_by_platform_fails()
{
    run_parse_arguments compile -p macos -l opus -a armv7a
    assert_failure "$status"
    assert_contains "$output" "the armv7a is not validate on macos"
}

function test_android_archs()
{
    run_parse_arguments compile -p android -l opus -a "arm64 x86_64"
    assert_success "$status"
    assert_contains "$output" "MR_ACTIVE_ARCHS=arm64 x86_64"
}

function test_nproc_override()
{
    run_parse_arguments compile -p macos -l opus -j 3
    assert_contains "$output" "override thread count:3"
    assert_contains "$output" "MR_HOST_NPROC=3"
}

function test_workspace_is_made_absolute()
{
    run_parse_arguments compile -p macos -l opus -s work/space
    assert_success "$status"
    assert_contains "$output" "MR_WORKSPACE=${TEST_TMP_DIR}/work/space"
    [[ -d "${TEST_TMP_DIR}/work/space" ]] || fail "relative workspace dir was not created"
}

function test_absolute_workspace_is_kept()
{
    mkdir -p "${TEST_TMP_DIR}/abs-work"
    run_parse_arguments compile -p macos -l opus -s "${TEST_TMP_DIR}/abs-work"
    assert_contains "$output" "MR_WORKSPACE=${TEST_TMP_DIR}/abs-work"
}

function test_unknown_options_are_forwarded()
{
    run_parse_arguments compile -p macos -l opus --whatever extra
    assert_success "$status"
    assert_contains "$output" "MR_UNKNOWN_OPTIONS : [--whatever extra]"
}

function test_help_prints_usage_of_the_action()
{
    run_parse_arguments compile --help
    assert_success "$status"
    assert_contains "$output" "usage: ./main.sh compile [options]"

    run_parse_arguments install --help
    assert_success "$status"
    assert_contains "$output" "usage: ./main.sh install [options]"
}

function test_parse_path_creates_relative_dir()
{
    eval_with_parse_arguments 'parse_path "sub/dir"' compile -p macos -l opus
    assert_success "$status"
    assert_equals "${TEST_TMP_DIR}/sub/dir" "$output"
}

function test_parse_path_keeps_absolute_dir()
{
    mkdir -p "${TEST_TMP_DIR}/already"
    eval_with_parse_arguments "parse_path '${TEST_TMP_DIR}/already'" compile -p macos -l opus
    assert_equals "${TEST_TMP_DIR}/already" "$output"
}

function test_make_absolute_path_of_relative_file()
{
    mkdir -p "${TEST_TMP_DIR}/configs/libs"
    eval_with_parse_arguments 'make_absolute_path "configs/libs/opus.sh"' compile -p macos -l opus
    assert_success "$status"
    assert_equals "${TEST_TMP_DIR}/configs/libs/opus.sh" "$output"
}

function test_make_absolute_path_of_missing_parent_dir()
{
    eval_with_parse_arguments 'make_absolute_path "does/not/exist/opus.sh"' compile -p macos -l opus
    # a missing parent dir can not be resolved: the caller gets a bogus path
    # instead of an error, and callers must check the file themselves
    assert_contains "$output" "/opus.sh"
    assert_not_contains "$output" "${TEST_TMP_DIR}/does/not/exist/opus.sh"
}

function test_make_absolute_path_keeps_absolute_file()
{
    eval_with_parse_arguments "make_absolute_path '${TEST_TMP_DIR}/my-lib.sh'" compile -p macos -l opus
    assert_success "$status"
    assert_equals "${TEST_TMP_DIR}/my-lib.sh" "$output"
}

function test_env_assert_fails_when_variable_is_missing()
{
    eval_with_parse_arguments 'env_assert "MR_NOT_DEFINED_AT_ALL"' compile -p macos -l opus
    assert_failure "$status"
    assert_contains "$output" "MR_NOT_DEFINED_AT_ALL is nil"
}

function test_env_assert_prints_value_when_present()
{
    eval_with_parse_arguments 'export MR_SOMETHING=hello; env_assert "MR_SOMETHING"' compile -p macos -l opus
    assert_success "$status"
    assert_contains "$output" "MR_SOMETHING : [hello]"
}

function test_echo_env_is_quiet_for_missing_variable()
{
    eval_with_parse_arguments 'echo_env "MR_NOT_DEFINED_AT_ALL"; echo done' compile -p macos -l opus
    assert_success "$status"
    assert_equals "done" "$output"
}

function test_echo_env_prints_present_variable()
{
    eval_with_parse_arguments 'export MR_SOMETHING=hello; echo_env "MR_SOMETHING"' compile -p macos -l opus
    assert_contains "$output" "MR_SOMETHING : [hello]"
}

function test_helper_functions_are_exported_to_child_scripts()
{
    eval_with_parse_arguments 'bash -c "make_absolute_path /tmp/x.sh"' compile -p macos -l opus
    assert_success "$status" "make_absolute_path must be usable by child scripts"
    assert_equals "/tmp/x.sh" "$output"
}
