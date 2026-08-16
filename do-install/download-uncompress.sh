#! /usr/bin/env bash
#
# Copyright (C) 2022 Matt Reach<qianlongxu@gmail.com>

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
set -o pipefail

THIS_DIR=$(DIRNAME=$(dirname "$0"); cd "$DIRNAME"; pwd)
cd "$THIS_DIR"

echo "=== [$0] check env begin==="
env_assert "MR_WORKSPACE"
env_assert "MR_DOWNLOAD_URL"
env_assert "MR_DOWNLOAD_ONAME"
env_assert "MR_UNCOMPRESS_DIR"
echo "===check env end==="

function download() {
    local dst="$1"
    echo "---[download]-----------------"
    echo "$MR_DOWNLOAD_URL"
    
    mkdir -p "$(dirname "$dst")"
    local tname="${dst}.tmp"
    if ! curl -fL --retry 3 --retry-delay 5 --retry-max-time 30 "$MR_DOWNLOAD_URL" -o "$tname"; then
        rm -f "$tname"
        echo "❌ download failed: $MR_DOWNLOAD_URL" >&2
        exit 1
    fi

    if [[ ! -s "$tname" ]]; then
        rm -f "$tname"
        echo "❌ downloaded an empty file: $MR_DOWNLOAD_URL" >&2
        exit 1
    fi

    mv "$tname" "${dst}"
}

function extract(){
    local dst="$1"
    if [[ -f "$dst" ]];then
        mkdir -p "$MR_UNCOMPRESS_DIR"
        if ! unzip -oq "$dst" -d "$MR_UNCOMPRESS_DIR"; then
            # a broken archive is cached, drop it so the next run downloads again.
            rm -f "$dst"
            echo "❌ can't extract $dst, it was removed, please retry." >&2
            exit 1
        fi
        echo "extract zip file"
    else
        echo "you need download ${MR_DOWNLOAD_ONAME} firstly." >&2
        exit 1
    fi
}

function install() {
    local dst="${MR_WORKSPACE}/pre/${MR_DOWNLOAD_ONAME}"
    if [[ -f "$dst" ]];then
        echo "$dst already exist,skip download."
    else
        download "$dst"
    fi
    extract "$dst"
}

install
