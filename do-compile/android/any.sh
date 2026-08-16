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

# Creating a multiplatform binary framework bundle
# https://developer.apple.com/documentation/xcode/creating-a-multi-platform-binary-framework-bundle

set -e

# 当前脚本所在目录
THIS_DIR=$(DIRNAME=$(dirname "$0"); cd "$DIRNAME"; pwd)
cd "$THIS_DIR"

do_lipo_lib() {
    local lib=$1
    local archs="$2"
    
    for arch in $archs; do
        local lib_dir="$MR_PRODUCT_ROOT/$LIB_NAME-$arch"
        
        if [ -d "$lib_dir" ]; then
            my_sed_i "s|-lpthread|-pthread|" "$lib_dir"/lib/pkgconfig/*.pc
            # Copy the directory
            mkdir -p "$MR_UNI_PROD_DIR/$LIB_NAME"
            cp -Rf "$lib_dir" "$MR_UNI_PROD_DIR/$LIB_NAME"
        else
            echo "can't find the $arch arch $lib"
        fi
    done
}

do_lipo_all() {
    echo '----------------------'
    echo '[*] lipo'
    
    local archs="$1"
    rm -rf $MR_UNI_PROD_DIR/$LIB_NAME
    echo "lipo archs: $archs"
    
    do_lipo_lib "$lib" "$archs"
    
    echo '----------------------'
    echo 
}

MR_BUILD_ENV_SHELL="export-android-build-env.sh"
source ../common/compile-any.sh
