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

if [[ "$MR_PLAT" != 'macos' ]]; then
    export MR_FORCE_CROSS=true
fi

if [[ "$MR_VENDOR_LIBS" == *"moltenvk"* || "$MR_VENDOR_LIBS" == "moltenvk" ]]; then
    if [[ "$MR_PLAT" == 'macos' ]]; then
        export MR_DEFAULT_ARCHS="arm64"
    elif [[ "$MR_PLAT" == 'ios' || "$MR_PLAT" == 'tvos' ]]; then
        export MR_DEFAULT_ARCHS="arm64 arm64_simulator"
    fi
else
    if [[ "$MR_PLAT" == 'ios' ]]; then
        export MR_DEFAULT_ARCHS="arm64 arm64_simulator x86_64_simulator"
    elif [[ "$MR_PLAT" == 'macos' ]]; then
        export MR_DEFAULT_ARCHS="x86_64 arm64"
    elif [[ "$MR_PLAT" == 'tvos' ]]; then
        export MR_DEFAULT_ARCHS="arm64 arm64_simulator x86_64_simulator"
    fi
fi

# Number of physical cores in the system to facilitate parallel assembling
export MR_HOST_NPROC=$(sysctl -n hw.physicalcpu)
# for ffmpeg --target-os
export MR_TAGET_OS="darwin"
export DEBUG_INFORMATION_FORMAT=dwarf-with-dsym

MR_HOST_ENV_DIR=$(DIRNAME=$(dirname "${BASH_SOURCE[0]}"); cd "${DIRNAME}"; pwd)
source "$MR_HOST_ENV_DIR/common-utils.sh"
