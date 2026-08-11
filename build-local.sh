#!/usr/bin/env bash
# Local TWRP build for Z2577 (no sudo). Usage: ./build-local.sh [--clean]
# Output: workspace/out/target/product/Z2577/vendor_boot.img
set -euo pipefail

MANIFEST_URL="https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp"
MANIFEST_BRANCH="twrp-12.1"
DEVICE_TREE_URL="https://github.com/XTENSEI/android_device_nubia_Z2577"
DEVICE_TREE_BRANCH="twrp-12.1"
DEVICE_PATH="device/nubia/Z2577"
DEVICE_NAME="Z2577"
BUILD_TARGET="vendor_boot"
JOBS="${JOBS:-$(nproc --all)}"

[[ "${1:-}" == "--clean" ]] && rm -rf workspace
mkdir -p workspace && cd workspace

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

[[ ! -d .repo ]] && repo init --depth=1 -u "$MANIFEST_URL" -b "$MANIFEST_BRANCH"
[[ ! -d .repo/projects ]] && repo sync -j"$JOBS" --force-sync

mkdir -p "$(dirname "$DEVICE_PATH")"
if [[ ! -d "$DEVICE_PATH" ]]; then
    git clone --depth=1 -b "$DEVICE_TREE_BRANCH" "$DEVICE_TREE_URL" "$DEVICE_PATH"
else
    git -C "$DEVICE_PATH" fetch origin "$DEVICE_TREE_BRANCH" && git -C "$DEVICE_PATH" checkout FETCH_HEAD
fi

cp -f "$DEVICE_PATH/patches/bootable/recovery/minuitwrp/graphics_drm.cpp" bootable/recovery/minuitwrp/graphics_drm.cpp
cp -f "$DEVICE_PATH/patches/bootable/recovery/partitionmanager.cpp" bootable/recovery/partitionmanager.cpp

if command -v ccache >/dev/null 2>&1; then
    export CCACHE_DIR="$PWD/.ccache" USE_CCACHE=1 CCACHE_EXEC="$(command -v ccache)"
    ccache -M 50G >/dev/null 2>&1 || true
fi

source build/envsetup.sh
export ALLOW_MISSING_DEPENDENCIES=true
lunch "twrp_${DEVICE_NAME}-eng"
make "$(tr -d _ <<< "$BUILD_TARGET")image" -j"$JOBS"
