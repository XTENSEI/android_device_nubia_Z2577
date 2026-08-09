# TWRP device tree for Nubia V80 Max (Z2577)

Team Win Recovery Project device tree for the Nubia V80 Max (Z2577).

| | |
|---|---|
| Device | Nubia V80 Max |
| SoC | Unisoc T7250 (ums9230_6h10), octa-core |
| RAM/Storage | 8/12 GB · 128/256 GB |
| Screen | 720×1640, `sprd_backlight` |
| Android | 16 (BP2A.250605.031.A3) |
| Bootloader | unlocked, vendor_boot recovery |
| Branch | `twrp-12.1` (minimal-manifest-twrp AOSP, TeamWin android-12.1) |

## Status

- [x] Skeleton, ramdisk files, prebuilts (dtb, bootconfig, vendor modules)
- [x] Trusty FBE decryption stack (keymint/gatekeeper HALs from stock images)
- [x] fastbootd / update_engine_sideload support (AIDL boot HALs)
- [x] CI build workflow (mirrors Massatriof16/Action-Recovery-Builder)
- [ ] First boot validation on device

> **Note on decryption**: the shipped keymint HALs are Android-13+ (keymint
> AIDL V2) interfaces. The twrp-12.1 manifest builds at API 32, where TWRP's
> vold still uses keymaster HIDL — so FBE decrypt is best-effort on the
> 12.1 manifest. Building with `MANIFEST_BRANCH=14.1` provides the
> keymint-V2 NDK libs for the full decrypt path. Recovery boots either way.

## Build

Dispatch the **Recovery Build** workflow from the Actions tab
(`workflow_dispatch`), or build manually:

```bash
repo init --depth=1 -u https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp.git -b twrp-12.1
repo sync -j$(nproc) --force-sync
git clone https://github.com/XTENSEI/android_device_nubia_Z2577 -b twrp-12.1 device/nubia/Z2577
source build/envsetup.sh
export ALLOW_MISSING_DEPENDENCIES=true
lunch twrp_Z2577-eng
make vendorbootimage -j$(nproc)
```

The recovery ramdisk lives in `vendor_boot.img`.

## Install

```bash
adb reboot bootloader
fastboot flash vendor_boot vendor_boot.img
fastboot reboot
```

To boot without flashing:

```bash
fastboot boot vendor_boot.img
```

## Credits

- [TeamWin Recovery Project](https://github.com/TeamWin)
- [Massatriof16](https://github.com/Massatriof16) — reference Unisoc trees
  (kl4, P671L) and the Action-Recovery-Builder workflow
- [MIO-KITCHEN](https://github.com/AKUBI-LT0/MIO-KITCHEN) — stock image
  extraction
