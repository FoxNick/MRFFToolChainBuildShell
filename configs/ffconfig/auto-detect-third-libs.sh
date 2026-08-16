#! /usr/bin/env bash
#
# Copyright (C) 2021 Matt Reach<qianlongxu@gmail.com>

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# https://ffmpeg.org/doxygen/4.1/md_LICENSE.html
# https://www.openssl.org/source/license.html

# pkg-config --variable pc_path pkg-config
# pkg-config --libs dav1d
# pkg-config --cflags --libs libbluray


THIRD_CFG_FLAGS=

# echo "----------------------"

# pkg-config --libs x264 --silence-errors >/dev/null && enable_x264=1

# if [[ $enable_x264 ]];then
#     echo "[✅] --enable-libx264 : $(pkg-config --modversion x264)"
#     THIRD_CFG_FLAGS="$THIRD_CFG_FLAGS --enable-gpl --enable-libx264"
# else
#     echo "[❌] --disable-libx264"
# fi

# echo "----------------------"

# pkg-config --libs fdk-aac --silence-errors >/dev/null && enable_aac=1

# if [[ $enable_aac ]];then
#     echo "[✅] --enable-libfdk-aac : $(pkg-config --modversion fdk-aac)"
#     THIRD_CFG_FLAGS="$THIRD_CFG_FLAGS --enable-nonfree --enable-libfdk-aac"
# else
#     echo "[❌] --disable-libfdk-aac"
# fi

# echo "----------------------"

# pkg-config --libs mp3lame --silence-errors >/dev/null && enable_lame=1

# if [[ $enable_lame ]];then
#     echo "[✅] --enable-libmp3lame : $(pkg-config --modversion mp3lame)"
#     THIRD_CFG_FLAGS="$THIRD_CFG_FLAGS --enable-gpl --enable-libmp3lame"
# else
#     echo "[❌] --disable-libmp3lame"
# fi


