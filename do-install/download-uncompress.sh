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

THIS_DIR=$(DIRNAME=$(dirname "$0"); cd "$DIRNAME"; pwd)
cd "$THIS_DIR"

echo "=== [$0] check env begin==="
env_assert "MR_WORKSPACE"
env_assert "MR_DOWNLOAD_URL"
env_assert "MR_DOWNLOAD_ONAME"
env_assert "MR_UNCOMPRESS_DIR"
echo "===check env end==="

function assert_secure_url() {
    local url="$1"
    case "$url" in
        https://*|file://*)
        ;;
        *)
            echo "❌ refuse to download from an unencrypted url: $url"
            echo "use a https url, MR_DOWNLOAD_BASEURL must start with https://"
            exit 1
        ;;
    esac
}

function download() {
    local dst="$1"
    echo "---[download]-----------------"
    echo "$MR_DOWNLOAD_URL"
    
    assert_secure_url "$MR_DOWNLOAD_URL"
    
    mkdir -p $(dirname "$dst")
    local tname="${dst}.tmp"
    if curl -fL --proto '=https,file' --proto-redir '=https' --tlsv1.2 --retry 3 --retry-delay 5 --retry-max-time 30 "$MR_DOWNLOAD_URL" -o "$tname";then
        mv "$tname" "${dst}"
    else
        rm -f "$tname"
        exit 1
    fi
}

function extract(){
    local dst="$1"
    if [[ -f "$dst" ]];then
        mkdir -p "$MR_UNCOMPRESS_DIR"
        unzip -oq "$dst" -d "$MR_UNCOMPRESS_DIR"
        echo "extract zip file"
    else
        echo "you need download ${MR_DOWNLOAD_ONAME} firstly."
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
