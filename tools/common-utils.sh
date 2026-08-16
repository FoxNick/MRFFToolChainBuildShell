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
# host independent helpers, shared by every platform's host env shell.

function install_depends() {
    local name="$1"
    local check_name="$name"
    # On macOS, GNU libtool is installed as glibtool to avoid conflict with Apple's libtool
    if [[ "$(uname)" == "Darwin" && "$name" == "libtool" ]]; then
        check_name="glibtool"
    fi

    if command -v "$check_name" &> /dev/null; then
        echo "[✅] ${name}: $(eval $check_name --version | head -n 1)"
        return 0
    else
        if [[ "$name" == "rustup" || "$name" == "cargo" ]]; then
            echo "will install rustup-init."
            brew install rustup-init
            rustup-init -y
            return 0
        else
            echo "will use brew install ${name}."
            brew install "$name"
        fi
    fi
    echo "[✅] ${name}: $(eval $check_name --version | head -n 1)"
}

# 定义跨平台sed函数
my_sed_i() {
    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS系统
        sed -i '' "$@"
    else
        # Linux系统及其他系统
        sed -i "$@"
    fi
}

# pkg-config 能否找到指定的库
function has_pkg_lib()
{
    pkg-config --libs "$1" --silence-errors >/dev/null
}

# 打印 pkg-config 能否找到指定的库，找不到也不会中断编译
function check_pkg_lib()
{
    local lib="$1"
    if has_pkg_lib "$lib"; then
        echo "[✅] $lib : $(pkg-config --modversion $lib)"
    else
        echo "[❌] $lib not found!"
    fi
}

export -f install_depends
export -f my_sed_i
export -f has_pkg_lib
export -f check_pkg_lib
