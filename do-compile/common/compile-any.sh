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
# build/clean/lipo 的通用流程，被 do-compile/{android,apple}/any.sh 导入。
# 导入前平台的 any.sh 需要:
# 1、定义 do_lipo_all 函数;
# 2、把 MR_BUILD_ENV_SHELL 设置为自己的构建环境脚本名。

# 平台目录，方便 do-compile/common 里的脚本调用平台脚本
export MR_PLAT_COMPILE_DIR="$THIS_DIR"
# common 目录，方便 common 里的脚本互相调用
export MR_COMMON_COMPILE_DIR=$(cd "$THIS_DIR/../common"; pwd)

# 优先使用平台私有的编译脚本，没有的话使用 common 目录里的通用脚本
function lib_compile_shell() {
    if [[ -f "$MR_PLAT_COMPILE_DIR/$LIB_NAME.sh" ]];then
        echo "$MR_PLAT_COMPILE_DIR/$LIB_NAME.sh"
    else
        echo "$MR_COMMON_COMPILE_DIR/$LIB_NAME.sh"
    fi
}

function do_compile() {
    if [ ! -d $MR_BUILD_SOURCE ]; then
        echo ""
        echo "!! ERROR"
        echo "!! Can not find lib source: $MR_BUILD_SOURCE"
        echo "!! Run init-any.sh ${LIB_NAME} first"
        echo ""
        exit 1
    fi

    mkdir -p "$MR_BUILD_PREFIX"
    "$(lib_compile_shell)"
}

function resolve_dep() {
    echo "[*] check depends bins: ${LIB_DEPENDS_BIN}"
    for b in ${LIB_DEPENDS_BIN}; do
        install_depends "$b"
    done
    echo "===================="
}

function do_clean() {

    if [[ -d $MR_BUILD_SOURCE ]];then
        echo "git clean:$MR_BUILD_SOURCE"
        cd $MR_BUILD_SOURCE
        git clean -xdf >/dev/null
        cd - >/dev/null
    fi

    if [[ -d $MR_BUILD_PREFIX ]];then
        echo "rm:$MR_BUILD_PREFIX"
        rm -rf $MR_BUILD_PREFIX >/dev/null
    fi
}

function main() {

    local cmd="$MR_CMD"

    case "$cmd" in
        'clean')
            for arch in $MR_ACTIVE_ARCHS; do
                export _MR_ARCH=$arch
                source $MR_SHELL_TOOLS_DIR/$MR_BUILD_ENV_SHELL
                echo "---"
                do_clean $arch
            done

            rm -rf $MR_UNI_PROD_DIR/$LIB_NAME
        ;;
        'lipo')
            do_lipo_all "$MR_ACTIVE_ARCHS"
        ;;
        'build')
            resolve_dep
            for arch in $MR_ACTIVE_ARCHS; do
                export _MR_ARCH=$arch
                source $MR_SHELL_TOOLS_DIR/$MR_BUILD_ENV_SHELL
                do_compile
                echo
            done
            do_lipo_all "$MR_ACTIVE_ARCHS"
        ;;
        'rebuild')
            echo
            echo '---clean for rebuild-----------------'
            MR_CMD='clean'
            main #>/dev/null
            echo
            echo '---build for rebuild-----------------'
            MR_CMD='build'
            main
        ;;
        *)
            echo "Unknown cmd:[$cmd]"
            echo "Maybe you want use rebuild|build|lipo|clean|"
            exit 1
        ;;
    esac
}

main
