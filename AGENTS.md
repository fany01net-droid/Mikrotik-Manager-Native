# Antigravity Rules: FNet MikroTik Monitor

Aturan dan panduan pengembangan untuk proyek **FNet MikroTik Monitor**. Semua agen wajib mematuhi aturan berikut dalam setiap sesi kerja:

---

## 1. Platform & Build Target (PENTING)

- **Utamakan Web / PWA:** Aplikasi difokuskan berjalan langsung sebagai web app responsif dan Progressive Web App (PWA) di browser HP dan desktop.
- **JANGAN BUAT / COMPILE APK DULU:** Jangan menjalankan perintah compile APK (seperti `cap build android`, `npx cap run android`, atau `./gradlew assemble*`) kecuali jika pengguna secara eksplisit memintanya.
- **Akses Jaringan Lokal:** Server web Vite berjalan pada host `0.0.0.0` (port `5173` untuk dev server, `4173` untuk preview) agar dapat langsung diakses dari browser smartphone dalam satu jaringan WiFi.
- **Proxy Anti-CORS:** Untuk lingkungan web browser, komunikasi ke RouterOS REST API selalu melalui `/api-proxy` yang disediakan oleh plugin Vite di `vite.config.ts`.

---

## 2. Standar UI/UX: Mobile-Friendly & Lightweight (ala shadcn/ui)

- **Mobile-First & Sentuhan Ergonomis:**
  - Semua tombol, tab, input, dan chip interaktif wajib memiliki area sentuh minimum **48×48 dp** (`min-h-[48px]`, `min-w-[48px]`).
  - Mendukung notch dan gesture bar dengan `env(safe-area-inset-top)` dan `env(safe-area-inset-bottom)`.
  - Bottom navigation bar harus otomatis bersembunyi saat virtual keyboard aktif agar input tidak terhalang.
  - Layout wajib bebas overflow horizontal (`overflow-x-hidden`) pada layar smartphone mulai 320px/360px.
- **Lightweight (Ringan & Cepat):**
  - Ikuti arsitektur komponen **shadcn/ui** (`@radix-ui` primitives, `class-variance-authority`, `clsx`, `tailwind-merge`).
  - Hindari library visualisasi/grafik yang berat. Gunakan progress bar Tailwind, SVG murni, dan CSS gauges berkinerja tinggi.
- **Identitas Visual Dark NOC:**
  - Background utama: Deep Dark Slate (`#020617`).
  - Card & Container: `#0f172a` dengan border halus `border-slate-800/80` dan efek subtle backdrop blur.
  - Warna status fungsional:
    - **Emerald (`#10b981`):** Online, interface running, latensi rendah (<500ms).
    - **Amber (`#f59e0b`):** Warning, load sedang (60-85%), latensi sedang (500-2000ms).
    - **Rose (`#ef4444`):** Offline, link down, error otentikasi, load kritis (>85%), latensi tinggi (>2000ms).
    - **Sky (`#0284c7`):** Aksen primer, elemen fokus, tab aktif.
- **Tipografi:**
  - Font antarmuka: System Sans (`system-ui`, `-apple-system`, `Roboto`).
  - Data teknis & angka telemetri (IP, port, MAC, uptime, latensi, traffic Rx/Tx, persentase): **Wajib font monospace** (`font-mono`) agar angka tidak bergeser saat nilai berubah.

---

## 3. Komunikasi REST API MikroTik

- Target perangkat adalah **MikroTik RouterOS v7.1+** (menggunakan native `/rest/` endpoint).
- Kredensial disimpan secara lokal (`localStorage`), tidak ada pengiriman data ke server cloud pihak ketiga (Zero Cloud Dependency, privacy-first).
- Selalu tampilkan umpan balik latensi (`ms`) dan pesan troubleshooting yang jelas saat terjadi kegagalan koneksi.
