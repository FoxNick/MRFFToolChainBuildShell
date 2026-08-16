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
# 遍历所有待处理的库配置，compile 和 install 共用。

# -lib-config 指定的库配置文件
LIB_CONFIG_PATH=
# -correct-pc 指定的产物目录
CORRECT_PC=

function parse_lib_options() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -lib-config)
                shift
                LIB_CONFIG_PATH="$1"
            ;;
            -correct-pc)
                shift
                CORRECT_PC="$1"
            ;;
            *)
                echo "unknown option: $1"
                sleep 2
            ;;
        esac
        shift
    done
}

# 检查库配置文件是否存在，然后导入它
function source_lib_config() {
    local lib_config="$1"
    lib_config=$(make_absolute_path "$lib_config")
    [[ ! -f "$lib_config" ]] && (echo "❌$lib_config config not exist,$MR_ACTION will stop."; exit 1;)
    source "$lib_config"
}

# 对 MR_VENDOR_LIBS 里的每个库以及 -lib-config 指定的库执行 handler
function foreach_lib_config() {
    local handler="$1"

    for lib in $MR_VENDOR_LIBS
    do
        "$handler" "configs/libs/${lib}.sh"
    done

    if [[ -n "$LIB_CONFIG_PATH" ]];then
        echo
        echo "$MR_ACTION specific lib config : [$LIB_CONFIG_PATH]"
        "$handler" "$LIB_CONFIG_PATH"
    fi
}
