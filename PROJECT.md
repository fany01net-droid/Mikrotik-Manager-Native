# Project: FNet MikroTik Monitor — Facebook App Visual Shell

## Architecture
FNet MikroTik Monitor is a mobile-first responsive web application and Progressive Web App (PWA) designed for MikroTik RouterOS v7 network administration.
The UI architecture is built on React 19, TypeScript, Vite, Tailwind CSS v4, and Radix UI primitives (shadcn/ui style).

### Theming & Visual Shell Architecture
- **Dual-Theme Engine**:
  - System/user selectable theme stored in `localStorage` under `fnet_theme` (`light` or `dark`).
  - Active theme dynamically applied via `.dark` class on `document.documentElement` (synced with `<meta name="theme-color">` and `color-scheme`).
  - **Facebook Light Mode**:
    - Surface / Background: `#F0F2F5`
    - Card Container: `#FFFFFF`
    - Card Border: `#CED0D4` (subtle border)
    - Primary Accent / Header Blue: Facebook Blue `#1877F2`
    - Typography: `#050505` primary text, `#65676B` secondary text
  - **Facebook Dark Mode**:
    - Surface / Background: `#18191A`
    - Card Container: `#242526`
    - Card Border: `#3A3B3C`
    - Primary Accent / Active Blue: Facebook Light Blue `#2D88FF`
    - Typography: `#E4E6EB` primary text, `#B0B3B8` secondary text
- **Facebook Visual Shell**:
  - **Top App Bar**: FNet brand emblem, active router indicator (round avatar with real-time status dot: Emerald <500ms, Amber 500-2000ms, Rose >2000ms), curved search pill (`rounded-full`), Sun/Moon theme toggle button (min 48×48 dp), and refresh/connection action buttons.
  - **Navigation Bar**: Bottom navigation with iconic tabs (Vitals, Interfaces, DHCP, PPPoE, Setup), Facebook Blue active indicator underline/pill, touch targets min 48×48 dp, safe area insets (`env(safe-area-inset-bottom)`), and auto-hiding when virtual keyboard is active.
  - **Card Containers**: Standardized `<Card>` primitive using semantic tokens (`bg-card`, `border-border`, `text-card-foreground`) with subtle elevation and rounded corners.

### Ergonomics & Mobile Ergonomics
- Viewport fit without horizontal scrolling (`overflow-x-hidden`) on mobile screens starting at 320px/360px.
- Touch target minimum 48×48 dp (`min-h-[48px]`, `min-w-[48px]`) for all interactive elements (buttons, inputs, tabs, presets, chips).
- Safe area insets support (`env(safe-area-inset-top)`, `env(safe-area-inset-bottom)`).

