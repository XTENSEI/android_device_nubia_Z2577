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

## Checks

Status reflects `twrp-12.1` HEAD (ramdisk: TWRP 3.7.1_12). `[?]` = not yet
verified on device.

### Blocking checks

- [x] Correct screen/recovery size (720x1640 @ 320, DRM graphics)
- [x] Working touch, screen
- [?] Backup to internal/microSD
- [?] Restore from internal/microSD
- [x] Reboot to system (BCB cleared via Android-format fstab + vendor fstab)
- [x] ADB (gadget bound for `mtp,adb`; adb out of the box)

### Medium checks

- [x] update.zip sideload (RC=0 verified)
- [x] UI colors (no inversion)
- [x] Screen goes off and on (power → swipe-to-unlock; display does not fully blank)
- [x] F2FS/EXT4 support (metadata f2fs, cache ext4); exFAT/NTFS [?]
- [x] All important partitions listed in mount/backup lists (system, vendor,
      product, odm, dlkms, boot, etc.)
- [?] Backup/restore to/from external storage
- [?] Backup/restore to/from adb
- [ ] Decrypt /data — metadata FBE. keymint TA confirmed alive in recovery
      (trusty v2.1.1, `com.android.trusty.keymaster` answers); decrypt build in
      flight. gatekeeper TA absent, not needed for DE-key unwrap.
- [x] Correct date

### Minor checks

- [ ] MTP export (adb-only gadget for now)
- [?] Reboot to bootloader
- [x] Reboot to recovery
- [?] Poweroff
- [x] Battery level (healthd)
- [x] Temperature (healthd)
- [ ] Encrypted backups (`TW_EXCLUDE_ENCRYPTED_BACKUPS`)
- [?] Input devices via USB OTG (keyboard/mouse/storage)
- [ ] USB mass storage export (no `mass_storage.0` lun)
- [x] Set brightness (`/sys/class/backlight/sprd_backlight`)
- [ ] Vibrate (no `timed_output/vibrator` node)
- [?] Screenshot
- [?] Partition SD card
- [x] Fastbootd (`TW_INCLUDE_FASTBOOTD`)

> **Known limitations:** `/data` decrypt needs the keymint TA reachable at the
> moment TWRP tries — the shipped vold patches keep the boot-HAL and keystore2
> lookups non-blocking so a slow TA fails fast to the UI instead of hanging.
> The trusty keymint/gatekeeper HALs are Android-13+ (keymint AIDL V2); the
> twrp-12.1 manifest builds at API 32 where TWRP's vold uses keymaster HIDL, so
> the stack ships as in-tree prebuilts (kl4/A666LN-proven, byte-identical
> ums9230 blobs).

## Build

Dispatch the **Recovery Build** workflow from the Actions tab
(`workflow_dispatch`), build on a VPS with `./build-local.sh` (no sudo
needed), or build manually:

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
