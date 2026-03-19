<p align="center">
  <img src="assets/offveil-logo.svg" alt="OffVeil" width="400" />
</p>

<h3 align="center">
  Native DPI bypass engine for macOS - no VPN, no external servers, no speed loss.
</h3>

<p align="center">
  <a href="https://github.com/berkaykyb/offveil-macOS/releases"><img src="https://img.shields.io/github/v/release/berkaykyb/offveil-macOS?style=flat-square&color=00c896&label=release" alt="Release" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-All%20Rights%20Reserved-red?style=flat-square" alt="License" /></a>
  <a href="https://github.com/berkaykyb/offveil-macOS/stargazers"><img src="https://img.shields.io/github/stars/berkaykyb/offveil-macOS?style=flat-square&color=ffcc00" alt="Stars" /></a>
  <a href="https://github.com/berkaykyb/offveil-macOS/releases"><img src="https://img.shields.io/github/downloads/berkaykyb/offveil-macOS/total?style=flat-square&color=00c896&label=downloads" alt="Downloads" /></a>
</p>

<p align="center">
  <a href="README_TR.md">Turkce</a>
</p>

---

## What is offveil?

**offveil** is a lightweight system-tray application designed to circumvent **Deep Packet Inspection (DPI)** restrictions effortlessly. 

Unlike traditional VPNs, OffVeil **never routes your traffic through third-party servers**. It operates entirely on your local machine. Your connection remains direct, and your download/upload speeds are uncompromised - the only change is that ISPs can no longer inspect or block your traffic based on domain names (SNI).

Everything happens on-device, ensuring maximum privacy and zero latency overhead.

---

## Features

- **One-click Protection:** A single toggle from the menu bar secures your connection immediately.
- **Smart Network Handling:** Automatically detects network state changes (Wi-Fi ↔ Ethernet, sleep/wake) and seamlessly rebinds protection.
- **Robust Recovery:** A built-in watchdog process ensures your system proxy settings are always restored gracefully, even if the application shuts down unexpectedly.
- **Auto-configuration:** Dynamically manages macOS system proxy settings (`networksetup`) without requiring manual terminal commands.
- **Energy Efficient:** Built specifically for macOS, running quietly in the background with minimal resource footprint.
- **Auto-updates:** Stays current seamlessly via GitHub Releases.

---

## Screenshots

<table>
  <tr>
    <th align="center">Active State</th>
    <th align="center">Inactive State</th>
    <th align="center">Settings - General</th>
    <th align="center">Settings - Support</th>
  </tr>
  <tr>
    <td align="center"><img src="assets/ss-active.png" width="240" /></td>
    <td align="center"><img src="assets/ss-inactive.png" width="240" /></td>
    <td align="center"><img src="assets/ss-settings.png" width="240" /></td>
    <td align="center"><img src="assets/ss-settings2.png" width="240" /></td>
  </tr>
</table>

---

## Technical Architecture & The Road to v2.0

Currently (v1.x), OffVeil for macOS utilizes [SpoofDPI](https://github.com/xvzc/SpoofDPI) as its core packet-processing engine. The application establishes a local proxy (`127.0.0.1:18080`) and automatically routes all system HTTP/HTTPS traffic through it to perform TLS ClientHello fragmentation.

### Why not kernel-level interception yet?

Developing a kernel-level network filter on Apple platforms requires implementing a **Network Extension**. Apple strictly gates this entitlement behind the **Apple Developer Program**. Without an active and approved developer account, code containing Network Extensions cannot be signed, tested, or executed on typical user machines.

### The v2.0 Vision

To deliver a working, reliable, and free application to users *today*, we adopted the local-proxy architecture leveraging SpoofDPI. **This is a temporary stepping stone.**

Upon securing an Apple Developer account, our immediate roadmap includes:

1. Developing a native, **Swift-based Network Extension** for kernel-level packet manipulation.
2. Completely dropping the local HTTP proxy architecture.
3. Achieving a zero-overhead, hyper-efficient DPI bypass with no proxy latency overhead.

Until then, OffVeil provides the most robust GUI and lifecycle management wrapper available for macOS DPI bypassing.

---

## Comparison

The macOS DPI bypass ecosystem is sparse and heavily CLI-oriented. OffVeil bridges the gap between technical efficacy and everyday usability on Apple platforms.

| Feature | **offveil (macOS)** | SpoofDPI (raw) | ByeDPI (raw) | Surge |
|---------|:-----------:|:--------:|:------:|:-----:|
| **Platform** | **macOS** | macOS | macOS | macOS |
| **Interface** | **Native GUI** | CLI | CLI | Native GUI |
| **Bypass Method** | **DPI Bypass via Local Proxy** | HTTP Proxy | SOCKS Proxy | Rules-based Proxy |
| **System Proxy Mgt** | **Automatic** | Manual | Manual | Automatic |
| **Network Rebind** | **Automatic** | Manual | Manual | Manual |
| **Crash Recovery** | **Automatic** | N/A | N/A | N/A |
| **Auto-update** | **Yes** | No | No | Yes |
| **Price** | **Free** | Free | Free | Paid (~$50+) |
| **Usage** | **Background App** | Terminal Session | Terminal Session | Background App |

---

## Installation

1. Download the latest `offveil.dmg` from the **[Releases](https://github.com/berkaykyb/offveil-macOS/releases)** page.
2. Open the downloaded `.dmg` file.
3. Drag the **offveil** application into your **Applications** folder.
4. **First launch only:** Since offveil is not distributed through the App Store, macOS requires a one-time approval. Open **Terminal** and run:
   ```bash
   xattr -cr /Applications/offveil.app
   ```
5. Open **offveil** from your Applications folder.

After this initial setup, offveil will open normally on all subsequent launches. Updates are handled automatically from within the app.

*Requires macOS 13 Ventura or later. Fully native on both Apple Silicon (M-series) and Intel architectures.*

---

## Tech Stack

| Component | Technology |
|-------|-----------|
| **Frontend UI** | SwiftUI |
| **State & Lifecycle** | Python 3 (compiled to standalone binary via PyInstaller) |
| **Proxy Engine** | [SpoofDPI](https://github.com/xvzc/SpoofDPI) (Go binary) |
| **Network Routing** | `Network.framework` (macOS native), `networksetup` CLI |

---

## Supported by the Community

If offveil has successfully lifted the veil for you and restored your access to the open internet, the simplest and most effective way to help the project grow is to **Star** this repository. It increases visibility and helps other users facing similar restrictions discover the tool.

<p align="center">
  <a href="https://github.com/berkaykyb/offveil-macOS/stargazers">
    <img src="https://img.shields.io/github/stars/berkaykyb/offveil-macOS?style=for-the-badge&color=ffcc00&label=%E2%AD%90%20Star%20offveil" alt="Star on GitHub" />
  </a>
</p>

---

## Acknowledgements & Licensing

This project is **All Rights Reserved**. The source code is made publicly available on GitHub for transparency and educational purposes only. No permission is granted to copy, modify, or distribute the code without explicit written consent from the author. See the [LICENSE](LICENSE) file for full terms.

OffVeil (macOS) v1.x utilizes the excellent open-source project **[SpoofDPI](https://github.com/xvzc/SpoofDPI)** by [@xvzc](https://github.com/xvzc) for its core packet fragmentation capabilities. SpoofDPI is licensed under the [Apache License 2.0](https://github.com/xvzc/SpoofDPI/blob/main/LICENSE).

A special thanks to **[@erayselim](https://github.com/erayselim)** for inspiring the original vision behind this project.

<p align="center">
  <sub>Lifting the veil. Restoring the open web.</sub>
</p>
