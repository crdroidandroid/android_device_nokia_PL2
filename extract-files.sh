#!/bin/bash
#
# Copyright (C) 2016 The CyanogenMod Project
# Copyright (C) 2017-2023 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

DEVICE=PL2
VENDOR=nokia

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

ONLY_FIRMWARE=
KANG=
SECTION=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        --only-firmware )
                ONLY_FIRMWARE=true
                ;;
        -n | --no-cleanup )
                CLEAN_VENDOR=false
                ;;
        -k | --kang )
                KANG="--kang"
                ;;
        -s | --section )
                SECTION="${2}"; shift
                CLEAN_VENDOR=false
                ;;
        * )
                SRC="${1}"
                ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

function blob_fixup() {
    case "${1}" in
        product/lib64/libdpmframework.so)
            for  LIBCUTILS_SHIM in $(grep -L "libcutils_shim.so" "${2}"); do
                "${PATCHELF}" --add-needed "libcutils_shim.so" "${2}"
            done
            ;;
        # Fix missing symbols
        product/lib64/lib-imscamera.so | product/lib64/lib-imsvideocodec.so | product/lib/lib-imscamera.so | product/lib/lib-imsvideocodec.so)
            for LIBGUI_SHIM in $(grep -L "libgui_shim.so" "${2}"); do
                "${PATCHELF}" --add-needed "libgui_shim.so" "${LIBGUI_SHIM}"
            done
            ;;
        vendor/etc/nfcee_access.xml)
            sed -i 's|xliff="urn:oasis:names:tc:xliff:document:1.2"|android="http://schemas.android.com/apk/res/android"|' "${2}"
            ;;
        vendor/bin/pm-service)
            grep -q libutils-v33.so "${2}" || "${PATCHELF}" --add-needed "libutils-v33.so" "${2}"
            ;;
        # Fix missing symbols
        vendor/lib/libgui_vendor.so)
            for LIBGUI_SHIM in $(grep -L "libgui_shim_vendor.so" "${2}"); do
                "${PATCHELF}" --add-needed "libgui_shim_vendor.so" "${LIBGUI_SHIM}"
            done
            ;;
        vendor/lib/hw/camera.sdm660.so)
            for  MEGVII_SHIM in $(grep -L "libshim_megvii.so" "${2}"); do
                "${PATCHELF}" --remove-needed "libMegviiFacepp.so" "$MEGVII_SHIM"
                "${PATCHELF}" --remove-needed "libmegface-new.so" "$MEGVII_SHIM"
                "${PATCHELF}" --add-needed "libshim_megvii.so" "$MEGVII_SHIM"
            done
            ;;
    esac
}

# Initialize the helper
setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" false "${CLEAN_VENDOR}"

if [ -z "${ONLY_FIRMWARE}" ]; then
    extract "${MY_DIR}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"
fi

"${MY_DIR}/setup-makefiles.sh"
