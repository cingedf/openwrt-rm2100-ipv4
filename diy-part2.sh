#!/usr/bin/env bash
# Apply only stable, source-independent customizations to official OpenWrt.
set -Eeuo pipefail

log() { printf '[RM2100] %s\n' "$*"; }
die() { printf '::error::%s\n' "$*" >&2; exit 1; }

: "${GITHUB_WORKSPACE:?GITHUB_WORKSPACE is not set}"
[ -f "$GITHUB_WORKSPACE/config/redmi_ac2100_minimal.config" ] || die 'Missing sparse seed config'
[ -f "$GITHUB_WORKSPACE/files/etc/uci-defaults/99-redmi-ac2100-firstboot" ] || die 'Missing first-boot UCI defaults'
[ -f Makefile ] && [ -d target/linux/ramips ] || die 'Run from official OpenWrt source root'

ref="$(git describe --tags --exact-match HEAD 2>/dev/null || true)"
[ "$ref" = 'v25.12.5' ] || die "Expected official source tag v25.12.5, got '${ref:-untagged}'"

cp "$GITHUB_WORKSPACE/config/redmi_ac2100_minimal.config" .config
mkdir -p files
cp -a "$GITHUB_WORKSPACE/files/." files/
chmod 0755 files/etc/uci-defaults/99-redmi-ac2100-firstboot

log "Using upstream OpenWrt ${ref} ($(git rev-parse --short=12 HEAD))"
log 'Copied sparse config and uci-defaults overlay; no core source files or hardware clock/IRQ patches modified.'
