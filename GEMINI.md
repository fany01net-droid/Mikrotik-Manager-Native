# Aturan Wajib Proyek: FNet MikroTik Monitor (Flutter Material 3)

Dokumen ini adalah **aturan utama & wajib** yang harus dibaca dan ditaati oleh semua AI Agent pada setiap prompt/sesi tanpa pengecualian.

---

## 1. Komponen Wajib Material 3 (M3) Murni Bawaan Flutter (Dart)
- **100% Bawaan Flutter Material 3:** Seluruh UI wajib dibangun hanya menggunakan widget resmi bawaan dari `package:flutter/material.dart` dengan tema `ThemeData(useMaterial3: true)`.
- **DILARANG KERAS MENGGUNAKAN CUSTOM COMPONENT:**
  - Jangan membuat custom widget/komponen styling buatan sendiri jika sudah ada padanan resminya di Flutter Material 3.
  - Jangan menggunakan library UI custom pihak ketiga yang bertentangan dengan standar M3.
- **Komponen Standar yang Wajib Digunakan:**
  - **App Bar & Header:** `AppBar`, `SliverAppBar`.
  - **Containers & Cards:** `Card` (elevated, filled, outlined), `Container` dengan batas wajar.
  - **Buttons:** `FilledButton`, `FilledButton.tonal`, `ElevatedButton`, `OutlinedButton`, `TextButton`, `IconButton`, `FloatingActionButton`.
  - **Form & Input:** `TextFormField`, `TextField`, `InputDecoration`, `Switch`, `Checkbox`, `RadioListTile`.
  - **Navigation:** `NavigationBar`, `NavigationRail`, `Drawer`, `TabBar`.
  - **Feedback & Dialog:** `SnackBar`, `AlertDialog`, `showModalBottomSheet`.
  - **List & Data:** `ListTile`, `Divider`, `ListView`, `SingleChildScrollView`.
  - **Indikator & Status:** `CircularProgressIndicator`, `LinearProgressIndicator`, `Badge`, `Chip`.

---

## 2. Larangan Push ke Git
- **JANGAN PUSH KE GIT SEBELUM DISURUH:**
  - Dilarang keras menjalankan `git push` ke remote repository dalam kondisi apa pun sebelum pengguna memberikan perintah eksplisit (misal: *"push ke git"*).
  - Hindari commit otomatis tanpa persetujuan pengguna.

---

## 3. Jalankan Live Preview di Web
- **Fokus Preview:** Seluruh pengujian tampilan dan verifikasi fitur wajib dijalankan melalui **Web Preview**.
- **Akses Jaringan Lokal:** Server web berjalan pada host `0.0.0.0` (port `5173`) agar dapat langsung diakses melalui browser smartphone maupun desktop dalam satu jaringan WiFi.
- **Hot Reload / Refresh:** Pastikan hasil build web terbaru (`build/web`) selalu diperbarui dan disajikan secara aktif.

---

## 4. Larangan Build / Compile APK
- **JANGAN BUILD APK SEBELUM DISURUH:**
  - Dilarang keras menjalankan perintah compile APK (seperti `flutter build apk`, `./gradlew assembleRelease`, `assembleDebug`, atau build Capacitor lama) sebelum ada instruksi eksplisit dari pengguna.
  - Waktu dan sumber daya difokuskan pada penyempurnaan UI & logika via web preview terlebih dahulu.

---

## 5. Standar Autentikasi & Respon UI
- **Kredensial Default:**
  - Username: `superadmin`
  - Password: `ihwan`
  - Jangan gunakan atau masukkan user dummy lain (seperti `ihwan / 1`).
- **Respon Notifikasi Bersih:**
  - Notifikasi kegagalan login atau validasi wajib menggunakan `SnackBar` standar Material 3 yang lugas (contoh: *"Username atau password salah"*).
  - Dilarang menambahkan pesan tambahan, opini, atau improvisasi di luar instruksi.
