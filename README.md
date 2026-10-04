# OrangeFox device tree for Nubia V80 Max (Z2577)

OrangeFox/TWRP device tree for the Nubia V80 Max (Z2577). The recovery binary
is packed into `vendor_boot.img`.

| | |
|---|---|
| Device | Nubia V80 Max, codename Z2577 |
| SoC | Unisoc T7250 (UMS9230), board `ums9230_6h10` |
| Screen | 720x1640 @ 320, RGBX_8888, backlight `sprd_backlight` (max 255) |
| Storage | f2fs `/data` with FBE, EROFS read-only system partitions, dynamic `super` |
| Stock | Android 16 (SDK 36), kernel 5.15.189-android13-8 GKI |
| Bootloader | unlocked, required for flashing |
| Branch | `fox-14.1` (OrangeFox 14.1) |

## Feature checklist

`[x]` verified on device. `[~]` in the current build, unverified. `[ ]`
untested. `[!]` not possible.

### Boot and display

- [x] Recovery boots from a flashed `vendor_boot.img`
- [x] Display 720x1640 over DRM (legacy page flip, atomic commit hangs on SPRD)
- [x] Touch input (`zte_tpd.ko`, loaded with the vendor modules)
- [x] Backlight slider (`sprd_backlight`, max 255)
- [x] Screen never blanks or times out (`TW_NO_SCREEN_TIMEOUT`)
- [~] Idle CPU: poll blocks 5 ms instead of busy-spinning a frame per render
- [~] GUI frame rate 120 (`TW_FRAMERATE`)
- [~] Additions list scroll range
- [ ] Screenshot
- [!] Flashlight, no torch node in the kernel

### Encryption and data

- [x] `/data` decrypt with the screen lock PIN (FBE, keymint + gatekeeper via TEE)
- [x] f2fs `/data` mounted with the stock inlinecrypt options
- [~] Cold boot decrypt without manual steps
- [ ] Format data
- [ ] Encrypted backup (`TW_EXCLUDE_ENCRYPTED_BACKUPS` not set)

### Partitions and storage

- [~] 50 twrp.flags entries, 49 of them with `backup=1` and `flashimg=1`,
      covering every stock Unisoc partition: boot chain, vbmeta sets, modem and
      NV, boot control. `/super` is added by TWRP itself from the logical
      volumes, a second entry would be listed twice
- [x] 41 fstab entries: erofs and ext4 system side, f2fs metadata and data
- [x] microSD as removable storage (vfat, `mmcblk1p1`)
- [x] 161 vendor kernel modules shipped, 156 loaded by recovery
- [x] NTFS mount support (`ntfs3.ko` is in the load list)
- [ ] microSD format and partition
- [ ] exFAT, no module in the shipped set and kernel support unknown
- [ ] USB OTG storage

### Backup and restore

- [ ] Backup to `/data`
- [ ] Backup to microSD
- [ ] Restore from either location
- [ ] MD5 verification after backup
- [ ] Backup over adb

### Flash and install

- [x] Install zip sideload
- [~] Install image picker covers all 49 flashimg entries plus super. Slot-only
      partitions (`init_boot`, `dtb`, `logo`, `vbmeta_odm` and friends) carry
      `slotselect`, TWRP appends the active slot suffix
- [x] Format skips secure erase (`BOARD_SUPPRESS_SECURE_ERASE`)
- [ ] Format all selected partitions

### USB

- [x] adb
- [ ] MTP, not enabled in BoardConfig
- [ ] USB mass storage, no lun on the gadget
- [ ] USB OTG keyboard and mouse

### Power and hardware

- [x] Battery level and temperature (healthd)
- [~] Vibrator (evdev FF_RUMBLE, `sc27xx-vibra.ko`); FF verified on device, UI
      untested
- [x] Correct date
- [x] Reboot to recovery
- [x] Reboot to system
- [x] Fastbootd
- [ ] Reboot to bootloader
- [ ] Poweroff

### Tools

- [x] Terminal and logcat inside recovery
- [x] resetprop, avbctl, zstd, repack tools
- [x] APEX packages excluded, our own ueventd handles USB nodes

## Known issues

- `recovery.log` repeats `Is_Mounted: Unable to find partition for path
  '/storage/sdcard0'`. Harmless, cause not identified.
- `fastboot boot vendor_boot.img` does not work here. The Unisoc bootloader
  only fastboots boot images, so recovery has to be flashed.

## Build

Dispatch the **OrangeFox Build** workflow from the Actions tab
(`workflow_dispatch`), or run it from the CLI:

```bash
gh workflow run "OrangeFox Build" -R XTENSEI/android_device_nubia_Z2577 \
  --ref fox-14.1 \
  -f DEVICE_TREE_URL=https://github.com/XTENSEI/android_device_nubia_Z2577 \
  -f DEVICE_TREE_BRANCH=fox-14.1 \
  -f DEVICE_PATH=device/nubia/Z2577 \
  -f DEVICE_NAME=Z2577 \
  -f BUILD_TARGET=vendor_boot
```

`--ref fox-14.1` matters: the repository default branch is the historical
`twrp-12.1` line.

To build by hand, sync the OrangeFox 14.1 sources first:

```bash
orangefox_sync.sh -b 14.1
source build/envsetup.sh
export ALLOW_MISSING_DEPENDENCIES=true
lunch twrp_Z2577-ap2a-eng
mka adbd vendorbootimage -j$(nproc)
```

`patches/` is copied over the synced tree before the build. CI greps the
result, so a patch that does not land fails the build. Artifacts:
`vendor_boot.img`, plus the OrangeFox img, zip and md5.

## Install

Back up the stock `vendor_boot.img` first: recovery lives in that partition, so
flashing over it removes stock recovery.

```bash
adb reboot bootloader
fastboot flash vendor_boot out/target/product/Z2577/vendor_boot.img
fastboot reboot
```

Going back to stock:

```bash
fastboot flash vendor_boot stock-vendor_boot.img
fastboot reboot
```

## Credits

- [OrangeFox](https://gitlab.com/OrangeFox) - recovery 14.1
- [TeamWin Recovery Project](https://github.com/TeamWin) - minuitwrp GUI and
  the recovery toolset
- [Massatriof16](https://github.com/Massatriof16) - the Unisoc UMS9230
  reference trees and the Action-Recovery-Builder workflow