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
# autotools（configure && make）交叉编译的通用逻辑，
# 由使用 configure 的库脚本导入，比如 bluray、dvdread、dvdnav、unibreak。
# https://www.gnu.org/software/automake/manual/html_node/Cross_002dCompilation.html

# 是否需要交叉编译
function mr_is_cross_compile() {
    [[ $(uname -m) != "$MR_ARCH" || "$MR_FORCE_CROSS" ]]
}

# 输出交叉编译需要的 configure 参数，$1 可以指定 apple 平台的 host
function mr_autotools_cross_flags() {
    mr_is_cross_compile || return 0

    echo "[*] cross compile, on $(uname -m) compile $MR_PLAT $MR_ARCH." >&2

    local host
    if [[ "$MR_PLAT" == 'android' ]];then
        # aarch64-linux-android21
        host="$MR_FF_ARCH-linux-android$MR_ANDROID_API"
    else
        # arm64-apple-darwin
        host="${1:-$MR_ARCH-apple-darwin}"
    fi
    echo "--host=$host --with-sysroot=$MR_SYS_ROOT"
}

# 输出编译参数，交叉编译时带上 sysroot
function mr_autotools_cflags() {
    local cflags="$MR_DEFAULT_CFLAGS"
    if mr_is_cross_compile ;then
        cflags="$cflags -isysroot $MR_SYS_ROOT"
    fi
    echo "$cflags"
}

# 生成 configure，$1 取值 autoreconf|bootstrap|autogen.sh
# configure 已经存在时直接复用，autogen.sh 除外，它自带 configure 逻辑
function mr_autotools_generate_configure() {
    local generator="${1:-autoreconf}"

    echo "----------------------"
    echo "[*] configurate $LIB_NAME"
    echo "----------------------"

    cd $MR_BUILD_SOURCE

    if [[ "$generator" == 'autogen.sh' ]];then
        echo "generate configure"
        ./autogen.sh >/dev/null
        return 0
    fi

    if [[ -f 'configure' ]]; then
        echo "reuse configure"
        return 0
    fi

    echo "auto generate configure"
    if [[ "$MR_AUTOTOOLS_DARWIN_PREP" ]];then
        mr_prepare_darwin_autotools
    fi

    case "$generator" in
        'bootstrap')
            ./bootstrap >/dev/null
        ;;
        *)
            autoreconf -if >/dev/null
        ;;
    esac
}

# macOS 上 GNU autotools 由 brew 安装，需要补充 aclocal 的搜索路径
function mr_prepare_darwin_autotools() {
    [[ "$(uname)" == "Darwin" ]] || return 0

    # Homebrew may be in different locations depending on the CPU arch
    if [[ -d "/opt/homebrew/share/aclocal" ]]; then
        export ACLOCAL_PATH="/opt/homebrew/share/aclocal:$ACLOCAL_PATH"
    elif [[ -d "/usr/local/share/aclocal" ]]; then
        export ACLOCAL_PATH="/usr/local/share/aclocal:$ACLOCAL_PATH"
    fi

    if command -v glibtoolize > /dev/null; then
        glibtoolize --force --copy
    elif command -v libtoolize > /dev/null; then
        libtoolize --force --copy
    fi
}

# 导出编译器等工具链变量，configure 和 make 都依赖它们
function mr_autotools_export_toolchain() {
    local cflags="$1"

    export CFLAGS="$cflags"
    export LDFLAGS="$cflags"

    if [[ "$MR_PLAT" == 'android' ]];then
        export CC="$MR_TRIPLE_CC"
        export CXX="$MR_TRIPLE_CXX"
        export AR="$MR_AR"
        export AS="$MR_AS"
        export RANLIB="$MR_RANLIB"
        export STRIP="$MR_STRIP"
    else
        export CC="$MR_CC"
        export CXX="$MR_CXX"
    fi
}

# 执行 configure，$1 是 configure 参数，$2 是编译参数
function mr_autotools_configure() {
    local cfg_flags="$1"
    local cflags="$2"

    echo
    echo "CC: ${MR_TRIPLE_CC:-$MR_CC}"
    echo "CFG_FLAGS: $cfg_flags"
    echo "CFLAGS: $cflags"
    echo

    mr_autotools_export_toolchain "$cflags"
    ./configure $cfg_flags
}

# 编译并安装，$1 为 verbose 时不隐藏编译日志
function mr_autotools_make_install() {
    echo "----------------------"
    echo "[*] compile $LIB_NAME"
    echo "----------------------"

    if [[ "$1" == 'verbose' ]];then
        make install -j$MR_HOST_NPROC
    else
        make install -j$MR_HOST_NPROC >/dev/null
    fi
}
