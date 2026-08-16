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
# 使用 autotools（configure && make）编译的库的通用编译脚本，
# 和 meson-compatible.sh、cmake-compatible.sh 是一个套路。
#
# $1: 库自己的 configure 参数
# $2: 生成 configure 的方式，autoreconf(默认)|bootstrap|autogen.sh
# $3: apple 平台的 host，默认 $MR_ARCH-apple-darwin
#
# 可选的环境变量:
# MR_AUTOTOOLS_DARWIN_PREP : 生成 configure 之前在 macOS 上执行 libtoolize
# MR_AUTOTOOLS_VERBOSE     : 不隐藏编译日志

set -e

THIS_DIR=$(DIRNAME=$(dirname "$0"); cd "$DIRNAME"; pwd)
source "$THIS_DIR/autotools.sh"

CFG_FLAGS="--prefix=$MR_BUILD_PREFIX $1"
CFLAGS="$(mr_autotools_cflags)"
CFG_FLAGS="$CFG_FLAGS $(mr_autotools_cross_flags "$3")"

mr_autotools_generate_configure "$2"
mr_autotools_configure "$CFG_FLAGS" "$CFLAGS"

if [[ "$MR_AUTOTOOLS_VERBOSE" ]];then
    mr_autotools_make_install verbose
else
    mr_autotools_make_install
fi
