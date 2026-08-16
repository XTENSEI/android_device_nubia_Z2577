#!/usr/bin/env bash
# Local OrangeFox 14.1 build for Z2577 (no sudo). Usage: ./build-local.sh [--clean]
# Output: workspace/out/target/product/Z2577/vendor_boot.img
set -eo pipefail # no -u: AOSP envsetup.sh reads unset vars (TOP, ZSH_VERSION)

FOX_BRANCH="14.1"
DEVICE_TREE_URL="https://github.com/XTENSEI/android_device_nubia_Z2577"
DEVICE_TREE_BRANCH="fox_14.1"
DEVICE_PATH="device/nubia/Z2577"
DEVICE_NAME="Z2577"
BUILD_TARGET="vendor_boot"
JOBS="${JOBS:-$(nproc --all)}"

[[ "${1:-}" == "--clean" ]] && rm -rf workspace
mkdir -p workspace && cd workspace
WORKSPACE="$PWD"

if ! command -v repo >/dev/null 2>&1; then
    mkdir -p "$HOME/bin"
    curl -s https://storage.googleapis.com/git-repo-downloads/repo > "$HOME/bin/repo"
    chmod a+x "$HOME/bin/repo"
    export PATH="$HOME/bin:$PATH"
fi

if ! java -version 2>&1 | grep -q 'version "11'; then
    if [[ ! -x "$HOME/jdk11/bin/java" ]]; then
        mkdir -p "$HOME/jdk11"
        curl -sL "https://api.adoptium.net/v3/binary/latest/11/ga/linux/x64/jdk/hotspot/normal/eclipse" -o /tmp/jdk11.tar.gz
        tar -xzf /tmp/jdk11.tar.gz -C "$HOME/jdk11" --strip-components=1
    fi
    export JAVA_HOME="$HOME/jdk11" PATH="$HOME/jdk11/bin:$PATH"
fi

# OrangeFox source setup (repo init + sync + patches), via the official sync script
if [[ ! -d .repo ]]; then
    rm -rf /tmp/ofox-sync && git clone https://gitlab.com/OrangeFox/sync /tmp/ofox-sync
    cd /tmp/ofox-sync
    ./orangefox_sync.sh -b "$FOX_BRANCH" -p "$WORKSPACE"
    cd "$WORKSPACE"
fi

mkdir -p "$(dirname "$DEVICE_PATH")"
if [[ ! -d "$DEVICE_PATH" ]]; then
    git clone --depth=1 -b "$DEVICE_TREE_BRANCH" "$DEVICE_TREE_URL" "$DEVICE_PATH"
else
    git -C "$DEVICE_PATH" fetch origin "$DEVICE_TREE_BRANCH" && git -C "$DEVICE_PATH" checkout FETCH_HEAD
fi

if command -v ccache >/dev/null 2>&1; then
    export CCACHE_DIR="$WORKSPACE/.ccache" USE_CCACHE=1 CCACHE_EXEC="$(command -v ccache)"
    ccache -M 50G >/dev/null 2>&1 || true
fi

source build/envsetup.sh
export ALLOW_MISSING_DEPENDENCIES=true
export FOX_BUILD_DEVICE="$DEVICE_NAME"
lunch "twrp_${DEVICE_NAME}-trunk_staging-eng"
make "$(tr -d _ <<< "$BUILD_TARGET")image" -j"$JOBS"
