#
# AERA Recovery configuration for the Nubia V80 Max (Z2577).
# SPDX-License-Identifier: GPL-3.0-or-later
#
# bootable/recovery/aera_config.mk translates AERA_* to the backend switch it
# replaces. Inherited from device.mk.
#

AERA_MAINTAINER := XTENSEI

# Display: 720x1640 @ 320dpi, punch-hole top centre
AERA_SCREEN_H := 1640
AERA_STATUS_H := 84
AERA_HIDE_NOTCH := 1
AERA_STATUS_INDENT_LEFT := 140
AERA_STATUS_INDENT_RIGHT := 140
AERA_OPTIONS_LIST_NUM := 6
AERA_USE_GREEN_LED := 0

# Vibrator is evdev force feedback (sc27xx_vibra), not an AIDL Vibrator HAL
AERA_SUPPORT_INPUT_FF_HAPTICS := true

AERA_INCLUDE_CRYPTO := true
AERA_INCLUDE_CRYPTO_FBE := true
AERA_INCLUDE_FBE_METADATA_DECRYPT := true
AERA_USE_FSCRYPT_POLICY := 2
# keymint is AIDL V2 trusty, gatekeeper HIDL V1 trusty, no weaver
AERA_FORCE_KEYMASTER_VER := true
AERA_DEFAULT_KEYMASTER_VERSION := 2

# trusty stack + touch; must come from the recovery ramdisk
AERA_LOAD_VENDOR_MODULES := "trusty.ko trusty-ipc.ko trusty-irq.ko trusty-log.ko trusty-pm.ko trusty-virtio.ko trusty-tui.ko ion_ipc_trusty.ko rpmb.ko lcd_state_notify.ko zte_tpd.ko"
AERA_LOAD_VENDOR_BOOT_MODULES := true

AERA_ENABLE_ALL_PARTITION_TOOLS := 1
AERA_FORCE_DATA_FORMAT_F2FS := 1
AERA_UNBIND_SDCARD_F2FS := 1
AERA_WIPE_METADATA_AFTER_DATAFORMAT := 1
AERA_DYNAMIC_FULL_SIZE := 13690208256
AERA_DISPLAY_FORMAT_FILESYSTEMS_DEBUG_INFO := 1
AERA_NO_TREBLE_COMPATIBILITY_CHECK := 1
AERA_WORKAROUND_BACKUP_BUG := 1
AERA_USE_LZ4_COMPRESSION := 1
AERA_ALLOW_EARLY_SETTINGS_LOAD := 1

# Deliberately unset: AERA_USE_AIDL_BOOT_CONTROL (HIDL boot HAL only),
# AERA_AB_DEVICE_WITH_RECOVERY_PARTITION (recovery is in vendor_boot),
# AERA_ENABLE_WLAN (no WLAN module in vendor_dlkm or system_dlkm),
# AERA_ENABLE_MOBILE_DATA (no aera-cellular-provider for this SoC).
