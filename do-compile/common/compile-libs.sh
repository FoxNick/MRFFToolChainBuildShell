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
# 所有平台共用的编译入口，被 do-compile/{android,apple}/main.sh 导入。
# 调用者需要保证工作目录是自己所在的平台目录。

source "$MR_SHELL_TOOLS_DIR/lib-config-loop.sh"

function do_compile_a_lib()
{
    local lib_config="$1"

    echo "===[$MR_CMD $lib_config]===================="
    source_lib_config "$lib_config"

    echo "LIB_NAME        : [$LIB_NAME]"
    echo "GIT_COMMIT      : [$GIT_COMMIT]"
    echo "LIPO_LIBS       : [$LIPO_LIBS]"
    echo "GIT_UPSTREAM    : [$GIT_UPSTREAM]"

    if ./any.sh; then
        echo "🎉  Congrats"
        echo "🚀  ${LIB_NAME} ${GIT_COMMIT} successfully $MR_CMD."
        echo
    fi
    echo "===================================="
}

parse_lib_options "$@"
echo "LIB_CONFIG_PATH:$LIB_CONFIG_PATH"
foreach_lib_config do_compile_a_lib
