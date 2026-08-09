#
# Copyright (C) 2026 The Android Open Source Project
#
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/nubia/Z2577

# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# Inherit some common TWRP stuff.
$(call inherit-product, vendor/twrp/config/common.mk)

# Inherit from Z2577 device
$(call inherit-product, device/nubia/Z2577/device.mk)

PRODUCT_DEVICE := Z2577
PRODUCT_NAME := twrp_Z2577
PRODUCT_BRAND := nubia
PRODUCT_MODEL := Z2577
PRODUCT_MANUFACTURER := nubia

PRODUCT_BUILD_PROP_OVERRIDES += \
    PRIVATE_BUILD_DESC="P615F02-user 16 BP2A.250605.031.A3 20260522.092043 release-keys"

BUILD_FINGERPRINT := nubia/P615F02/P615F02:16/BP2A.250605.031.A3/20260522.092043:user/release-keys
