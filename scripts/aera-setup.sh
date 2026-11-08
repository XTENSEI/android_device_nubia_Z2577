#!/bin/bash
#
# Set up an AERA 16 source tree with this device tree in one command.
#   scripts/aera-setup.sh [dest]
#
# Env: AERA_BRANCH (aera-16.0), DEVICE_BRANCH (aera-16), JOBS (nproc)
#
set -euo pipefail

AERA_BRANCH="${AERA_BRANCH:-aera-16.0}"
DEVICE_BRANCH="${DEVICE_BRANCH:-aera-16}"
DEVICE_URL="${DEVICE_URL:-https://github.com/XTENSEI/android_device_nubia_Z2577}"
JOBS="${JOBS:-$(nproc)}"
DEST="${1:-$HOME/android/AERA_16.0}"

mkdir -p "$DEST"
cd "$DEST"

if [ ! -d .repo ]; then
    repo init -u https://github.com/AERA-Recovery/android_manifest.git -b "$AERA_BRANCH"
fi

# Do not apply AERA's remove-minimal.xml. On aera-16.0 every entry names a
# project the twrp-default layer already drops, and repo aborts with
# "remove-project element specifies non-existent project".
repo sync -c --force-sync --no-clone-bundle --no-tags -j"$JOBS"

if [ -d device/nubia/Z2577/.git ]; then
    git -C device/nubia/Z2577 pull --ff-only
else
    git clone -b "$DEVICE_BRANCH" "$DEVICE_URL" device/nubia/Z2577
fi

cat <<EOF

Ready in $DEST

  cd $DEST
  export AERA_BUILD_DEVICE=Z2577
  . build/envsetup.sh
  lunch twrp_Z2577-bp2a-eng
  mka adbd vendorbootimage

recoveryimage is the wrong target here: this board sets TARGET_NO_RECOVERY
and packs recovery inside vendor_boot.
EOF
