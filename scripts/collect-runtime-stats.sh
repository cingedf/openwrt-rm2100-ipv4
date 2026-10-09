#!/bin/sh
# Capture idle or stress-test state on OpenWrt/RM2100; BusyBox ash compatible.
set -u
OUT="${1:-/tmp/rm2100-health-$(date +%Y%m%d-%H%M%S).txt}"

{
    echo "=== RM2100 health snapshot ==="
    date 2>/dev/null || true
    echo
    echo "=== uptime/load ==="
    uptime 2>/dev/null || true
    echo
    echo "=== memory ==="
    free -m 2>/dev/null || true
    grep -E '^(MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapTotal|SwapFree|Slab|SReclaimable|SUnreclaim):' /proc/meminfo 2>/dev/null || true
    echo
    echo "=== swap ==="
    cat /proc/swaps 2>/dev/null || true
    echo
    echo "=== zram stats ==="
    for f in /sys/block/zram*/mm_stat /sys/block/zram*/disksize /sys/block/zram*/comp_algorithm; do
        [ -r "$f" ] || continue
        echo "--- $f"
        cat "$f"
    done
    echo
    echo "=== conntrack usage ==="
    for f in /proc/sys/net/netfilter/nf_conntrack_count /proc/sys/net/netfilter/nf_conntrack_max; do
        [ -r "$f" ] || continue
        printf '%s: ' "$f"
        cat "$f"
    done
    echo
    echo "=== top processes by RSS (kB) ==="
    for f in /proc/[0-9]*/status; do
        [ -r "$f" ] || continue
        name="$(awk '/^Name:/ {print $2; exit}' "$f" 2>/dev/null)"
        rss="$(awk '/^VmRSS:/ {print $2; exit}' "$f" 2>/dev/null)"
        [ -n "$rss" ] || rss=0
        printf '%10s %s\n' "$rss" "${name:-unknown}"
    done | sort -rn | head -n 25
    echo
    echo "=== relevant kernel/system messages ==="
    (dmesg 2>/dev/null; logread 2>/dev/null) | grep -Ei 'out of memory|oom-killer|killed process|nf_conntrack.*full|tx timeout|watchdog|mt7615|mt7603|pppoe|error|failed' | tail -n 100 || true
} > "$OUT"

printf 'Saved snapshot: %s\n' "$OUT"
