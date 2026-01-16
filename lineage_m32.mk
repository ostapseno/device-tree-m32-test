#
# Copyright (C) 2024 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# Inherit from device makefile.
$(call inherit-product, device/samsung/m32/device.mk)

# Inherit some common LineageOS stuff.
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)

PRODUCT_NAME := lineage_m32
PRODUCT_DEVICE := m32
PRODUCT_MANUFACTURER := samsung
PRODUCT_BRAND := samsung
PRODUCT_MODEL := SM-m325F

PRODUCT_GMS_CLIENTID_BASE := android-samsung-ss

PRODUCT_BUILD_PROP_OVERRIDES += \
    TARGET_DEVICE=m32 \
    PRODUCT_NAME=m32xx \
    PRIVATE_BUILD_DESC="m32xx-user 13 TP1A.220624.014 m325FXXS7DXA2 release-keys"

BUILD_FINGERPRINT := samsung/m32xx/m32:13/TP1A.220624.014/m325FXXS7DXA2:user/release-keys
