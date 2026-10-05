# OrangeFox device tree for Nubia V80 Max (Z2577)

OrangeFox 14.1 recovery for the Nubia V80 Max. The recovery binary is packed into
`vendor_boot.img`, so this tree builds `vendorbootimage`.

Build on the device right now: CI run `37257296699`, commit `2a2f4d0`. The
`/system/bin/recovery` on the phone is byte for byte the one from that artifact
(sha256 `ad01853343235f3eed92f4a0b2eecd4b4dc8818ca30408b6662c27461c9a4de5`).
Everything in `fox-14.1` after that commit is in the tree but not on the device.

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

`[✔]` verified on device, `[?]` in the build but unverified, `[ ]` untested,
`[!]` not possible on this device.

## Blocking checks

- [✔] Correct screen/recovery size, the log opens at 720 x 1640
- [✔] Working touch, screen
- [✔] Decrypt `/data` with the screen lock PIN, `twrp.user.0.decrypt=1`
- [✔] Reboot to recovery
- [✔] Reboot to system
- [✔] ADB
- [✔] Correct date
- [✔] Battery level and temperature
- [✔] Backup to internal, 64 MB of `/boot` with a SHA2 digest in 5 seconds
- [ ] Restore from internal
- [ ] Format data

## Medium checks

- [?] update.zip sideload, the page opens, no package has been pushed through it
- [✔] Every partition listed in the mount and backup lists, 50 entries. The
      crash dumps (`sysdumpdb`, `uboot_log`, `blackbox`), the `avbmeta_rs*`
      copies and `reserve1`/`reserve2` are left out on purpose
- [✔] Cold boot decrypt with no manual steps, the gatekeeper TA loads from /odm
      once `twrp.storage.ready=1` lands
- [✔] Vibrator in the UI, sc27xx-vibra only reads `weak_magnitude`, so the FF
      effect sets that one. Verified on the flashed build
- [?] Touch tap haptics, a `tw_touch_vibrate` slider on the vibrate page, default
      off, and the install-start feedback. In the tree, needs the next flash
- [?] Install LED, `Leds()` now resolves `sc27xx:green` and `sc27xx:red` and
      blinks them through the LED class timer trigger. In the tree, next flash
- [✔] microSD as removable storage, mounted at `/external_sd`, with
      `/storage/sdcard0` and `/mnt/sdcard` symlinked to it
- [✔] NTFS mount support
- [ ] Backup to microSD
- [ ] Restore from microSD
- [ ] microSD format and partition
- [?] exFAT card, the card in the device is vfat. The kernel has exFAT built in
      and TWRP probes the card before mounting it
- [ ] USB OTG storage

## Minor checks

- [✔] Screen never blanks
- [✔] Brightness slider
- [✔] Idle CPU about 2% of one core, the 5 ms input poll is in the flashed build
- [✔] Terminal and logcat
- [✔] Fastbootd
- [ ] Screenshot
- [ ] Reboot to bootloader, the menu entry is there
- [ ] Poweroff, the menu entry is there
- [!] USB mass storage, no `f_mass_storage` module in the kernel or on the
      device, and the menu item is off through `TW_NO_USB_STORAGE`
- [!] MTP, the kernel has no `f_mtp`, no module anywhere on the device, so
      neither `/dev/mtp_usb` nor `/dev/usb-ffs/mtp/ep0` can ever appear.
      `start_mtp.sh` loads a vendor module if one turns up
- [✔] RNDIS, `setprop sys.usb.rndis 1` unbinds the gadget, links the vendor
      rndis function next to `ffs.adb`, rebinds and gives `usb0` 192.168.42.129/24.
      No DHCP server in the ramdisk, so the PC takes 192.168.42.100/24 by hand,
      then `adb connect 192.168.42.129:5555`. Log in `/tmp/start_rndis.log`
- [!] Flashlight, no torch node in the kernel

# Release status

The boot, decrypt, GUI and file access paths are verified on the hardware. Three
items are left before an unofficial release, and all three need one flash of the
current tree:

1. Tap haptics and the install LED, both in the tree since `2a2f4d0`.
2. Restore from a backup.
3. Format data, plus a full `super` backup if /data has the room for it
   (28 GB against 35 GB free).

Nothing else in the list is open. What the kernel cannot do is marked `[!]` and
needs a kernel change, not a tree change.

Harmless log noise, not worth chasing:

- `Failed to load image from Default/Progress/indeterminate033`, the OFox theme
  ships 32 frames and the loader asks for one more
- `UnMount: Unable to find partition for path '/lib'`, TWRP unmounting the
  vendor overlay
- `Unable to open module directory /vendor/lib/modules/5.15-gki`, this device
  keeps its modules in `vendor_dlkm`

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
- Every mount point in `twrp.flags` has to be a single path segment.
  `TWFunc::Get_Root_Path()` cuts at the second slash, so `/storage/sdcard0` never
  matched a partition.

# References

- [OrangeFox](https://gitlab.com/OrangeFox) - recovery 14.1
- [TeamWin Recovery Project](https://github.com/TeamWin) - minuitwrp GUI
- [Massatriof16](https://github.com/Massatriof16) - Unisoc UMS9230 reference
  trees and the Actions recovery builder