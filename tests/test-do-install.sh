#! /usr/bin/env bash
#
# Unit tests for do-install/main.sh, do-install/install-pre-lib.sh,
# do-install/install-pre-xcf.sh and do-install/download-uncompress.sh
#

source "${REPO_ROOT}/tests/lib/stubs.sh"

# Copies do-install into the temp dir and replaces the scripts which touch the
# network / the file system by stubs echoing the environment they receive.
# Echoes the path of the copy.
function make_do_install_sandbox()
{
    local dir="${TEST_TMP_DIR}/do-install"
    cp -R "${REPO_ROOT}/do-install" "$dir"

    cat << 'EOF' > "${dir}/download-uncompress.sh"
#! /usr/bin/env bash
echo "download-uncompress MR_DOWNLOAD_ONAME=[$MR_DOWNLOAD_ONAME]"
echo "download-uncompress MR_DOWNLOAD_URL=[$MR_DOWNLOAD_URL]"
echo "download-uncompress MR_UNCOMPRESS_DIR=[$MR_UNCOMPRESS_DIR]"
EOF

    cat << 'EOF' > "${dir}/correct-pc.sh"
#! /usr/bin/env bash
echo "correct-pc [$1]"
EOF

    chmod +x "${dir}/download-uncompress.sh" "${dir}/correct-pc.sh"
    echo "$dir"
}

# run_parse_lib_config <plat> [env assignments...]
# Sources do-install/main.sh and dumps what parse_lib_config extracted.
function run_parse_lib_config()
{
    local plat="$1"
    shift
    run env MR_PLAT="$plat" "$@" \
        "$BASH" -c "source '${REPO_ROOT}/do-install/main.sh' > /dev/null; parse_lib_config; echo \"TAG=[\$TAG] LIB_NAME=[\$LIB_NAME] VER=[\$VER]\""
}

function test_parse_lib_config_of_a_plain_version_tag()
{
    run_parse_lib_config ios PRE_COMPILE_TAG_IOS=opus-1.6.1-260409182634
    assert_success "$status"
    assert_contains "$output" "TAG=[opus-1.6.1-260409182634]"
    assert_contains "$output" "LIB_NAME=[opus]"
    assert_contains "$output" "VER=[1.6.1]"
}

function test_parse_lib_config_of_a_branch_and_commit_tag()
{
    run_parse_lib_config macos PRE_COMPILE_TAG_MACOS=yuv-main-f94b8cf7-260228135452
    assert_success "$status"
    assert_contains "$output" "LIB_NAME=[yuv]"
    assert_contains "$output" "VER=[main-f94b8cf7]"
}

function test_parse_lib_config_picks_the_tag_of_the_platform()
{
    run_parse_lib_config android \
        PRE_COMPILE_TAG_IOS=opus-1.0.0-1 \
        PRE_COMPILE_TAG_ANDROID=opus-2.0.0-2
    assert_contains "$output" "VER=[2.0.0]"
}

function test_parse_lib_config_without_tag_stops()
{
    run_parse_lib_config tvos
    assert_contains "$output" "PRE_COMPILE_TAG_TVOS can't be nil"
    assert_not_contains "$output" "LIB_NAME=[opus]"
}

function test_install_pre_lib_builds_the_release_url()
{
    local sandbox
    sandbox=$(make_do_install_sandbox)
    run env MR_PLAT=macos TAG=opus-1.6.1-260409182634 LIB_NAME=opus VER=1.6.1 \
        MR_WORKSPACE="${TEST_TMP_DIR}/build" \
        "${sandbox}/install-pre-lib.sh"

    assert_success "$status"
    assert_contains "$output" "MR_DOWNLOAD_ONAME=[opus-1.6.1-260409182634/opus-macos-universal-1.6.1.zip]"
    assert_contains "$output" "MR_DOWNLOAD_URL=[https://github.com/debugly/MRFFToolChainBuildShell/releases/download/opus-1.6.1-260409182634/opus-macos-universal-1.6.1.zip]"
    assert_contains "$output" "MR_UNCOMPRESS_DIR=[${TEST_TMP_DIR}/build/product/macos/universal]"
    # the pc files of the extracted lib and of its dependencies are corrected
    assert_contains "$output" "correct-pc [${TEST_TMP_DIR}/build/product/macos/universal]"
}

function test_install_pre_lib_honours_a_download_mirror()
{
    local sandbox
    sandbox=$(make_do_install_sandbox)
    run env MR_PLAT=macos TAG=opus-1.6.1-260409182634 LIB_NAME=opus VER=1.6.1 \
        MR_WORKSPACE="${TEST_TMP_DIR}/build" \
        MR_DOWNLOAD_BASEURL="https://mirror.example.com/libs/" \
        "${sandbox}/install-pre-lib.sh"

    assert_contains "$output" "MR_DOWNLOAD_URL=[https://mirror.example.com/libs/opus-1.6.1-260409182634/opus-macos-universal-1.6.1.zip]"
}

function test_install_pre_lib_installs_device_and_simulator_on_ios()
{
    local sandbox
    sandbox=$(make_do_install_sandbox)
    run env MR_PLAT=ios TAG=opus-1.6.1-260409182634 LIB_NAME=opus VER=1.6.1 \
        MR_WORKSPACE="${TEST_TMP_DIR}/build" \
        "${sandbox}/install-pre-lib.sh"

    assert_success "$status"
    assert_contains "$output" "opus-ios-universal-1.6.1.zip"
    assert_contains "$output" "opus-ios-universal-simulator-1.6.1.zip"
    assert_contains "$output" "MR_UNCOMPRESS_DIR=[${TEST_TMP_DIR}/build/product/ios/universal-simulator]"
}

