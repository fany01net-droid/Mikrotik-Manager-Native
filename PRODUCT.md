# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Stack

React, Vite, TypeScript, Tailwind CSS, Capacitor (Android APK)

## Users

Network administrators, sysadmins, ISP technicians, and home-lab users managing MikroTik RouterOS devices who need quick, reliable access to router vitals directly from their Android smartphones or Linux workstations.

## Product Purpose

Provide a clean, fast, privacy-focused mobile app (.apk) and web interface to configure connection credentials (IP, Port, Username, Password, SSL) and monitor MikroTik RouterOS v7 metrics (CPU, RAM, Storage, Uptime, Network Interfaces) in real-time.

## Positioning

Unlike heavy or ad-supported third-party MikroTik apps, FNet MikroTik Monitor is lean, open, ad-free, and communicates directly with the router's native REST API without any third-party cloud servers or external dependencies.

## Operating Context

Used primarily over local WiFi/LAN (e.g. `192.168.88.1`) or via secure VPN tunnels (WireGuard, OpenVPN, SSTP, L2TP). Operates in noisy network environments where quick troubleshooting and instant visual status indicators are critical.

## Capabilities and Constraints

- **Capabilities:**
  - Multiple router profile management (switch between routers seamlessly).
  - Custom REST API port & HTTPS/TLS toggle with self-signed certificate handling.
  - Live connection testing with latency benchmarking (`ms`).
  - Real-time gauge metrics: CPU load, RAM usage, HDD storage, system uptime.
  - Live network interface list with link status indicators (Running vs Down).
  - Auto-refresh mechanism with manual override.
- **Constraints:**
  - Targets MikroTik RouterOS v7.1+ REST API.
  - Requires local network permissions (`INTERNET`, `usesCleartextTraffic=true` for local HTTP).

## Brand Commitments

- Name: **FNet MikroTik Monitor**
- Visual Tone: High-tech dark theme inspired by enterprise network operations centers (NOC). Deep slate backgrounds, precision status badges (emerald for online, rose for error, sky for active parameters).

## Evidence on Hand

- Verified endpoints: `/rest/system/resource`, `/rest/interface`
- Local storage for credentials
- Vite dev-proxy anti-CORS bridge for instant browser preview

## Product Principles

1. **Instant Feedback:** Connection status, latency, and system health must be obvious at a glance.
2. **Zero Cloud Dependency:** Data stays entirely between the user's device and the MikroTik router.
3. **Ergonomic & Resilient:** Touch targets sized for mobile use (min 48dp), clear error messages with practical troubleshooting steps.
