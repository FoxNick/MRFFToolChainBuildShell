#! /usr/bin/env bash
#
# Unit tests for tools/prepare-build-workspace.sh
#

source "${REPO_ROOT}/tests/lib/stubs.sh"

function run_prepare_workspace()
{
    run env "$@" bash -c "source '${REPO_ROOT}/tools/prepare-build-workspace.sh'; env | sort"
}

function test_workspace_defaults_to_repo_build_dir()
{
    run_prepare_workspace MR_PLAT=ios PATH="$PATH"
    assert_success "$status"
    assert_contains "$output" "MR_WORKSPACE=${REPO_ROOT}/build"
    assert_contains "$output" "MR_SRC_ROOT=${REPO_ROOT}/build/src/ios"
    assert_contains "$output" "MR_PRODUCT_ROOT=${REPO_ROOT}/build/product/ios"
}

function test_explicit_workspace_is_respected()
{
    run_prepare_workspace MR_PLAT=android MR_WORKSPACE="${TEST_TMP_DIR}/ws" PATH="$PATH"
    assert_contains "$output" "MR_SRC_ROOT=${TEST_TMP_DIR}/ws/src/android"
    assert_contains "$output" "MR_PRODUCT_ROOT=${TEST_TMP_DIR}/ws/product/android"
}

function test_universal_and_per_platform_product_dirs()
{
    run_prepare_workspace MR_PLAT=tvos MR_WORKSPACE="${TEST_TMP_DIR}/ws" PATH="$PATH"
    assert_contains "$output" "MR_UNI_PROD_DIR=${TEST_TMP_DIR}/ws/product/tvos/universal"
    assert_contains "$output" "MR_UNI_SIM_PROD_DIR=${TEST_TMP_DIR}/ws/product/tvos/universal-simulator"
    assert_contains "$output" "MR_XCFRMK_DIR=${TEST_TMP_DIR}/ws/product/xcframework"
    assert_contains "$output" "MR_IOS_PRODUCT_ROOT=${TEST_TMP_DIR}/ws/product/ios"
    assert_contains "$output" "MR_MACOS_PRODUCT_ROOT=${TEST_TMP_DIR}/ws/product/macos"
    assert_contains "$output" "MR_TVOS_PRODUCT_ROOT=${TEST_TMP_DIR}/ws/product/tvos"
}

function test_build_tools_are_looked_up_in_path()
{
    stub_command cmake 'echo cmake'
    stub_command ninja 'echo ninja'
    stub_command meson 'echo meson'
    stub_command nasm 'echo nasm'
    stub_command pkg-config 'echo pkg-config'

    run_prepare_workspace MR_PLAT=macos MR_WORKSPACE="${TEST_TMP_DIR}/ws" PATH="$PATH"
    assert_contains "$output" "MR_CMAKE_EXECUTABLE=${STUB_BIN_DIR}/cmake"
    assert_contains "$output" "MR_NINJA_EXECUTABLE=${STUB_BIN_DIR}/ninja"
    assert_contains "$output" "MR_MESON_EXECUTABLE=${STUB_BIN_DIR}/meson"
    assert_contains "$output" "MR_NASM_EXECUTABLE=${STUB_BIN_DIR}/nasm"
    assert_contains "$output" "MR_PKG_CONFIG_EXECUTABLE=${STUB_BIN_DIR}/pkg-config"
    assert_contains "$output" "PKG_CONFIG=${STUB_BIN_DIR}/pkg-config"
}

function test_missing_build_tools_are_empty_not_fatal()
{
    # an empty PATH means none of the build tools can be found; the script must
    # still succeed, the missing tools are only reported later by the compile
    # scripts
    run env MR_PLAT=macos MR_WORKSPACE="${TEST_TMP_DIR}/ws" PATH="/nonexistent" \
        "$BASH" -c "source '${REPO_ROOT}/tools/prepare-build-workspace.sh'; echo \"[\$MR_CMAKE_EXECUTABLE]\""
    assert_success "$status"
    assert_contains "$output" "[]"
}
