#
# Copyright (C) 2026 The Android Open Source Project
#
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/nubia/Z2577
# For building with minimal manifest
ALLOW_MISSING_DEPENDENCIES := true

# Build hacks
BUILD_BROKEN_DUP_RULES := true
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true

# A/B
AB_OTA_UPDATER := true
AB_OTA_PARTITIONS += \
    boot \
    init_boot \
    vendor_boot \
    dtbo \
    system \
    system_ext \
    product \
    vendor \
    odm \
    system_dlkm \
    vendor_dlkm \
    vbmeta \
    vbmeta_system \
    vbmeta_vendor

TARGET_SCREEN_HEIGHT := 1640
TARGET_SCREEN_WIDTH := 720

# vendor_boot configuration (recovery lives inside the vendor_boot ramdisk)
TARGET_NO_RECOVERY := true
BOARD_BOOT_HEADER_VERSION := 4
BOARD_USES_GENERIC_KERNEL_IMAGE := true
BOARD_INCLUDE_RECOVERY_RAMDISK_IN_VENDOR_BOOT := true
BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT := true
BOARD_MOVE_GSI_AVB_KEYS_TO_VENDOR_BOOT := true
BOARD_RAMDISK_USE_LZ4 := true

# Assert
TARGET_OTA_ASSERT_DEVICE := Z2577

# Architecture
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := generic
TARGET_CPU_VARIANT_RUNTIME := cortex-a75

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv7-a-neon
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := generic
TARGET_2ND_CPU_VARIANT_RUNTIME := cortex-a55

# Bootloader
TARGET_BOOTLOADER_BOARD_NAME := Z2577
TARGET_NO_BOOTLOADER := true

# Display (720x1640 from stock dtb panel-max-x=0x2cf/panel-max-y=0x667; density 320 from ro.sf.lcd_density=320)
TARGET_SCREEN_DENSITY := 320

# Touch (stock vendor modules; zte_tpd depends on lcd_state_notify)
TW_LOAD_VENDOR_MODULES := "lcd_state_notify.ko zte_tpd.ko"
BOARD_KERNEL_SEPARATED_DTBO := true

# Kernel / vendor_boot (values from stock vendor_boot header, MIO-KITCHEN unpack)
TARGET_NO_KERNEL := true
BOARD_VENDOR_BASE := 0x00000000
BOARD_VENDOR_CMDLINE := console=ttyS1,115200n8 bootconfig bootconfig
BOARD_VENDOR_BOOTCONFIG := $(DEVICE_PATH)/bootconfig
BOARD_PAGE_SIZE := 4096
BOARD_KERNEL_OFFSET := 0x00008000
BOARD_RAMDISK_OFFSET := 0x05400000
BOARD_TAGS_OFFSET := 0x00000100
BOARD_HEADER_SIZE := 2128
TARGET_PREBUILT_DTB := $(DEVICE_PATH)/prebuilt/dtb.img
BOARD_DTB_SIZE := 157645
BOARD_DTB_OFFSET := 0x01f00000
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)
BOARD_MKBOOTIMG_ARGS += --base $(BOARD_VENDOR_BASE)
BOARD_MKBOOTIMG_ARGS += --ramdisk_offset $(BOARD_RAMDISK_OFFSET)
BOARD_MKBOOTIMG_ARGS += --kernel_offset $(BOARD_KERNEL_OFFSET)
BOARD_MKBOOTIMG_ARGS += --tags_offset $(BOARD_TAGS_OFFSET)
BOARD_MKBOOTIMG_ARGS += --dtb $(TARGET_PREBUILT_DTB)
BOARD_MKBOOTIMG_ARGS += --dtb_offset $(BOARD_DTB_OFFSET)
BOARD_MKBOOTIMG_ARGS += --vendor_bootconfig $(BOARD_VENDOR_BOOTCONFIG)

# Partitions (sizes from stock super metadata, MIO-KITCHEN config/parts_info)
BOARD_SYSTEMIMAGE_PARTITION_TYPE := erofs
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := f2fs
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true
BOARD_FLASH_BLOCK_SIZE := 262144 # (BOARD_KERNEL_PAGESIZE * 64)
BOARD_HAS_LARGE_FILESYSTEM := true
TARGET_COPY_OUT_VENDOR := vendor
BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 104857600 # 100 MiB, stock vendor_boot

BOARD_SUPER_PARTITION_SIZE := 13690208256
BOARD_SUPER_PARTITION_GROUPS := group_unisoc_a
BOARD_GROUP_UNISOC_A_PARTITION_LIST := system system_ext product vendor odm vendor_dlkm system_dlkm
BOARD_GROUP_UNISOC_A_SIZE := 13686013952

TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888

# Verified Boot (device is unlocked; recovery uses avb test keys)
BOARD_AVB_ENABLE := true
BOARD_AVB_RECOVERY_ALGORITHM := SHA256_RSA4096
BOARD_AVB_RECOVERY_KEY_PATH := external/avb/test/data/testkey_rsa4096.pem
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --set_hashtree_disabled_flag
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --flags 4

BOARD_SUPPRESS_SECURE_ERASE := true
