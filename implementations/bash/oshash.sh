#!/bin/bash
# OpenSubtitles Hash (OSHash) - Bash implementation.
# Note: This is slow due to shell arithmetic limitations but works correctly.

correct_64bit() {
    local pow32=$(( 1 << 32 ))
    while [ "$g_lo" -ge $pow32 ]; do
        g_lo=$(( g_lo - pow32 ))
        g_hi=$(( g_hi + 1 ))
    done
    while [ "$g_hi" -ge $pow32 ]; do
        g_hi=$(( g_hi - pow32 ))
    done
}

hash_part() {
    local file="$1"
    local curr=0
    local dsize=$((8192*8))
    local bytes_at_once=2048
    local groups=$(( (bytes_at_once / 8) - 1 ))
    local k=0
    local offset=0
    declare -a num=()

    while [ "$curr" -lt "$dsize" ]; do
        num=( $(od -t u1 -An -N "$bytes_at_once" -w$bytes_at_once -j "$curr" "$file") )
        for k in $(seq 0 $groups); do
            offset=$(( k * 8 ))
            g_lo=$(( g_lo + \
                num[$(( offset + 0 ))] + \
                (num[$(( offset + 1 ))] << 8) + \
                (num[$(( offset + 2 ))] << 16) + \
                (num[$(( offset + 3 ))] << 24) ))
            g_hi=$(( g_hi + \
                num[$(( offset + 4 ))] + \
                (num[$(( offset + 5 ))] << 8) + \
                (num[$(( offset + 6 ))] << 16) + \
                (num[$(( offset + 7 ))] << 24) ))
            correct_64bit
        done
        curr=$(( curr + bytes_at_once ))
    done
}

hash_file() {
    g_lo=0
    g_hi=0

    local file="$1"
    local size=$(stat -c%s "$file")
    local offset=$(( size - 65536 ))

    local part1=$(mktemp)
    local part2=$(mktemp)

    dd if="$file" bs=65536 count=1 of="$part1" 2>/dev/null
    dd if="$file" bs=1 skip="$offset" count=65536 of="$part2" 2>/dev/null

    hash_part "$part1"
    hash_part "$part2"

    g_lo=$(( g_lo + size ))
    correct_64bit

    rm -f "$part1" "$part2"
    printf "%08x%08x\n" $g_hi $g_lo
}

if [ -z "$1" ]; then
    echo "Usage: $0 <file>" >&2
    exit 1
fi

hash_file "$1"
