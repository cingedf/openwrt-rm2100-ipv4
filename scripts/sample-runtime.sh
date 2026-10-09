#!/bin/sh
# Low-overhead time-series sampler for idle and multi-client stress tests.
# Usage: sh sample-runtime.sh [interval_seconds] [sample_count] [output_file]
# Default: sample every 10 seconds for 2 hours (720 samples).
set -eu

INTERVAL="${1:-10}"
SAMPLES="${2:-720}"
OUT="${3:-/tmp/rm2100-series-$(date +%Y%m%d-%H%M%S).csv}"

case "$INTERVAL" in ''|*[!0-9]*) echo 'interval must be an integer >= 1' >&2; exit 2;; esac
case "$SAMPLES" in ''|*[!0-9]*) echo 'sample_count must be a positive integer' >&2; exit 2;; esac
[ "$INTERVAL" -ge 1 ] || { echo 'interval must be >= 1 second' >&2; exit 2; }
[ "$SAMPLES" -ge 1 ] || { echo 'sample_count must be >= 1' >&2; exit 2; }

mem_value() {
    awk -v key="$1" '$1 == key ":" {print $2; found=1} END {if (!found) print 0}' /proc/meminfo
}
read_value() {
    if [ -r "$1" ]; then cat "$1"; else printf 'NA'; fi
}

umask 077
{
    printf '# RM2100 low-overhead runtime series\n'
    printf '# interval_seconds=%s sample_count=%s\n' "$INTERVAL" "$SAMPLES"
    printf 'epoch,uptime_seconds,load1,mem_available_kb,mem_free_kb,cached_kb,swap_free_kb,conntrack_count,conntrack_max,zram_mm_stat\n'
} > "$OUT"

n=0
while [ "$n" -lt "$SAMPLES" ]; do
    epoch="$(date +%s)"
    uptime_seconds="$(awk '{print int($1)}' /proc/uptime 2>/dev/null || printf '0')"
    load1="$(awk '{print $1}' /proc/loadavg 2>/dev/null || printf 'NA')"
    available="$(mem_value MemAvailable)"
    free_kb="$(mem_value MemFree)"
    cached="$(mem_value Cached)"
    swap_free="$(mem_value SwapFree)"
    ct_count="$(read_value /proc/sys/net/netfilter/nf_conntrack_count)"
    ct_max="$(read_value /proc/sys/net/netfilter/nf_conntrack_max)"
    zram="$(read_value /sys/block/zram0/mm_stat)"
    # mm_stat is space-delimited; replace spaces so each sample stays one CSV field.
    zram="$(printf '%s' "$zram" | tr ' ' ':')"
    printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
        "$epoch" "$uptime_seconds" "$load1" "$available" "$free_kb" \
        "$cached" "$swap_free" "$ct_count" "$ct_max" "$zram" >> "$OUT"
    n=$((n + 1))
    [ "$n" -lt "$SAMPLES" ] && sleep "$INTERVAL"
done

printf 'Saved %s samples to %s\n' "$SAMPLES" "$OUT"