### Purified Technical Terminology & Network Domain Logic
- STRICT ZERO social media terms (no Like, Share, Post, Comment, Friends, Story, Timeline, etc.).
- 100% pure MikroTik RouterOS v7 configuration & monitoring terminology (CPU Load, RAM, Storage, Uptime, Latensi, Uji Koneksi, Simpan Profil, Perpanjang (+30 Hari), Isolir, Putuskan Sesi, Segarkan Data, Catatan Pelanggan).
- 100% preservation of REST API RouterOS v7 endpoints, Vite `/api-proxy`, multi-profile localStorage persistence, DHCP lease ONT detection, and PPPoE secret/active management with `exp: YYYY-MM-DD` comment parsing.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Dual-Theme Engine (Light & Dark) | CSS variables in `index.css`, `themeService.ts`, removal of hardcoded dark wrappers in `main.tsx` and `index.html`, `localStorage` persistence | M1 | ORIGINAL_REQUEST §R1 |
| 2 | Facebook Top App Bar | FNet brand emblem, round avatar router indicator with status dot, curved search pill, 48dp Sun/Moon toggle, refresh & connection controls | M1 | ORIGINAL_REQUEST §R1 |
| 3 | Facebook Navigation Bar | Bottom navigation with iconic tabs, Facebook Blue active indicator, safe-area insets, and keyboard auto-hide | M1 | ORIGINAL_REQUEST §R1, §R2 |
| 4 | Facebook Cards & Semantic Tokens | Refactor `card.tsx` and UI primitives to use semantic tokens (`bg-card`, `border-border`) rendering clean white cards on #F0F2F5 (light) and dark cards on #18191A (dark) | M2 | ORIGINAL_REQUEST §R1 |
| 5 | Views Refactoring & Zinc Cleanup | Remove hardcoded `bg-zinc-950` / `border-zinc-800` from all 5 views (`VitalsView`, `InterfacesView`, `DhcpView`, `PppoeView`, `SetupConnection`) | M2 | ORIGINAL_REQUEST §R1 |
| 6 | Mobile Ergonomics & 48dp Touch Targets | Elevate undersized buttons (<48dp) in `SetupConnection.tsx`, `InterfacesView.tsx`, `VitalsView.tsx` to satisfy min 48×48 dp standard | M2 | ORIGINAL_REQUEST §R2 |
| 7 | Zero Social Media Terms Audit | Verify 100% pure RouterOS v7 terminology and strict absence of social media terms (e.g. ensure UI copy uses "Catatan Pelanggan" instead of social terms) | M2 | ORIGINAL_REQUEST §R3 |
| 8 | Network Domain Logic Preservation | Maintain 100% integrity of RouterOS REST calls, multi-profile, DHCP ONT detection, and PPPoE secret/active session logic | M2 | ORIGINAL_REQUEST §R4 |
| 9 | Comprehensive Build & Test Gate | Verify all 43 tests pass (`npm test`), `npm run build` succeeds with 0 errors, Impeccable check passes, zero APK build executions | M3 | ORIGINAL_REQUEST Acceptance Criteria |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | M1: Dual-Theme Engine & Facebook Shell | `src/index.css`, `src/lib/themeService.ts`, `src/main.tsx`, `index.html`, `src/components/TopAppBar.tsx`, `src/components/BottomNavBar.tsx`, `src/App.tsx` | none | DONE |
| 2 | M2: Facebook Cards, Views Refactor & Ergonomics | `src/components/ui/card.tsx`, `src/components/VitalsView.tsx`, `src/components/InterfacesView.tsx`, `src/components/DhcpView.tsx`, `src/components/PppoeView.tsx`, `src/components/SetupConnection.tsx` | M1 | DONE |
| 3 | M3: Verification & Integrity Gate | Full test suite (43 unit tests passing via `npm test`), production build (`npm run build`), Impeccable design check, zero social terms audit, zero APK builds | M1, M2 | DONE |

## Interface Contracts
### `themeService` ↔ React UI Components
- `getTheme(): 'light' | 'dark'`
- `setTheme(theme: 'light' | 'dark'): void`
- `toggleTheme(): 'light' | 'dark'`
- `initTheme(): 'light' | 'dark'`
- Synchronization: Updates `document.documentElement.classList` (`dark` on/off), sets `localStorage.setItem('fnet_theme', theme)`, and updates `<meta name="theme-color">` (`#1877F2` or `#18191A`).

### Domain Logic Contracts (IMMUTABLE)
- `src/lib/pppoeUtils.ts`: All exports (`parseExpiryFromComment`, `extendExpiryDate`, `buildExpiryComment`, `calcExpiryDaysRemaining`, `getExpiryBadgeStatus`, `normalizeDateToIso`) must remain unchanged with identical function signatures and return types.
- `src/services/mikrotikApi.ts`: All exports (`buildBaseUrl`, `getAuthHeader`, `testConnection`, `getResource`, `getInterfaces`, `getDhcpLeases`, `getPppSecrets`, `getPppActiveSessions`, `addPppSecret`, `updatePppSecret`, `kickPppActiveSession`, etc.) must maintain identical contracts.

## Code Layout
- `src/index.css`: Global styles, Tailwind v4 design tokens, `:root` and `.dark` variables.
- `src/lib/themeService.ts`: Theme persistence and state management.
- `src/main.tsx`: Application entry point (clean semantic root wrapper).
- `index.html`: Base HTML, viewport, meta tags.
- `src/components/TopAppBar.tsx`: Facebook-style top app bar.
- `src/components/BottomNavBar.tsx`: Facebook-style bottom navigation bar.
- `src/App.tsx`: App shell, active view switching, keyboard detection, back-button handling.
- `src/components/ui/card.tsx`: Facebook card wrapper with semantic tokens.
- `src/components/VitalsView.tsx`: System vitals and resource metrics.
- `src/components/InterfacesView.tsx`: Network interface list and status.
- `src/components/DhcpView.tsx`: DHCP Server leases and 1-tap PPPoE conversion.
- `src/components/PppoeView.tsx`: PPPoE secret and active session administration.
- `src/components/SetupConnection.tsx`: Router connection settings and profile management.
