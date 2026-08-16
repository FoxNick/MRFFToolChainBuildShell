#! /usr/bin/env bash
#
# Unit tests for configs/ffconfig/auto-detect-third-libs.sh
#
# The script turns the libs found by pkg-config plus the FFmpeg version into
# the configure flags stored in THIRD_CFG_FLAGS.
#

source "${REPO_ROOT}/tests/lib/stubs.sh"

AUTO_DETECT="${REPO_ROOT}/configs/ffconfig/auto-detect-third-libs.sh"

# stub_pkg_config <available modules...>
# Only the listed modules are 'installed', everything else is missing.
function stub_pkg_config()
{
    local available="$*"
    stub_command pkg-config "
available='${available}'
mod=
for arg in \"\$@\"; do
    case \"\$arg\" in
        -*) ;;
        *) mod=\"\$arg\" ;;
    esac
done
for a in \$available; do
    if [[ \"\$a\" == \"\$mod\" ]]; then
        echo \"1.2.3\"
        exit 0
    fi
done
exit 1
"
}

# creates a fake ffmpeg source dir whose configure --help lists the features
function make_fake_ff_source()
{
    local dir="${TEST_TMP_DIR}/ffmpeg-src"
    mkdir -p "$dir"
    {
        echo '#! /usr/bin/env bash'
        echo 'if [[ "$1" == "--help" ]]; then'
        printf '    printf "%%s\\n" %s\n' "$*"
        echo 'fi'
    } > "${dir}/configure"
    chmod +x "${dir}/configure"
    echo "$dir"
}

# run_auto_detect <ffmpeg version> [extra env assignments...]
function run_auto_detect()
{
    local version="$1"
    shift
    local src
    src=$(make_fake_ff_source "--enable-libdvdread")
    run env \
        GIT_REPO_VERSION="$version" \
        MR_BUILD_SOURCE="$src" \
        MR_BUILD_PREFIX="${TEST_TMP_DIR}/prefix" \
        MR_FF_ARCH="arm64" \
        MR_TAGET_OS="darwin" \
        MR_PLAT="ios" \
        MR_ARCH="arm64" \
        MR_SYS_ROOT="${TEST_TMP_DIR}/sysroot" \
        PATH="$PATH" \
        "$@" \
        "$BASH" -c "source '${AUTO_DETECT}' > /dev/null; echo \"\$THIRD_CFG_FLAGS\""
}

# calls gt_or_equal of the script, whose result is empty for 'lower than'
function run_gt_or_equal()
{
    stub_pkg_config
    run env \
        GIT_REPO_VERSION="7.1.1" \
        MR_BUILD_SOURCE="${TEST_TMP_DIR}/ffmpeg-src" \
        MR_BUILD_PREFIX="${TEST_TMP_DIR}/prefix" \
        MR_PLAT="ios" MR_ARCH="arm64" MR_FF_ARCH="arm64" MR_TAGET_OS="darwin" \
        MR_SYS_ROOT="${TEST_TMP_DIR}/sysroot" PATH="$PATH" \
        "$BASH" -c "source '${AUTO_DETECT}' > /dev/null; echo \"[\$(gt_or_equal '$1' '$2')]\""
}

function test_gt_or_equal_greater()
{
    make_fake_ff_source > /dev/null
    run_gt_or_equal "7.1.1" "6"
    assert_equals "[1]" "$output"
}

function test_gt_or_equal_equal()
{
    make_fake_ff_source > /dev/null
    run_gt_or_equal "7.1.1" "7.1.1"
    assert_equals "[1]" "$output"
}

function test_gt_or_equal_lower_is_empty()
{
    make_fake_ff_source > /dev/null
    run_gt_or_equal "4.0.5" "7.1.1"
    assert_equals "[]" "$output"
}

function test_gt_or_equal_ignores_missing_components()
{
    make_fake_ff_source > /dev/null
    # 7 is treated as 7.0.0, so it is lower than 7.1
    run_gt_or_equal "7" "7.1"
    assert_equals "[]" "$output"

    run_gt_or_equal "7.1" "7"
    assert_equals "[1]" "$output"
}

function test_gt_or_equal_handles_non_numeric_and_empty_parts()
{
    make_fake_ff_source > /dev/null
    # non numeric parts count as 0
    run_gt_or_equal "7.a.1" "7.0.1"
    assert_equals "[1]" "$output"

    run_gt_or_equal "7..1" "7.0.1"
    assert_equals "[1]" "$output"

    # leading zeros must not be read as octal
    run_gt_or_equal "7.08" "7.9"
    assert_equals "[]" "$output"
}

function test_no_third_party_lib_found()
{
    stub_pkg_config
    run_auto_detect "7.1.1"
    assert_success "$status"
    assert_not_contains "$output" "--enable-libopus"
    assert_not_contains "$output" "--enable-libdav1d"
    assert_not_contains "$output" "--enable-libbluray"
    # webp is explicitly disabled when missing on apple
    assert_contains "$output" "--disable-libwebp"
}

function test_detected_libs_are_enabled()
{
    stub_pkg_config openssl opus dav1d libsmb2 libbluray dvdread dvdnav uavs3d libxml-2.0 libwebp
    run_auto_detect "7.1.1"
    assert_success "$status"
    assert_contains "$output" "--enable-openssl"
    assert_contains "$output" "--enable-libopus --enable-decoder=opus"
    assert_contains "$output" "--enable-libdav1d"
    assert_contains "$output" "--enable-libsmb2 --enable-protocol=libsmb2"
    assert_contains "$output" "--enable-libbluray --enable-protocol=bluray"
    assert_contains "$output" "--enable-libdvdread --enable-libdvdnav --enable-demuxer=dvdvideo --enable-gpl"
    assert_contains "$output" "--enable-libuavs3d"
    assert_contains "$output" "--enable-libxml2"
    assert_contains "$output" "--enable-libwebp"
}

function test_smb2_and_av3a_need_ffmpeg_6()
{
    stub_pkg_config libsmb2
    run_auto_detect "5.1.6"
    assert_not_contains "$output" "--enable-libsmb2"
    assert_not_contains "$output" "--enable-parser=av3a"

    run_auto_detect "6.1.1"
    assert_contains "$output" "--enable-libsmb2"
    assert_contains "$output" "--enable-parser=av3a --enable-demuxer=av3a"
}

function test_dav1d_needs_ffmpeg_4_2()
{
    stub_pkg_config dav1d
    run_auto_detect "4.0.5"
    assert_not_contains "$output" "--enable-libdav1d"

    run_auto_detect "4.2"
    assert_contains "$output" "--enable-libdav1d --enable-decoder=libdav1d"
}

function test_uavs3d_needs_ffmpeg_5()
{
    stub_pkg_config uavs3d
    run_auto_detect "4.0.5"
    assert_not_contains "$output" "--enable-libuavs3d"

    run_auto_detect "5.1.6"
    assert_contains "$output" "--enable-libuavs3d --enable-decoder=libuavs3d"
}

function test_hardware_av1_decoder_needs_ffmpeg_7_1_1()
{
    stub_pkg_config
    run_auto_detect "6.1.1"
    assert_not_contains "$output" "--enable-decoder=av1"

    run_auto_detect "7.1.1"
    assert_contains "$output" "--enable-decoder=av1"
}

function test_old_ffmpeg_falls_back_to_configure_help_for_dvdread()
{
    stub_pkg_config dvdread
    run_auto_detect "6.1.1"
    # before 7.1.1 dvdread is only a protocol and is gated on configure --help
    assert_contains "$output" "--enable-libdvdread --enable-protocol=dvd"
    assert_not_contains "$output" "--enable-demuxer=dvdvideo"
}

function test_postproc_is_disabled_after_8_1_1()
{
    stub_pkg_config
    run_auto_detect "8.1.1"
    assert_not_contains "$output" "--disable-postproc"

    run_auto_detect "8.2"
    assert_contains "$output" "--disable-postproc"
}

function test_webp_is_skipped_on_android()
{
    stub_pkg_config libwebp
    run_auto_detect "7.1.1" MR_PLAT=android
    assert_not_contains "$output" "libwebp"
}

function test_common_flags_are_always_present()
{
    stub_pkg_config
    run_auto_detect "7.1.1"
    assert_contains "$output" "--prefix=${TEST_TMP_DIR}/prefix"
    assert_contains "$output" "--enable-static"
    assert_contains "$output" "--disable-shared"
    assert_contains "$output" "--enable-pic"
    assert_contains "$output" "--pkg-config-flags=--static"
    assert_contains "$output" "--arch=arm64"
    assert_contains "$output" "--target-os=darwin"
}

function test_release_and_debug_flags()
{
    stub_pkg_config
    run_auto_detect "7.1.1"
    assert_contains "$output" "--enable-optimizations"
    assert_contains "$output" "--disable-debug"
    assert_contains "$output" "--enable-small"

    run_auto_detect "7.1.1" MR_DEBUG=debug
    assert_contains "$output" "--disable-optimizations"
    assert_contains "$output" "--enable-debug"
    assert_contains "$output" "--disable-small"
}

function test_apple_platform_flags()
{
    stub_pkg_config
    run_auto_detect "7.1.1" MR_PLAT=ios
    assert_contains "$output" "--enable-videotoolbox"
    assert_contains "$output" "--enable-hwaccel=*_videotoolbox"
    assert_contains "$output" "--enable-iconv"
    assert_contains "$output" "--enable-neon"
}

function test_android_platform_flags()
{
    stub_pkg_config
    run_auto_detect "7.1.1" MR_PLAT=android MR_ARCH=arm64
    assert_contains "$output" "--enable-jni"
    assert_contains "$output" "--enable-mediacodec"
    assert_contains "$output" "--enable-decoder=h264_mediacodec --enable-hwaccel=h264_mediacodec"
    assert_contains "$output" "--disable-iconv"
    assert_contains "$output" "--disable-bzlib"
    assert_contains "$output" "--enable-neon"
    assert_not_contains "$output" "--enable-videotoolbox"
}

function test_android_x86_disables_asm()
{
    stub_pkg_config
    run_auto_detect "7.1.1" MR_PLAT=android MR_ARCH=x86_64
    assert_contains "$output" "--disable-neon"
    assert_contains "$output" "--disable-asm --disable-inline-asm"
}

function test_cross_compile_flags_are_added()
{
    stub_pkg_config
    run_auto_detect "7.1.1" MR_FORCE_CROSS=true
    assert_contains "$output" "--enable-cross-compile"
    assert_contains "$output" "--sysroot=${TEST_TMP_DIR}/sysroot"
}
