#
# Copyright (C) 2026 The Android Open Source Project
#
# SPDX-License-Identifier: Apache-2.0
#

LOCAL_PATH := device/nubia/Z2577

# Enable Virtual A/B OTA
ENABLE_VIRTUAL_AB := true
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota/launch_with_vendor_ramdisk.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota/compression.mk)

# Dynamic Partitions
PRODUCT_USE_DYNAMIC_PARTITIONS := true

# Boot control HAL + health
PRODUCT_PACKAGES += \
    android.hardware.health@2.1-impl \
    android.hardware.health@2.1-service \
    bootctrl.ums9230

# Keymint / gatekeeper / keystore2 (FBE decrypt via trusty)
PRODUCT_PACKAGES += \
    android.hardware.gatekeeper \
    android.hardware.security.keymint \
    android.hardware.security.secureclock \
    android.hardware.security.sharedsecret \
    libkeymint \
    libtrusty \
    libgatekeeper \
    android.system.keystore2