function test_install_pre_lib_installs_only_one_slice_on_android()
{
    local sandbox
    sandbox=$(make_do_install_sandbox)
    run env MR_PLAT=android TAG=opus-1.6.1-260409182634 LIB_NAME=opus VER=1.6.1 \
        MR_WORKSPACE="${TEST_TMP_DIR}/build" \
        "${sandbox}/install-pre-lib.sh"

    assert_contains "$output" "opus-android-universal-1.6.1.zip"
    assert_not_contains "$output" "universal-simulator"
}

function test_install_pre_xcf_builds_the_xcframework_url()
{
    local sandbox
    sandbox=$(make_do_install_sandbox)
    run env PRE_COMPILE_TAG=ass-0.17.4-260409182634 LIB_NAME=ass VER=0.17.4 \
        MR_XCFRMK_DIR="${TEST_TMP_DIR}/build/product/xcframework" \
        "${sandbox}/install-pre-xcf.sh"

    assert_success "$status"
    assert_contains "$output" "MR_DOWNLOAD_ONAME=[ass-0.17.4-260409182634-xcfmwk.zip]"
    assert_contains "$output" "MR_DOWNLOAD_URL=[https://github.com/debugly/MRFFToolChainBuildShell/releases/download/ass-0.17.4-260409182634/ass-apple-xcframework-0.17.4.zip]"
    assert_contains "$output" "MR_UNCOMPRESS_DIR=[${TEST_TMP_DIR}/build/product/xcframework]"
}

# download-uncompress.sh with curl and unzip stubbed out
function run_download_uncompress()
{
    define_env_assert
    run env \
        MR_WORKSPACE="${TEST_TMP_DIR}/build" \
        MR_DOWNLOAD_URL="https://example.com/opus.zip" \
        MR_DOWNLOAD_ONAME="opus-1.6.1/opus-macos-universal-1.6.1.zip" \
        MR_UNCOMPRESS_DIR="${TEST_TMP_DIR}/build/product/macos/universal" \
        PATH="$PATH" \
        "${REPO_ROOT}/do-install/download-uncompress.sh"
}

function test_download_uncompress_downloads_then_extracts()
{
    stub_command curl 'while [[ $# -gt 0 ]]; do [[ "$1" == "-o" ]] && { shift; echo "zipdata" > "$1"; }; shift; done'
    stub_command unzip 'echo "unzip $*"'

    run_download_uncompress
    assert_success "$status"
    assert_contains "$output" "extract zip file"
    assert_contains "$output" "unzip"
    assert_file_exists "${TEST_TMP_DIR}/build/pre/opus-1.6.1/opus-macos-universal-1.6.1.zip"
}

function test_download_uncompress_skips_an_already_downloaded_file()
{
    stub_command curl 'echo "curl must not be called" >&2; exit 1'
    stub_command unzip 'echo "unzip $*"'
    mkdir -p "${TEST_TMP_DIR}/build/pre/opus-1.6.1"
    echo "zipdata" > "${TEST_TMP_DIR}/build/pre/opus-1.6.1/opus-macos-universal-1.6.1.zip"

    run_download_uncompress
    assert_success "$status"
    assert_contains "$output" "already exist,skip download"
    assert_not_contains "$output" "curl must not be called"
}

function test_download_uncompress_fails_when_download_produces_nothing()
{
    stub_command curl 'exit 22'
    stub_command unzip 'echo "unzip $*"'

    run_download_uncompress
    assert_failure "$status"
    assert_not_contains "$output" "extract zip file"
}

function test_download_uncompress_requires_its_environment()
{
    define_env_assert
    run env MR_WORKSPACE="${TEST_TMP_DIR}/build" PATH="$PATH" \
        "${REPO_ROOT}/do-install/download-uncompress.sh"
    assert_failure "$status"
    assert_contains "$output" "MR_DOWNLOAD_URL is nil"
}

function test_main_installs_every_requested_lib()
{
    local sandbox
    sandbox=$(make_do_install_sandbox)
    cp -R "${REPO_ROOT}/configs" "${TEST_TMP_DIR}/configs"
    define_make_absolute_path

    run env MR_PLAT=macos MR_VENDOR_LIBS="opus yuv" \
        MR_SHELL_ROOT_DIR="$TEST_TMP_DIR" \
        MR_WORKSPACE="${TEST_TMP_DIR}/build" \
        "${sandbox}/main.sh"

    assert_success "$status"
    assert_contains "$output" "opus-macos-universal"
    assert_contains "$output" "yuv-macos-universal"
}

function test_main_correct_pc_mode_only_fixes_pc_files()
{
    local sandbox
    sandbox=$(make_do_install_sandbox)

    run env MR_PLAT=macos MR_VENDOR_LIBS="opus" \
        "${sandbox}/main.sh" -correct-pc "${TEST_TMP_DIR}/product"

    assert_success "$status"
    assert_contains "$output" "correct-pc [${TEST_TMP_DIR}/product]"
    assert_not_contains "$output" "MR_DOWNLOAD_URL"
}

function test_main_stops_on_a_missing_lib_config()
{
    local sandbox
    sandbox=$(make_do_install_sandbox)
    define_make_absolute_path

    run env MR_PLAT=macos MR_VENDOR_LIBS="doesnotexist" \
        MR_SHELL_ROOT_DIR="$TEST_TMP_DIR" \
        "${sandbox}/main.sh"

    assert_failure "$status"
    assert_contains "$output" "config not exist"
}
