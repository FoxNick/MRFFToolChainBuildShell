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
#

set -e

# 当前脚本所在目录
THIS_DIR=$(DIRNAME=$(dirname "$0"); cd "$DIRNAME"; pwd)
cd "$THIS_DIR"

function parse_lib_config() {
    
    local t=$(echo "PRE_COMPILE_TAG_$MR_PLAT" | tr '[:lower:]' '[:upper:]')
    local vt=$(eval echo "\$$t")
    
    if test -z $vt ;then
        echo "$t can't be nil"
        exit
    fi
    
    export TAG=$vt
    # opus-1.3.1-231124151836
    # yuv-stable-eb6e7bb-250225223408
    LIB_NAME=$(echo $TAG | awk -F - '{print $1}')
    local prefix="${LIB_NAME}-"
    local suffix=$(echo $TAG | awk -F - '{printf "-%s", $NF}')
    # 去掉前缀
    local temp=${TAG#$prefix}
    # 去掉后缀
    VER=${temp%$suffix}
    
    export VER
    export LIB_NAME
}

source "$MR_SHELL_TOOLS_DIR/lib-config-loop.sh"

function do_install_a_lib()
{
    local lib_config="$1"

    echo "===[install $lib_config]===================="
    source_lib_config "$lib_config"
    parse_lib_config
    if [[ $FORCE_XCFRAMEWORK ]];then
        ./install-pre-xcf.sh
    else
        ./install-pre-lib.sh
    fi
    echo "===================================="
}

parse_lib_options "$@"

if [[ -n "$CORRECT_PC" ]];then
    echo "correct pc file : [$CORRECT_PC]"
    ./correct-pc.sh "$CORRECT_PC"
else
    foreach_lib_config do_install_a_lib
fi
