# Riwayat Percakapan & Pengembangan (Development History)
## FNet MikroTik Monitor (Flutter Material 3 Native)

Dokumen ini mencatat riwayat percakapan, keputusan arsitektur, dan evolusi pengembangan proyek **FNet MikroTik Monitor** berbasis Flutter murni dengan Material Design 3 (M3).

---

## 📌 Ringkasan Milestone Pengembangan

### 1. Kustomisasi Dashboard Dinamis (9 Widgets Modular)
- **Komponen**: [`lib/screens/beranda_screen.dart`](lib/screens/beranda_screen.dart)
- **Fitur Kunci**:
  - **Modularitas Penuh**: Setiap widget dapat diaktifkan/dinonaktifkan dan diatur urutannya secara interaktif (*drag & drop*) melalui modal bottom sheet pengaturan layout.
  - **Variasi Tampilan (*Style Variations*)**: Setiap widget memiliki beberapa opsi gaya visual (misal: Mini Cards, List View, Minimal Chip, LED Switch Grid, dll.).
  - **Menu Tindakan Cepat (More Vert / Titik Tiga)**:
    - *Edit Tata Letak & Widget*: Pengaturan urutan dan visibilitas widget.
    - *Tampilkan Semua Widget*: Mengaktifkan seluruh widget sekaligus.
    - *Uji Respon Koneksi*: Pengujian latensi REST API MikroTik secara instan.
    - *Reset Tata Letak Default*: Mengembalikan urutan dan konfigurasi bawaan.

#### Daftar 9 Widget Dashboard:
1. **Ringkasan Klien & Layanan (`clients_summary`)**:
   - Menghitung real-time total PPPoE Aktif, Hotspot Aktif, dan DHCP Leases.
   - Tap langsung membuka tab terkait (*deep navigation*).
   - Opsi: *3 Mini Cards*, *Daftar Layanan*, *Chip Ringkas*.
2. **Status Interface & Port (`interfaces_status`)**:
   - Visualisasi switch port (UP / DOWN / NO LINK).
   - Tap port langsung beralih memantau grafik trafik interface yang dipilih.
   - Opsi: *Grid Port Switch (LED)*, *Daftar Port Detail*, *Progress Rasio*.
3. **Spesifikasi Perangkat Keras (`hardware_specs`)**:
   - Model Board, CPU Architecture, Core/MHz, Bad Blocks, RouterOS Platform.
   - Opsi: *Grid Kartu*, *Daftar Rincian*, *Minimalis*.
4. **Aksi Cepat & Pintasan (`quick_actions`)**:
   - Segarkan Data, Uji Respon Latensi, Salin Host IP, dan Atur Widget.
   - Opsi: *Tombol Tonal M3*, *Pill Chips*.
5. **Uptime & Jam Aktif (`uptime_clock`)**:
   - Menampilkan lama waktu aktif router dengan banner gradien atau tile ringkas.
6. **Beban CPU & RAM (`system_resource`)**:
   - Data real-time REST API MikroTik dengan visualisasi Gauge M3, Progress Bar, atau Kartu Ringkas.
7. **Suhu & Voltase Sensor (`health_sensors`)**:
   - Metrik sensor hardware terkalibrasi dengan status tegangan (*Normal*, *Stabil*, *Overvolt*, *Undervolt*).
8. **Grafik Trafik Jaringan Real-Time (`traffic_chart`)**:
   - Visualisasi smooth line chart RX & TX dengan rate Mbps/kbps dan indikator puncak.
9. **Identitas Router & Header (`router_identity`)**:
   - Nama router, model, IP host, status koneksi aktif, dan menu aksi cepat.

---

### 2. Standar Material 3 Expressive (M3E) & Loading Indicators
- **Komponen**: [`lib/widgets/loading_indicator_m3e.dart`](lib/widgets/loading_indicator_m3e.dart), [`lib/theme/fnet_theme.dart`](lib/theme/fnet_theme.dart)
- **Implementasi**:
  - Penggantian seluruh loading spinner legacy dengan indikator Material 3 Expressive.
  - Varian loading yang konsisten untuk: inline spinner, full-page loading, modal dialog loading, dan button loading state.
  - Penerapan token semantik 100% dari `Theme.of(context).colorScheme` tanpa *hardcoded colors*.

