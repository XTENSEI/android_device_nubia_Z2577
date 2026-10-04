# OrangeFox device tree for Nubia V80 Max (Z2577)

OrangeFox 14.1 recovery for the Nubia V80 Max. The recovery binary is packed into
`vendor_boot.img`, so this tree builds `vendorbootimage`.

# Device specifications

Basic | Spec sheet
----: | ----
Device | Nubia V80 Max
Model | Z2577, stock product name `P615F02`
SoC | Unisoc T7250 (UMS9230), board `ums9230_6h10`
Display | 720 x 1640, 320 dpi
Storage | 256 GB, f2fs `/data` with FBE, EROFS read-only partitions, dynamic `super`
Android | 16 (SDK 36), kernel 5.15.189-android13-8
Bootloader | must be unlocked

# Checks

`[✔]` works on device, `[?]` in the build but unverified, `[ ]` untested,
`[!]` not possible on this device.

## Blocking checks

- [✔] Correct screen/recovery size
- [✔] Working touch, screen
- [✔] Decrypt `/data` with the screen lock PIN
- [✔] Reboot to recovery
- [✔] Reboot to system
- [✔] ADB
- [✔] Correct date
- [✔] Battery level and temperature
- [ ] Backup to internal
- [ ] Restore from internal
- [ ] Format data

## Medium checks

- [✔] update.zip sideload
- [?] Every partition listed in the mount and backup lists
- [?] Cold boot decrypt with no manual steps
- [?] Vibrator in the UI (evdev FF_RUMBLE verified with the test binary)
- [?] microSD as removable storage, detected and mounted but switching was
      broken before the `/external_sd` fix, verify on the next build
- [✔] NTFS mount support
- [ ] Backup to microSD
- [ ] Restore from microSD
- [ ] microSD format and partition
- [?] exFAT card, the kernel has exFAT built in and TWRP probes the card before
      mounting, verify on device
- [ ] USB OTG storage

## Minor checks

- [✔] Screen never blanks
- [✔] Brightness slider
- [✔] Terminal and logcat
- [✔] Fastbootd
- [ ] Screenshot
- [ ] Reboot to bootloader
- [ ] Poweroff
- [ ] USB mass storage
- [?] MTP, compiled in and the server starts, but the kernel has no ffs_mtp so
      neither `/dev/mtp_usb` nor `/dev/usb-ffs/mtp/ep0` ever appears.
      `start_mtp.sh` loads a vendor module if one turns up
- [?] RNDIS, `setprop sys.usb.rndis 1` from adb links the vendor rndis function
      next to `ffs.adb` and gives `usb0` 192.168.42.129/24. No DHCP server in the
      ramdisk, so the PC needs a matching address by hand. Log in `/tmp/start_rndis.log`
- [!] Flashlight, no torch node in the kernel

# Clone

    git clone -b fox-14.1 https://github.com/XTENSEI/android_device_nubia_Z2577 device/nubia/Z2577

# Build

Sync the OrangeFox 14.1 sources first, then build:

    orangefox_sync.sh -b 14.1
    export ALLOW_MISSING_DEPENDENCIES=true
    . build/envsetup.sh
    lunch twrp_Z2577-ap2a-eng
    mka adbd vendorbootimage

The 3-part lunch name is required, the 14.x envsetup rejects `twrp_Z2577-eng`.

Or build it from the Actions tab, **OrangeFox Build**, `workflow_dispatch`:

    gh workflow run "OrangeFox Build" -R XTENSEI/android_device_nubia_Z2577 \
      --ref fox-14.1 \
      -f DEVICE_TREE_URL=https://github.com/XTENSEI/android_device_nubia_Z2577 \
      -f DEVICE_TREE_BRANCH=fox-14.1 \
      -f DEVICE_PATH=device/nubia/Z2577 \
      -f DEVICE_NAME=Z2577 \
      -f BUILD_TARGET=vendor_boot

# Flash

Keep a copy of the stock `vendor_boot.img` first, recovery lives there.
`fastboot boot` does not work on this SoC, the Unisoc bootloader only fastboots
boot images, so recovery has to be flashed.

    adb reboot bootloader
    fastboot flash vendor_boot out/target/product/Z2577/vendor_boot.img
    fastboot reboot

Going back to stock is the same command with the stock image.

# Notes

- `patches/` holds full source files copied over the synced tree, the workflow
  greps each one so a patch that does not land fails the build.
- OrangeFox forces the logical partitions (system, vendor, product, odm,
  system_ext, the dlkm pair) to non-backupable and puts `super` in their place.
  Backing up super covers all of them.

# References

- [OrangeFox](https://gitlab.com/OrangeFox) - recovery 14.1
- [TeamWin Recovery Project](https://github.com/TeamWin) - minuitwrp GUI
- [Massatriof16](https://github.com/Massatriof16) - Unisoc UMS9230 reference
  trees and the Actions recovery builder