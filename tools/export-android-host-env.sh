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

# https://github.com/Javernaut/ffmpeg-android-maker

function install_depends() {
    local name="$1"
    if command -v "$name" &> /dev/null; then
        echo "[✅] ${name}: $(eval $name --version | head -n 1)"
        return 0
    fi

    if [[ "$name" == "rustup" || "$name" == "cargo" ]]; then
        echo "will install rustup-init."
        brew install rustup-init
        rustup-init -y
        return 0
    fi

    echo "will use brew install ${name}."
    if ! brew install "$name"; then
        echo "❌ can't install ${name}, please install it by hand." >&2
        return 1
    fi

    # brew may succeed without putting the bin in PATH, e.g. keg-only formulas.
    if ! command -v "$name" &> /dev/null; then
        echo "❌ ${name} is still not in PATH after brew install." >&2
        return 1
    fi
    echo "[✅] ${name}: $(eval $name --version | head -n 1)"
}

# brew isn't available on the other hosts, so only check the depends there.
function check_depends() {
    local name="$1"
    if ! command -v "$name" &> /dev/null; then
        echo "❌ ${name} not found in PATH, please install it firstly." >&2
        return 1
    fi
    echo "[✅] ${name}: $(eval $name --version | head -n 1)"
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

export -f my_sed_i

case "$OSTYPE" in
  darwin*)  HOST_TAG="darwin-x86_64"; export -f install_depends ;;
  linux*)   HOST_TAG="linux-x86_64"; install_depends() { check_depends "$@"; }; export -f check_depends install_depends ;;
  msys)
    install_depends() { check_depends "$@"; }
    export -f check_depends install_depends
    case "$(uname -m)" in
      x86_64) HOST_TAG="windows-x86_64" ;;
      i686)   HOST_TAG="windows" ;;
      *)
        echo "unsupported host arch: [$(uname -m)]" >&2
        exit 1
      ;;
    esac
  ;;
  *)
    echo "unsupported host os: [$OSTYPE]" >&2
    exit 1
  ;;
esac

if [[ $OSTYPE == "darwin"* ]]; then
  HOST_NPROC=$(sysctl -n hw.physicalcpu)
else
  HOST_NPROC=$(nproc)
fi

export MR_FORCE_CROSS=true
# The variable is used as a path segment of the toolchain path
export MR_HOST_TAG="$HOST_TAG"
# Number of physical cores in the system to facilitate parallel assembling
export MR_HOST_NPROC="$HOST_NPROC"
# for ffmpeg --target-os
export MR_TAGET_OS="android"
# 
export MR_PLAT="android"
if [[ -n "$ANDROID_NDK_HOME" ]];then
    export MR_ANDROID_NDK_HOME="$ANDROID_NDK_HOME"
elif [[ -n "$ANDROID_NDK_ROOT" ]]; then
    export MR_ANDROID_NDK_HOME="$ANDROID_NDK_ROOT"
elif [[ -n "$ANDROID_NDK" ]]; then
    export MR_ANDROID_NDK_HOME="$ANDROID_NDK"
else
    echo "You must define ANDROID_NDK_HOME or ANDROID_NDK_ROOT or ANDROID_NDK before starting."
    echo "They must point to your NDK directories.\n"
    exit 1
fi

if [[ ! -d "$MR_ANDROID_NDK_HOME" ]]; then
    echo "the ndk dir doesn't exist: $MR_ANDROID_NDK_HOME" >&2
    exit 1
fi

MR_NDK_REL=$(grep -m 1 -o '^## r[0-9]*.*' "$MR_ANDROID_NDK_HOME/CHANGELOG.md" | awk '{print $2}') || true
if [[ -z "$MR_NDK_REL" ]]; then
    echo "can't read the ndk release from $MR_ANDROID_NDK_HOME/CHANGELOG.md" >&2
    exit 1
fi
export MR_NDK_REL

export MR_TOOLCHAIN_ROOT="$MR_ANDROID_NDK_HOME/toolchains/llvm/prebuilt/${MR_HOST_TAG}"
export PATH="${MR_TOOLCHAIN_ROOT}/bin:$PATH"
export MR_SYS_ROOT="${MR_TOOLCHAIN_ROOT}/sysroot"

# Using Make from the Android SDK
export MR_MAKE_EXECUTABLE=${MR_ANDROID_NDK_HOME}/prebuilt/${MR_HOST_TAG}/bin/make
# Init Android plat env
export MR_DEFAULT_ARCHS="armv7a arm64 x86 x86_64"