#!/usr/bin/env bash
set -euo pipefail

# Compare partition sizes from BoardConfig.mk with the connected device.
# Requires: adb, a booted device, and USB debugging enabled.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BOARD_CONFIG="${REPO_DIR}/BoardConfig.mk"

if ! command -v adb >/dev/null 2>&1; then
    echo "error: adb is not installed or not in PATH" >&2
    exit 1
fi

if [[ ! -f "${BOARD_CONFIG}" ]]; then
    echo "error: BoardConfig.mk not found at ${BOARD_CONFIG}" >&2
    exit 1
fi

adb get-state >/dev/null 2>&1 || {
    echo "error: no adb device found (or unauthorized)" >&2
    exit 1
}

extract_board_size() {
    local var="$1"
    local value
    value="$(
        awk -v k="${var}" '
            $0 ~ "^[[:space:]]*" k "[[:space:]]*:?=" {
                line=$0
                sub("^[[:space:]]*" k "[[:space:]]*:?=[[:space:]]*", "", line)
                gsub(/[[:space:]]/, "", line)
                last=line
            }
            END { if (last != "") print last }
        ' "${BOARD_CONFIG}"
    )"
    if [[ -z "${value}" || ! "${value}" =~ ^[0-9]+$ ]]; then
        echo ""
    else
        echo "${value}"
    fi
}

get_device_size_bytes() {
    local part="$1"
    local block
    local sectors

    block="$(
        adb shell "
            for d in \$(find /dev/block -type d -name by-name 2>/dev/null); do
                p=\"\$d/${part}\"
                if [ -e \"\$p\" ]; then
                    readlink -f \"\$p\"
                    exit 0
                fi
            done
        " | tr -d '\r' | tr -d '\n'
    )"
    if [[ -z "${block}" ]]; then
        echo ""
        return
    fi

    block="${block##*/}"
    sectors="$(adb shell "cat /sys/class/block/${block}/size 2>/dev/null" | tr -d '\r' | tr -d '\n')"
    if [[ -z "${sectors}" || ! "${sectors}" =~ ^[0-9]+$ ]]; then
        echo ""
        return
    fi

    echo $((sectors * 512))
}

print_row() {
    local var="$1"
    local part="$2"
    local board_size="$3"
    local device_size="$4"

    local board_mib device_mib diff
    board_mib="$(awk -v b="${board_size}" 'BEGIN{printf "%.2f", b/1024/1024}')"
    device_mib="$(awk -v b="${device_size}" 'BEGIN{printf "%.2f", b/1024/1024}')"
    diff=$((device_size - board_size))

    if [[ "${board_size}" -eq "${device_size}" ]]; then
        printf "OK   %-34s %-10s board=%12s (%7s MiB) device=%12s (%7s MiB)\n" \
            "${var}" "${part}" "${board_size}" "${board_mib}" "${device_size}" "${device_mib}"
    else
        local diff_mib
        diff_mib="$(awk -v b="${diff}" 'BEGIN{printf "%.2f", b/1024/1024}')"
        printf "FAIL %-34s %-10s board=%12s (%7s MiB) device=%12s (%7s MiB) diff=%s (%s MiB)\n" \
            "${var}" "${part}" "${board_size}" "${board_mib}" "${device_size}" "${device_mib}" "${diff}" "${diff_mib}"
    fi
}

checks=(
    "BOARD_BOOTIMAGE_PARTITION_SIZE:boot"
    "BOARD_RECOVERYIMAGE_PARTITION_SIZE:recovery"
    "BOARD_SUPER_PARTITION_SIZE:super"
)

echo "Checking partition sizes using ${BOARD_CONFIG}"
echo

fail_count=0
for entry in "${checks[@]}"; do
    var="${entry%%:*}"
    part="${entry##*:}"

    board_size="$(extract_board_size "${var}")"
    if [[ -z "${board_size}" ]]; then
        echo "SKIP ${var}: not set in BoardConfig.mk"
        continue
    fi

    device_size="$(get_device_size_bytes "${part}")"
    if [[ -z "${device_size}" ]]; then
        echo "SKIP ${var}: could not read /dev/block/by-name/${part} from device"
        continue
    fi

    print_row "${var}" "${part}" "${board_size}" "${device_size}"
    [[ "${board_size}" -eq "${device_size}" ]] || fail_count=$((fail_count + 1))
done

echo
if [[ "${fail_count}" -eq 0 ]]; then
    echo "Result: no mismatches found for checked partitions."
else
    echo "Result: ${fail_count} mismatch(es) found."
    exit 2
fi