---

### 3. Arsitektur 5 Tab Utama & On-Demand Data Fetching
- **Komponen**:
  - **Beranda (Dashboard)**: Monitoring komprehensif metrik router dan widget interaktif.
  - **PPPoE**: Manajemen PPPoE Active Sessions, Secret Users, dan Profile.
  - **Hotspot**: Manajemen Hotspot Active Users, Hotspot Users/Vouchers, dan Server Profiles.
  - **DHCP Server**: Pemantauan DHCP Leases, Server Binding, dan IP Pool.
  - **Pengaturan (Settings)**: Multi-router manager, tema gelap/terang, dan konfigurasi API.
- **On-Demand Loading**: Setiap tab hanya melakukan pemanggilan API saat tab aktif dibuka, mencegah overhead jaringan dan baterai.
- **Infinite Scrolling & Lazy Loading**: Penanganan dataset besar pada daftar user/voucher hotspot dan DHCP leases.

---

### 4. Sistem Notifikasi Adaptif (Toast / SnackBar M3)
- **Komponen**: [`lib/screens/main_scaffold.dart`](lib/screens/main_scaffold.dart), [`lib/widgets/toast_banner.dart`](lib/widgets/toast_banner.dart)
- **Perilaku**:
  - Posisi notifikasi adaptif: ditampilkan di bagian atas saat drawer navigasi terbuka, dan di bagian bawah layar saat drawer tertutup agar tidak menutupi kontrol antarmuka.
  - Desain floating dengan padding aman serta skema warna kontras semantik (Error, Success, Info, Warning).

---

### 5. CORS Relay Server & Web Live Preview
- **Komponen**: [`serve.py`](serve.py)
- **Fungsi**:
  - Web server lokal di host `0.0.0.0:5173` untuk pengujian simultan desktop dan smartphone dalam satu jaringan WiFi.
  - Menyediakan proxy relay transparan untuk bypass restriksi CORS browser saat berkomunikasi langsung dengan REST API RouterOS MikroTik.
  - Menyajikan kompilasi build web Flutter (`build/web`) secara otomatis.

---

## 📜 Log Riwayat Git Commit

```text
06e0198 feat: add dynamic customizable dashboard widgets, real CPU/RAM metrics, and CORS relay server
d60ed23 feat: replace all loading indicators with Material 3 Expressive (M3E), refine router connection test feedback, and polish UI
812bd90 feat: implement on-demand tab loading with M3 progress indicators, constrained drawer heights, and pure M3 semantic colors
b3e0a77 feat: complete Material 3 5-tabs app, loading indicators, theme-matched top/bottom SnackBar, and infinite scroll lazy loading
a1feb1e feat: implement top/bottom notification positioning, standardize router list style, and auto-navigate to dashboard with M3 loading
db3b351 refactor: isolate full native android dart flutter and fix drawer snackbar visibility
353de37 chore: remove legacy capacitor react files, retain pure flutter project
bd49547 feat: migrate to Flutter Material 3 native with live traffic chart and CI/CD workflow
```

---

## 🔒 Aturan & Kebijakan Pengembangan (Rules Compliance)
1. **Material 3 Murni (100% Flutter Native)**: Seluruh UI menggunakan widget resmi dari `package:flutter/material.dart` dengan `useMaterial3: true`.
2. **Kredensial Default Validasi**: Menggunakan akun resmi `superadmin` / `ihwan`.
3. **Pengujian Web Preview**: Seluruh verifikasi tampilan difokuskan pada browser live preview (`0.0.0.0:5173`).
4. **Git Push**: Hanya dieksekusi setelah mendapatkan perintah eksplisit dari pengguna.
