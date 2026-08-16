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

set -e

echo "--check denpendencies--------------------"
check_pkg_lib 'freetype2'
check_pkg_lib 'fribidi'
check_pkg_lib 'harfbuzz'
check_pkg_lib 'libunibreak'

CFG_FLAGS="-Dtest=disabled -Dprofile=disabled -Dasm=disabled -Dlibunibreak=enabled"

if [[ "$MR_PLAT" == 'android' ]];then
    # android 没有 coretext，字体查找依赖 fontconfig
    check_pkg_lib 'fontconfig'
    CFG_FLAGS="$CFG_FLAGS -Dfontconfig=enabled -Dcoretext=disabled"
else
    CFG_FLAGS="$CFG_FLAGS -Dfontconfig=disabled -Dcoretext=enabled"
fi
echo "----------------------"

"$MR_PLAT_COMPILE_DIR/meson-compatible.sh" "$CFG_FLAGS"
