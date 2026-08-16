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

THIS_DIR=$(DIRNAME=$(dirname "$0"); cd "$DIRNAME"; pwd)
cd "$THIS_DIR"

CFG_FLAGS="--with-pic --disable-shared --disable-dependency-tracking --disable-silent-rules --disable-bdjava-jar --without-freetype --without-fontconfig --disable-doxygen-doc --disable-examples"

if [[ "$MR_DEBUG" == "debug" ]];then
    CFG_FLAGS="$CFG_FLAGS use_examples=yes --disable-optimizations"
fi

export MR_AUTOTOOLS_VERBOSE=1

"$MR_COMMON_COMPILE_DIR/autotools-compatible.sh" "$CFG_FLAGS" bootstrap
