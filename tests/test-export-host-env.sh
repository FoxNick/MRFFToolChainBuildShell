#! /usr/bin/env bash
#
# Unit tests for tools/export-apple-host-env.sh and
# tools/export-android-host-env.sh
#

source "${REPO_ROOT}/tests/lib/stubs.sh"

# sources a host env script with the given environment and dumps the result
function run_host_env()
{
    local script="$1"
    shift
    # NDK variables may be set on the host (CI runners define them), drop them
    # so every test controls its own environment
    run env -u ANDROID_NDK_HOME -u ANDROID_NDK_ROOT -u ANDROID_NDK \
        "$@" bash -c "source '${REPO_ROOT}/tools/${script}'; env | sort"
}

function test_apple_ios_default_archs()
{
    stub_sysctl
    run_host_env export-apple-host-env.sh MR_PLAT=ios MR_VENDOR_LIBS=ffmpeg7 PATH="$PATH"
    assert_success "$status"
    assert_contains "$output" "MR_DEFAULT_ARCHS=arm64 arm64_simulator x86_64_simulator"
    assert_contains "$output" "MR_TAGET_OS=darwin"
    assert_contains "$output" "MR_FORCE_CROSS=true"
}

function test_apple_tvos_default_archs()
{
    stub_sysctl
    run_host_env export-apple-host-env.sh MR_PLAT=tvos MR_VENDOR_LIBS=ass PATH="$PATH"
    assert_contains "$output" "MR_DEFAULT_ARCHS=arm64 arm64_simulator x86_64_simulator"
}

function test_apple_macos_is_not_cross_compiled()
{
    stub_sysctl
    run_host_env export-apple-host-env.sh MR_PLAT=macos MR_VENDOR_LIBS=ass PATH="$PATH"
    assert_contains "$output" "MR_DEFAULT_ARCHS=x86_64 arm64"
    assert_not_contains "$output" "MR_FORCE_CROSS=true"
}

function test_apple_moltenvk_drops_x86_64_archs()
{
    stub_sysctl
    run_host_env export-apple-host-env.sh MR_PLAT=ios MR_VENDOR_LIBS=moltenvk PATH="$PATH"
    assert_contains "$output" "MR_DEFAULT_ARCHS=arm64 arm64_simulator"

    run_host_env export-apple-host-env.sh MR_PLAT=macos MR_VENDOR_LIBS=moltenvk PATH="$PATH"
    assert_contains "$output" "MR_DEFAULT_ARCHS=arm64"
}

function test_apple_moltenvk_is_detected_inside_a_lib_list()
{
    stub_sysctl
    run_host_env export-apple-host-env.sh MR_PLAT=ios MR_VENDOR_LIBS="dovi moltenvk placebo" PATH="$PATH"
    assert_contains "$output" "MR_DEFAULT_ARCHS=arm64 arm64_simulator"
}

function test_apple_host_nproc_comes_from_sysctl()
{
    stub_command sysctl 'echo 42'
    run_host_env export-apple-host-env.sh MR_PLAT=macos MR_VENDOR_LIBS=opus PATH="$PATH"
    assert_contains "$output" "MR_HOST_NPROC=42"
}

function test_android_env_from_ndk_home()
{
    local ndk
    ndk=$(make_fake_ndk "27c")
    run_host_env export-android-host-env.sh ANDROID_NDK_HOME="$ndk" OSTYPE="linux-gnu" PATH="$PATH"
    assert_success "$status"
    assert_contains "$output" "MR_ANDROID_NDK_HOME=$ndk"
    assert_contains "$output" "MR_NDK_REL=r27c"
    assert_contains "$output" "MR_TOOLCHAIN_ROOT=${ndk}/toolchains/llvm/prebuilt/linux-x86_64"
    assert_contains "$output" "MR_SYS_ROOT=${ndk}/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
    assert_contains "$output" "MR_MAKE_EXECUTABLE=${ndk}/prebuilt/linux-x86_64/bin/make"
    assert_contains "$output" "MR_DEFAULT_ARCHS=armv7a arm64 x86 x86_64"
    assert_contains "$output" "MR_TAGET_OS=android"
    assert_contains "$output" "MR_PLAT=android"
    assert_contains "$output" "MR_FORCE_CROSS=true"
}

function test_android_toolchain_is_prepended_to_path()
{
    local ndk
    ndk=$(make_fake_ndk)
    run_host_env export-android-host-env.sh ANDROID_NDK_HOME="$ndk" OSTYPE="linux-gnu" PATH="$PATH"
    assert_contains "$output" "PATH=${ndk}/toolchains/llvm/prebuilt/linux-x86_64/bin:"
}

function test_android_ndk_root_is_used_as_fallback()
{
    local ndk
    ndk=$(make_fake_ndk)
    run_host_env export-android-host-env.sh ANDROID_NDK_ROOT="$ndk" OSTYPE="linux-gnu" PATH="$PATH"
    assert_success "$status"
    assert_contains "$output" "MR_ANDROID_NDK_HOME=$ndk"
}

function test_android_ndk_is_used_as_last_fallback()
{
    local ndk
    ndk=$(make_fake_ndk)
    run_host_env export-android-host-env.sh ANDROID_NDK="$ndk" OSTYPE="linux-gnu" PATH="$PATH"
    assert_success "$status"
    assert_contains "$output" "MR_ANDROID_NDK_HOME=$ndk"
}

function test_android_without_any_ndk_variable_fails()
{
    run_host_env export-android-host-env.sh OSTYPE="linux-gnu" PATH="$PATH"
    assert_failure "$status"
    assert_contains "$output" "You must define ANDROID_NDK_HOME or ANDROID_NDK_ROOT or ANDROID_NDK"
}

function test_my_sed_i_edits_file_in_place()
{
    define_my_sed_i
    echo "prefix=/old/path" > "${TEST_TMP_DIR}/lib.pc"
    my_sed_i "s|/old/path|/new/path|g" "${TEST_TMP_DIR}/lib.pc"
    assert_equals "prefix=/new/path" "$(cat "${TEST_TMP_DIR}/lib.pc")"
    # no backup file left behind on either platform
    [[ ! -f "${TEST_TMP_DIR}/lib.pc''" ]] || fail "sed left a backup file"
}
