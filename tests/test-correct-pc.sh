#! /usr/bin/env bash
#
# Unit tests for do-install/correct-pc.sh
#
# The pc files shipped inside the pre compiled zips still point at the absolute
# paths of the machine which built them; correct-pc.sh rewrites them to the
# local product dir.
#

source "${REPO_ROOT}/tests/lib/stubs.sh"

REMOTE_ROOT="/Users/runner/work/MRFFToolChainBuildShell/MRFFToolChainBuildShell/build/product/macos"

# write_pc <product-root> <universal-dir> <lib> <content...>
# Creates <product-root>/<universal-dir>/<lib>/lib/pkgconfig/<lib>.pc and
# echoes its path.
function write_pc()
{
    local root="$1" universal="$2" lib="$3"
    shift 3
    local dir="${root}/${universal}/${lib}/lib/pkgconfig"
    mkdir -p "$dir"
    printf '%s\n' "$@" > "${dir}/${lib}.pc"
    echo "${dir}/${lib}.pc"
}

function run_correct_pc()
{
    define_my_sed_i
    run "${REPO_ROOT}/do-install/correct-pc.sh" "$1"
}

function test_prefix_is_rewritten_to_the_local_product_dir()
{
    local prod="${TEST_TMP_DIR}/product/macos"
    local pc
    pc=$(write_pc "$prod" universal opus \
        "prefix=${REMOTE_ROOT}/universal/opus" \
        'exec_prefix=${prefix}' \
        'libdir=${prefix}/lib' \
        'includedir=${prefix}/include' \
        'Name: Opus')

    run_correct_pc "$prod"
    assert_success "$status"
    assert_contains "$(cat "$pc")" "prefix=${prod}/universal/opus"
    assert_not_contains "$(cat "$pc")" "$REMOTE_ROOT"
}

function test_arch_suffix_is_replaced_by_universal()
{
    local prod="${TEST_TMP_DIR}/product/macos"
    local pc
    pc=$(write_pc "$prod" universal opus \
        "prefix=${REMOTE_ROOT}/opus-arm64" \
        "Libs: -L${REMOTE_ROOT}/opus-arm64/lib -lopus")

    run_correct_pc "$prod"
    assert_success "$status"
    local content
    content=$(cat "$pc")
    assert_not_contains "$content" "opus-arm64"
    assert_contains "$content" "universal/opus"
}

function test_x86_arch_suffix_is_replaced_by_universal()
{
    local prod="${TEST_TMP_DIR}/product/macos"
    local pc
    pc=$(write_pc "$prod" universal opus \
        "prefix=${REMOTE_ROOT}/opus-x86_64" \
        "Libs: -L${REMOTE_ROOT}/opus-x86_64/lib -lopus")

    run_correct_pc "$prod"
    local content
    content=$(cat "$pc")
    assert_not_contains "$content" "opus-x86_64"
    assert_contains "$content" "universal/opus"
}

function test_universal_simulator_is_folded_into_universal()
{
    local prod="${TEST_TMP_DIR}/product/ios"
    local pc
    pc=$(write_pc "$prod" universal-simulator bluray \
        "prefix=${REMOTE_ROOT}/universal-simulator/bluray" \
        "Cflags: -I${REMOTE_ROOT}/universal-simulator/bluray/include")

    run_correct_pc "$prod"
    assert_success "$status"
    local content
    content=$(cat "$pc")
    # the remote 'universal-simulator' segment is first folded into 'universal',
    # then the prefix is pointed at the dir the pc file actually lives in
    assert_not_contains "$content" "$REMOTE_ROOT"
    assert_contains "$content" "prefix=${prod}/universal-simulator/bluray"
    assert_contains "$content" "-I${prod}/universal-simulator/bluray/include"
}

function test_dependency_include_and_lib_paths_are_relocated()
{
    local prod="${TEST_TMP_DIR}/product/macos"
    local pc
    pc=$(write_pc "$prod" universal bluray \
        "prefix=${REMOTE_ROOT}/universal/bluray" \
        "Libs: -L${REMOTE_ROOT}/universal/bluray/lib -lbluray -L/some/other/machine/universal/xml2/lib -lxml2" \
        "Cflags: -I${REMOTE_ROOT}/universal/bluray/include -I/some/other/machine/universal/xml2/include")

    run_correct_pc "$prod"
    assert_success "$status"
    local content
    content=$(cat "$pc")
    assert_contains "$content" "-L${prod}/universal/xml2/lib"
    assert_contains "$content" "-I${prod}/universal/xml2/include"
    assert_not_contains "$content" "/some/other/machine"
}

function test_every_pc_file_below_the_given_dir_is_fixed()
{
    local prod="${TEST_TMP_DIR}/product/macos"
    local opus_pc bluray_pc
    opus_pc=$(write_pc "$prod" universal opus "prefix=${REMOTE_ROOT}/universal/opus")
    bluray_pc=$(write_pc "$prod" universal bluray "prefix=${REMOTE_ROOT}/universal/bluray")

    run_correct_pc "$prod"
    assert_success "$status"
    assert_contains "$(cat "$opus_pc")" "prefix=${prod}/universal/opus"
    assert_contains "$(cat "$bluray_pc")" "prefix=${prod}/universal/bluray"
}

function test_already_local_pc_file_is_left_untouched()
{
    local prod="${TEST_TMP_DIR}/product/macos"
    local pc
    pc=$(write_pc "$prod" universal opus \
        "prefix=${prod}/universal/opus" \
        'libdir=${prefix}/lib' \
        "Libs: -L${prod}/universal/opus/lib -lopus")
    local before
    before=$(cat "$pc")

    run_correct_pc "$prod"
    assert_success "$status"
    assert_equals "$before" "$(cat "$pc")"
}

function test_dir_without_pc_files_is_a_noop()
{
    local prod="${TEST_TMP_DIR}/product/macos"
    mkdir -p "${prod}/universal/opus/lib"

    run_correct_pc "$prod"
    assert_success "$status"
    assert_contains "$output" "fix pc files in folder: ${prod}"
}
