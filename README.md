# Redmi AC2100 (RM2100) — OpenWrt 25.12.5 IPv4-only Profile

[![Build Status](https://github.com/cingedf/openwrt-rm2100-ipv4/actions/workflows/build.yml/badge.svg)](https://github.com/cingedf/openwrt-rm2100-ipv4/actions/workflows/build.yml)
[![OpenWrt Version](https://img.shields.io/badge/OpenWrt-25.12.5-blue)](https://openwrt.org/releases/25.12/start)
[![Target](https://img.shields.io/badge/Target-ramips%2Fmt7621-green)](https://openwrt.org/toh/hwdata/xiaomi/xiaomi_redmi_router_ac2100)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

> **Stable, minimal, IPv4-only OpenWrt build for Xiaomi Redmi Router AC2100 (RM2100)**  
> Pinned to official OpenWrt `v25.12.5` — no forks, no unverified patches, no blind "optimizations".

---

## 🎯 Target Device & Scope

| Item | Spec |
|------|------|
| **Device** | Xiaomi Redmi Router AC2100 / RM2100 |
| **Platform** | MediaTek MT7621A (dual-core MIPS 880 MHz) |
| **RAM / Flash** | 128 MiB DDR3 / 128 MiB NAND (UBI) |
| **WAN** | PPPoE (IPv4 only) |
| **LAN** | IPv4 DHCP + DNS (dnsmasq) |
| **Wi-Fi** | 2.4 GHz MT7603EN + 5 GHz MT7615N (AP mode) |
| **Management** | SSH only (Dropbear) — **no LuCI / web UI** |
| **Proxy** | ShellCrash — **nftables backend + TProxy** |
| **Swap** | ZRAM 64 MiB (LZO, priority 100) |

**IPv6 is disabled at kernel level** (`CONFIG_IPV6` unset) — no IPv6 modules, daemons, or UCI remnants in the final image.

---

## ✨ Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| **Official upstream only** | Pinned to `v25.12.5` tag; no Lean/ImmortalWrt/other fork patches |
| **Full source build** | ImageBuilder cannot disable IPv6 in kernel; we need `CONFIG_IPV6=n` |
| **Sparse seed config** | `make defconfig` resolves all dependencies; CI validates every symbol |
| **Single firewall path** | `firewall4` + nftables only — no parallel iptables backend |
| **`ip-tiny` over `ip-full`** | Minimal iproute2 variant keeps `ip rule/route` for TProxy policy routing |
| **Keep `curl` + `ca-bundle`** | ShellCrash install/update needs curl; `uclient-fetch` is not a drop-in replacement |
| **Explicit USB/SCSI/ext4/VFAT/NLS bans** | RM2100 has no USB; guards flash if target defaults change — **not a RAM saving claim** |
| **ZRAM 64 MiB LZO** | Conservative, no extra kernel deps; upstream `zram-swap` reads exact UCI keys |
| **BusyBox / Dropbear kept functional** | Pruning applets saves flash, not idle RAM; keep diagnostics & ShellCrash cron |

---

## 🚀 Quick Start

### 1. Build on GitHub Actions (recommended)

```bash
# Fork or create a repo from this template
gh repo create yourname/openwrt-rm2100-ipv4 --public --clone
# Copy this directory's contents to the repo root (preserve .github/workflows/)
git add . && git commit -m "Add RM2100 IPv4-only profile" && git push
```

Then: **Actions → Build Redmi AC2100 - OpenWrt 25.12.5 IPv4-only → Run workflow**

Artifacts produced:
- `...-squashfs-kernel1.bin` + `...-squashfs-rootfs0.bin` — **first install** (two partitions)
- `...-squashfs-sysupgrade.bin` — **upgrade** from existing OpenWrt
- `resolved-openwrt.config` / `resolved-linux-kernel.config` / `feeds-info.txt` / `SHA256SUMS`

### 2. Flashing — **Read carefully**

| Image | Use Case |
|-------|----------|
| `kernel1.bin` + `rootfs0.bin` | **First install** — RM2100 uses separate kernel/rootfs partitions |
| `sysupgrade.bin` | **Upgrade only** — already running compatible OpenWrt |

⚠️ **Do NOT write `sysupgrade.bin` to `kernel1`/`rootfs0` directly.**  
Follow the current [RM2100 installation guide](https://openwrt.org/toh/hwdata/xiaomi/xiaomi_redmi_router_ac2100), confirm boot-slot state, back up config & bootloader env, keep recovery path.

---

## 🔧 First Boot (via Ethernet)

| Default | Value |
|---------|-------|
| **LAN IP** | `192.168.31.1` |
| **Hostname** | `Redmi-AC2100` |
| **SSH** | `root@192.168.31.1` (password: `password`) |
| **Wi-Fi** | **Disabled** — radios off until you set unique SSIDs/keys |

**Immediate steps after SSH login:**

```sh
# 1. Change root password
passwd

# 2. Configure Wi-Fi (verify indices first!)
uci show wireless
# Typical: @wifi-iface[0] on radio0 (2.4G), @wifi-iface[1] on radio1 (5G)

# 3. Example (adjust indices per your `uci show wireless`)
uci set wireless.@wifi-iface[0].ssid='YOUR_2G_SSID'
uci set wireless.@wifi-iface[0].encryption='psk2'
uci set wireless.@wifi-iface[0].key='YOUR_STRONG_PASSWORD'
uci set wireless.@wifi-iface[1].ssid='YOUR_5G_SSID'
uci set wireless.@wifi-iface[1].encryption='psk2'
uci set wireless.@wifi-iface[1].key='YOUR_STRONG_PASSWORD'
uci set wireless.radio0.disabled='0'
uci set wireless.radio1.disabled='0'
uci commit wireless
wifi reload
```

---

## 📦 ShellCrash Setup (Transparent Proxy)

This image includes ShellCrash runtime dependencies. After first boot:

```sh
# Install ShellCrash (follow its current installer)
sh -c "$(curl -kfsSL https://raw.githubusercontent.com/juewuy/ShellCrash/master/install.sh)"

# In ShellCrash menu:
# - Select proxy core (auto-detect MIPS LE softfloat first)
# - Choose: nftables firewall backend + TProxy mode
# - Do NOT enable flow offload (breaks TProxy packet visibility)
```

**Verify TProxy policy routing after start:**
```sh
ip rule show
ip route show table 100
```

> ⚠️ **High-impact RAM optimization**: ShellCrash PR [#1305](https://github.com/juewuy/ShellCrash/pull/1305) (merged to `dev` 2026-07-11) can store the uncompressed core persistently instead of decompressing into tmpfs, potentially reclaiming ~36 MiB `RssShmem`.  
> **Do not blindly apply** — verify on RM2100: check `/etc/ShellCrash` filesystem, available space, and whether `readlink -f /tmp/ShellCrash/CrashCore` points to a persistent file. Test the exact `dev` build before daily use.

---

## 📊 Runtime Validation (Don't Guess — Measure)

### One-shot detailed snapshot
```sh
sh /root/collect-runtime-stats.sh /tmp/rm2100-idle.txt
```

### Low-overhead time series (2-hour stress test)
```sh
# 10-second interval, 720 samples ≈ 2 hours
sh /root/sample-runtime.sh 10 720 /tmp/rm2100-peak.csv
```

### Capture after load
```sh
sh /root/collect-runtime-stats.sh /tmp/rm2100-after-test.txt
```

**What gets recorded:**
- `MemAvailable`, swap, slab, top 25 processes by RSS
- ZRAM `mm_stat`, disk size, compression algorithm
- conntrack current/max counts
- Kernel/system warnings: OOM, conntrack full, TX timeout, Wi-Fi/PPPoE errors

---

## ✅ Acceptance Checklist (Must Pass Before Claiming Success)

1. **Boot & basics** — SSH works, LAN `192.168.31.1`, `ps` shows no LuCI/rpcd/uhttpd/odhcpd
2. **IPv6 absent** — `zcat /proc/config.gz | grep CONFIG_IPV6` → not `y`/`m` (or check CI artifact `resolved-linux-kernel.config`)
3. **PPPoE** — Stable over reconnects & reboots; IPv4 DNS/DHCP functional
4. **Wi-Fi** — Each band independently, then both together with clients
5. **ShellCrash** — nftables + TProxy, TCP & UDP through LAN client; `ip rule/route table 100` correct; flow offload disabled
6. **2–4 hour stress** — Multiple clients (video, downloads, browsing); record latency, packet loss, `MemAvailable`, proxy RSS, conntrack, ZRAM, logs
7. **Only then** — Test one performance tweak at a time (IRQ affinity, packet steering, HNAT, etc.) and repeat full checklist

---

## 🏗️ Build System (GitHub Actions)

```yaml
# .github/workflows/build.yml
- Ubuntu 24.04 runner
- Pinned OpenWrt v25.12.5 tag
- ccache (1 GB) with content-based compiler_check
- Strict assertions:
  ✅ Required packages present (target, wifi, ppp, nftables, ShellCrash deps)
  ✅ Forbidden packages absent (LuCI, IPv6, iptables, USB, SCSI, ext4, VFAT, NLS, ip-full, etc.)
  ✅ Kernel CONFIG_IPV6 not y/m
  ✅ All three RM2100 image types produced
```

---

## 📁 Repository Structure

```
.
├── .github/workflows/build.yml      # CI pipeline
├── config/redmi_ac2100_minimal.config  # Sparse seed config
├── diy-part2.sh                     # Overlay copy + tag verification
├── files/etc/uci-defaults/
│   └── 99-redmi-ac2100-firstboot    # First-boot UCI defaults
├── scripts/
│   ├── collect-runtime-stats.sh     # Detailed health snapshot
│   └── sample-runtime.sh            # Low-overhead time series
└── README.md
```

---

## 📚 References

| Topic | Link |
|-------|------|
| OpenWrt 25.12 release notes | https://openwrt.org/releases/25.12/start |
| RM2100 device page | https://openwrt.org/toh/hwdata/xiaomi/xiaomi_redmi_router_ac2100 |
| Official image definition (v25.12.5) | https://github.com/openwrt/openwrt/blob/v25.12.5/target/linux/ramips/image/mt7621.mk |
| ShellCrash PR #1305 (core storage) | https://github.com/juewuy/ShellCrash/pull/1305 |
| dnsmasq feature options | https://git.openwrt.org/openwrt/openwrt/tree/package/network/services/dnsmasq/Makefile |
| zram-swap init (v25.12.5) | https://github.com/openwrt/openwrt/blob/v25.12.5/package/system/zram-swap/files/zram.init |
| sysctl defaults (v25.12.5) | https://github.com/openwrt/openwrt/blob/v25.12.5/package/base-files/files/etc/init.d/sysctl |
| iproute2 `ip-tiny` vs `ip-full` | https://raw.githubusercontent.com/openwrt/openwrt/openwrt-25.12/package/network/utils/iproute2/Makefile |
| ShellCrash deps & MIPS builds | https://github.com/juewuy/ShellCrash/blob/dev/README.md |

---

## ⚖️ License

MIT — see [LICENSE](LICENSE).  
Upstream OpenWrt components retain their respective licenses (GPL-2.0-only, etc.).

---

> **No claim of successful build or hardware validation is made until GitHub Actions passes and the physical RM2100 clears the acceptance checklist above.**
