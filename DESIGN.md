---
name: NOC - System Design System
description: Clean Apple iOS & HIG inspired minimalist theme for NOC System
colors:
  primary: "#0071e3"
  primary-hover: "#0077ed"
  background: "#f5f5f7"
  surface: "#ffffff"
  surface-card: "#ffffff"
  surface-input: "#f5f5f7"
  text-primary: "#1d1d1f"
  text-secondary: "#86868b"
  text-muted: "#86868b"
  success: "#10b981"
  success-bg: "#d1fae5"
  warning: "#f59e0b"
  warning-bg: "#fef3c7"
  danger: "#ef4444"
  danger-bg: "#fee2e2"
  border: "#d2d2d7"
  gauge-emerald-start: "#34d399"
  gauge-emerald-end: "#059669"
  gauge-rose-start: "#fb7185"
  gauge-rose-end: "#dc2626"
  gauge-amber-start: "#fde047"
  gauge-amber-end: "#ea580c"
  modal-shadow: "rgba(0, 0, 0, 0.08)"
typography:
  display:
    fontFamily: "-apple-system, BlinkMacSystemFont, 'SF Pro Display', 'Inter', system-ui, sans-serif"
    fontSize: "1.5rem"
    fontWeight: 700
    lineHeight: 1.2
  title:
    fontFamily: "-apple-system, BlinkMacSystemFont, 'SF Pro Display', 'Inter', system-ui, sans-serif"
    fontSize: "1.125rem"
    fontWeight: 600
    lineHeight: 1.3
  body:
    fontFamily: "-apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Inter', system-ui, sans-serif"
    fontSize: "0.875rem"
    fontWeight: 400
    lineHeight: 1.5
  mono:
    fontFamily: "'SF Mono', 'JetBrains Mono', ui-monospace, monospace"
    fontSize: "0.75rem"
    fontWeight: 500
  caption:
    fontFamily: "-apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Inter', system-ui, sans-serif"
    fontSize: "0.6875rem"
    fontWeight: 500
  micro:
    fontFamily: "-apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Inter', system-ui, sans-serif"
    fontSize: "0.625rem"
    fontWeight: 600
rounded:
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "24px"
  full: "9999px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "16px"
  lg: "24px"
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "#ffffff"
    rounded: "{rounded.xl}"
    padding: "12px 24px"
  button-secondary:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.xl}"
    padding: "12px 20px"
  card:
    backgroundColor: "{colors.surface-card}"
    rounded: "{rounded.xl}"
    padding: "20px"
---

## Overview

NOC - System mengadopsi bahasa visual modern ala **Apple HIG / iOS Minimalist** dengan latar belakang abu-abu terang bersih (`#f5f5f7`), kontainer kartu putih murni (`#ffffff`), border halus (`#d2d2d7`), tipografi SF Pro/Inter, serta ergonomi sentuh standar mobile (target sentuh minimum 48dp).

## Colors

- **Primary Brand:** Apple Blue (`#0071e3`), Hover (`#0077ed`) untuk tombol aksi utama dan indikator aktif.
- **Surface & Backgrounds:**
  - Background Utama: `#f5f5f7`
  - Container / Card: `#ffffff` dengan border halus `rgba(0,0,0,0.06)` dan shadow iOS modal
  - Input Fields: `#f5f5f7` dengan focus ring Apple Blue
  - Header & Navigation: `rgba(255, 255, 255, 0.8)` dengan `backdrop-blur-xl`
- **Typography:**
  - Teks Utama: `#1d1d1f`
  - Teks Sekunder & Caption: `#86868b`
- **Status & Feedback Signals:**
  - **Online / Reply / Healthy:** Emerald (`#10b981`)
  - **Warning / Loading:** Amber (`#f59e0b`)
  - **Error / RTO / Offline:** Rose (`#ef4444`)

## Typography

- Font Interface: System Sans-Serif (`-apple-system`, `SF Pro`, `Inter`, `system-ui`).
- Font Angka & Telemetri: Monospace (`SF Mono`, `JetBrains Mono`, `ui-monospace`) untuk IP address, port, latensi, dan kredensial agar angka tidak bergeser saat nilai berubah.

## Layout & Viewport

- Format Mobile-First:
  - Fixed viewport anti-overscroll pada Chrome mobile (`100%` height & fixed body lock).
  - Bottom bar navigation setinggi 56dp dengan safe area padding (`env(safe-area-inset-bottom)`).
  - Floating Action Button (FAB) melayang di atas navigation bar.
- Jarak antar elemen terstruktur dalam kelipatan 4dp/8dp.

## Shapes & Radii

- Radius Border: `24px` - `28px` (rounded-3xl) untuk modal dan kartu; `16px` (rounded-2xl) untuk field input dan tombol; `9999px` (rounded-full) untuk badges, chips, checklist, dan FAB.

## Touch Targets

- Semua elemen interaktif (tombol, tab bottom bar, checklist pemilihan router, FAB, aksi edit/hapus) memiliki area sentuh minimum **48×48 dp**.