# Function to compare two version numbers
# Returns:
#   1 if v1 == v2 or if v1 > v2
#   0 if v1 < v2
gt_or_equal() {
    local v1=$1
    local v2=$2
    local IFS=.
    # 将版本字符串按 "." 分割成数组
    # 例如 "7..1" 会变成 (7 "" 1)
    local v1_parts=($v1) v2_parts=($v2)
    local i

    # 确定两个版本号数组中的最大长度
    local len_v1=${#v1_parts[@]}
    local len_v2=${#v2_parts[@]}
    local max_len=$((len_v1 > len_v2 ? len_v1 : len_v2))

    for ((i=0; i<$max_len; i++)); do
        # 获取版本号的对应部分，如果部分缺失或为空字符串，则默认为 "0"
        local p1_val=${v1_parts[i]:-0}
        local p2_val=${v2_parts[i]:-0}

        # 进一步确保 p1_val 和 p2_val 是纯数字；如果不是，则视为 0
        # 这能处理像 "7.a.1" 这样包含非数字部分的情况
        if ! [[ "$p1_val" =~ ^[0-9]+$ ]]; then
            p1_val=0
        fi
        if ! [[ "$p2_val" =~ ^[0-9]+$ ]]; then
            p2_val=0
        fi

        # 进行数字比较
        # 使用 10# 前缀确保按十进制处理 (例如 "08" 被视为 8 而不是八进制)
        if ((10#$p1_val > 10#$p2_val)); then
            echo 1 # v1 > v2
            return 0
        fi
        if ((10#$p1_val < 10#$p2_val)); then
            echo # v1 < v2
            return 0
        fi
    done

    echo 1 # v1 == v2 (所有部分都相等)
    return 0
}

has_feature() {
    local feature=$1
    $MR_BUILD_SOURCE/configure --help | grep -q -- "$feature" && enable_feature=1 || enable_feature=0
    echo $enable_feature
    return 0
}

# 检测第三方库并追加 FFmpeg 配置参数
# $1 pkg-config 名称；$2 找到时追加的参数；$3 找不到时打印的信息；$4 找不到时追加的参数(可选)
detect_third_lib() {
    local pkg="$1"
    if pkg-config --libs "$pkg" --silence-errors >/dev/null;then
        echo "[✅] $2 : $(pkg-config --modversion $pkg)"
        THIRD_CFG_FLAGS="$THIRD_CFG_FLAGS $2"
    else
        echo "[❌] $3"
        if [[ -n "$4" ]];then
            THIRD_CFG_FLAGS="$THIRD_CFG_FLAGS $4"
        fi
    fi
    echo "----------------------"
    return 0
}

echo "----------------------"
# use pkg-config fix ff4.0--ijk0.8.8--20210426--001 use openssl 1_1_1m occur can't find openssl error.
detect_third_lib openssl "--enable-nonfree --enable-openssl" "--disable-openssl"
detect_third_lib opus "--enable-libopus --enable-decoder=opus" "--disable-libopus --disable-decoder=opus"

# FFmpeg 4.2 支持AV1、AVS2等格式
# dav1d由VideoLAN，VLC和FFmpeg联合开发，项目由AOM联盟赞助，和libaom相比，dav1d性能普遍提升100%，最高提升400%

result=$(gt_or_equal "$GIT_REPO_VERSION" "4.2")
if [[ $result ]]; then
    detect_third_lib dav1d "--enable-libdav1d --enable-decoder=libdav1d" "--disable-libdav1d --disable-decoder=libdav1d"
fi

#从FFmpeg7.1.1开始支持硬解av1，苹果需要M3芯片
result=$(gt_or_equal "$GIT_REPO_VERSION" "7.1.1")
if [[ $result ]]; then
    echo "[✅] --enable hw av1 decoder"
    THIRD_CFG_FLAGS="$THIRD_CFG_FLAGS --enable-decoder=av1"
else
    echo "[❌] --disable hw av1 decoder"
fi

echo "----------------------"

# 从6开始支持的 smb2 协议
result=$(gt_or_equal "$GIT_REPO_VERSION" "6")
if [[ $result ]]; then
    detect_third_lib libsmb2 "--enable-libsmb2 --enable-protocol=libsmb2" "--disable-libsmb2 --disable-protocol=libsmb2"

    echo "[✅] --enable-parser=av3a"
    THIRD_CFG_FLAGS="$THIRD_CFG_FLAGS --enable-parser=av3a --enable-demuxer=av3a"
    echo "----------------------"
fi

detect_third_lib libbluray "--enable-libbluray --enable-protocol=bluray" "--disable-libbluray --disable-protocol=bluray"

#不确定7代之前的版本是否支持dvdvideo
result=$(gt_or_equal "$GIT_REPO_VERSION" "7.1.1")
if [[ $result ]]; then
    pkg-config --libs dvdread --silence-errors >/dev/null && enable_dvdread=1
    pkg-config --libs dvdnav --silence-errors >/dev/null && enable_dvdnav=1
    if [[ $enable_dvdread && $enable_dvdnav ]];then
        echo "[✅] --enable-demuxer=dvdvideo --enable-gpl --enable-libdvdread : $(pkg-config --modversion dvdread)"
        #libdvdread is gpl and --enable-gpl is not specified.
        THIRD_CFG_FLAGS="$THIRD_CFG_FLAGS --enable-libdvdread --enable-libdvdnav --enable-demuxer=dvdvideo --enable-gpl"
    else
        echo "[❌] --disable-dvdvideo"
    fi
    echo "----------------------"
else
    dvd_feature=$(has_feature "libdvdread")
    if [[ $dvd_feature ]]; then
        detect_third_lib dvdread "--enable-libdvdread --enable-protocol=dvd" "--disable-dvd protocol"
    fi
fi

result=$(gt_or_equal "$GIT_REPO_VERSION" "5")
if [[ $result ]]; then
    detect_third_lib uavs3d "--enable-libuavs3d --enable-decoder=libuavs3d" "--disable-libuavs3d --disable-decoder=libuavs3d"
fi

result=$(gt_or_equal "8.1.1" "$GIT_REPO_VERSION")
if [[ ! $result ]]; then
    THIRD_CFG_FLAGS="$THIRD_CFG_FLAGS --disable-postproc"
fi

detect_third_lib libxml-2.0 "--enable-demuxer=dash --enable-libxml2" "--disable-demuxer=dash --disable-libxml2"

result=$(gt_or_equal "$GIT_REPO_VERSION" "7")
if [[ $result && $MR_PLAT != 'android' ]]; then
    detect_third_lib libwebp "--enable-libwebp --enable-demuxer=webp --enable-decoder=libwebp" \
        "--disable-libwebp --disable-decoder=libwebp" \
        "--disable-libwebp --disable-demuxer=webp --disable-decoder=libwebp"
fi

# export PKG_CONFIG_LIBDIR=$PKG_CONFIG_LIBDIR:/opt/homebrew/Cellar/shaderc/2024.0/lib/pkgconfig:/opt/homebrew/Cellar/little-cms2/2.16/lib/pkgconfig
# pkg-config --libs libplacebo --silence-errors >/dev/null && enable_placebo=1

# if [[ $enable_placebo ]];then
#     echo "[✅] --enable-libplacebo"
#     THIRD_CFG_FLAGS="$THIRD_CFG_FLAGS --enable-libplacebo"
# else
#     echo "[❌] --disable-libplacebo"
# fi
# echo "----------------------"

# pkg-config --libs avs3ad --silence-errors >/dev/null && enable_avs3ad=1

# if [[ $enable_avs3ad ]];then
#     echo "[✅] --enable-decoder=av3a"
#     THIRD_CFG_FLAGS="$THIRD_CFG_FLAGS --enable-parser=av3a"
# else
#     echo "[❌] --disable-decoder=av3a"
# fi


# --------------------------------------------------------------
THIRD_CFG_FLAGS="$THIRD_CFG_FLAGS --pkg-config-flags=--static"
THIRD_CFG_FLAGS="$THIRD_CFG_FLAGS --enable-static"
THIRD_CFG_FLAGS="$THIRD_CFG_FLAGS --disable-shared"

THIRD_CFG_FLAGS="--prefix=$MR_BUILD_PREFIX $THIRD_CFG_FLAGS"

# Developer options (useful when working on FFmpeg itself):
# THIRD_CFG_FLAGS="$THIRD_CFG_FLAGS --disable-stripping"

# x86_64, arm64
THIRD_CFG_FLAGS="$THIRD_CFG_FLAGS --enable-pic"

if [[ "$MR_DEBUG" == "debug" ]]; then
    THIRD_CFG_FLAGS="$THIRD_CFG_FLAGS --disable-optimizations"
    THIRD_CFG_FLAGS="$THIRD_CFG_FLAGS --enable-debug"
    THIRD_CFG_FLAGS="$THIRD_CFG_FLAGS --disable-small"
    #C_FLAGS="$C_FLAGS -D DEBUG_BLURAY=1"
else
    THIRD_CFG_FLAGS="$THIRD_CFG_FLAGS --enable-optimizations"
    THIRD_CFG_FLAGS="$THIRD_CFG_FLAGS --disable-debug"
    THIRD_CFG_FLAGS="$THIRD_CFG_FLAGS --enable-small"
fi

##
THIRD_CFG_FLAGS="$THIRD_CFG_FLAGS --arch=$MR_FF_ARCH"
THIRD_CFG_FLAGS="$THIRD_CFG_FLAGS --target-os=$MR_TAGET_OS"

# for cross compile
if [[ $(uname -m) != "$MR_ARCH" || "$MR_FORCE_CROSS" ]]; then
    echo "[*] cross compile, on $(uname -m) compile $MR_PLAT $MR_ARCH."
    THIRD_CFG_FLAGS="$THIRD_CFG_FLAGS --sysroot=$MR_SYS_ROOT"
    THIRD_CFG_FLAGS="$THIRD_CFG_FLAGS --enable-cross-compile"
fi

# for apple paltform

case "$MR_PLAT" in
    ios|macos|tvos)
    # enable asm
    THIRD_CFG_FLAGS="$THIRD_CFG_FLAGS --enable-neon"
    THIRD_CFG_FLAGS="$THIRD_CFG_FLAGS --enable-asm --enable-inline-asm"
    # enable videotoolbox hwaccel
    THIRD_CFG_FLAGS="$THIRD_CFG_FLAGS --enable-videotoolbox"
    THIRD_CFG_FLAGS="$THIRD_CFG_FLAGS --enable-hwaccel=*_videotoolbox"
    # enable iconv
    THIRD_CFG_FLAGS="$THIRD_CFG_FLAGS --enable-iconv"
    ;;
    android)
    # enable mediacodec hwaccel
    THIRD_CFG_FLAGS="$THIRD_CFG_FLAGS --enable-jni"
    THIRD_CFG_FLAGS="$THIRD_CFG_FLAGS --enable-mediacodec"
    THIRD_CFG_FLAGS="$THIRD_CFG_FLAGS --enable-decoder=h264_mediacodec --enable-hwaccel=h264_mediacodec"
    THIRD_CFG_FLAGS="$THIRD_CFG_FLAGS --enable-decoder=h265_mediacodec --enable-hwaccel=h265_mediacodec"
    # disable iconv
    THIRD_CFG_FLAGS="$THIRD_CFG_FLAGS --disable-iconv"
    THIRD_CFG_FLAGS="$THIRD_CFG_FLAGS --disable-bzlib"
    if [[ "$MR_ARCH" == "armv7a" || "$MR_ARCH" == "arm64" ]]; then
        # enable asm
        THIRD_CFG_FLAGS="$THIRD_CFG_FLAGS --enable-neon"
        THIRD_CFG_FLAGS="$THIRD_CFG_FLAGS --enable-asm --enable-inline-asm"
    else
        THIRD_CFG_FLAGS="$THIRD_CFG_FLAGS --disable-neon"
        THIRD_CFG_FLAGS="$THIRD_CFG_FLAGS --disable-asm --disable-inline-asm"
    fi
    ;;
esac