#! /usr/bin/env bash
#
# Unit tests for tools/export-apple-pkg-config-dir.sh and
# tools/export-android-pkg-config-dir.sh
#

source "${REPO_ROOT}/tests/lib/stubs.sh"

# creates <root>/<universal>/<lib>[-<arch>]/lib/pkgconfig/<lib>.pc
function make_pc_file()
{
    local root="$1" universal="$2" lib="$3" arch="${4:-}"
    local name="$lib"
    [[ -n "$arch" ]] && name="${lib}-${arch}"
    local dir="${root}/${universal}/${name}/lib/pkgconfig"
    mkdir -p "$dir"
    printf 'prefix=%s\nName: %s\n' "${root}/${universal}/${name}" "$lib" > "${dir}/${lib}.pc"
    echo "$dir"
}

function run_pkg_config_dir()
{
    local script="$1"
    shift
    define_env_assert
    run env "$@" bash -c "source '${REPO_ROOT}/tools/${script}'; echo \"PKG_CONFIG_LIBDIR=\$PKG_CONFIG_LIBDIR\""
}

function test_apple_collects_every_pkgconfig_dir()
{
    local prod="${TEST_TMP_DIR}/product/ios"
    local opus_dir bluray_dir
    opus_dir=$(make_pc_file "$prod" universal opus)
    bluray_dir=$(make_pc_file "$prod" universal bluray)

    run_pkg_config_dir export-apple-pkg-config-dir.sh \
        MR_UNI_PROD_DIR="${prod}/universal" \
        MR_UNI_SIM_PROD_DIR="${prod}/universal-simulator"

    assert_success "$status"
    assert_contains "$output" "$opus_dir"
    assert_contains "$output" "$bluray_dir"
    # entries are joined with a colon, like pkg-config expects
    assert_contains "$output" ":"
}

function test_apple_simulator_uses_the_simulator_product_dir()
{
    local prod="${TEST_TMP_DIR}/product/ios"
    local device_dir sim_dir
    device_dir=$(make_pc_file "$prod" universal opus)
    sim_dir=$(make_pc_file "$prod" universal-simulator opus)

    run_pkg_config_dir export-apple-pkg-config-dir.sh \
        MR_IS_SIMULATOR=1 \
        MR_UNI_PROD_DIR="${prod}/universal" \
        MR_UNI_SIM_PROD_DIR="${prod}/universal-simulator"

    assert_contains "$output" "$sim_dir"
    assert_not_contains "$output" "$device_dir"
}

function test_apple_missing_product_dir_yields_empty_libdir()
{
    run_pkg_config_dir export-apple-pkg-config-dir.sh \
        MR_UNI_PROD_DIR="${TEST_TMP_DIR}/does-not-exist/universal" \
        MR_UNI_SIM_PROD_DIR="${TEST_TMP_DIR}/does-not-exist/universal-simulator"

    assert_success "$status"
    assert_contains "$output" "PKG_CONFIG_LIBDIR="
    assert_not_contains "$output" "PKG_CONFIG_LIBDIR=/"
}

function test_apple_requires_the_product_dir_variables()
{
    run_pkg_config_dir export-apple-pkg-config-dir.sh MR_UNI_PROD_DIR="" MR_UNI_SIM_PROD_DIR=""
    assert_failure "$status"
    assert_contains "$output" "MR_UNI_PROD_DIR is nil"
}

function test_android_filters_by_arch()
{
    local prod="${TEST_TMP_DIR}/product/android"
    local arm64_dir x86_dir
    arm64_dir=$(make_pc_file "$prod" universal opus arm64)
    x86_dir=$(make_pc_file "$prod" universal opus x86_64)

    run_pkg_config_dir export-android-pkg-config-dir.sh \
        _MR_ARCH="opus-arm64" \
        MR_UNI_PROD_DIR="${prod}/universal" \
        MR_UNI_SIM_PROD_DIR="${prod}/universal-simulator"

    assert_success "$status"
    assert_contains "$output" "$arm64_dir"
    assert_not_contains "$output" "$x86_dir"
}

function test_android_missing_product_dir_yields_empty_libdir()
{
    run_pkg_config_dir export-android-pkg-config-dir.sh \
        _MR_ARCH="arm64" \
        MR_UNI_PROD_DIR="${TEST_TMP_DIR}/nope/universal" \
        MR_UNI_SIM_PROD_DIR="${TEST_TMP_DIR}/nope/universal-simulator"

    assert_success "$status"
    assert_contains "$output" "PKG_CONFIG_LIBDIR="
    assert_not_contains "$output" "PKG_CONFIG_LIBDIR=/"
}
