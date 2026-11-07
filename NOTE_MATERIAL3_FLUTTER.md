# Panduan Standar Komponen Flutter Material 3 (M3)
## FNet MikroTik Monitor

Dokumen ini adalah acuan resmi (**Design & Implementation Guideline**) untuk seluruh komponen antarmuka (UI) dalam build Flutter aplikasi **FNet MikroTik Monitor**. Semua komponen wajib mematuhi standar **Material Design 3 (Material You / M3)** yang diintegrasikan dengan identitas visual **Dark & Light NOC (Network Operations Center)**.

---

## 1. Fondasi Material 3 di Flutter

Material 3 di Flutter berpusat pada sistem pewarnaan dinamis, elevasi berbasis saturasi warna (*tonal elevation*), serta bentuk sudut yang lebih organik (*rounded surfaces*).

### A. Konfigurasi `ThemeData` Global
Di `lib/theme/fnet_theme.dart`, pastikan:
```dart
ThemeData(
  useMaterial3: true, // Wajib diaktifkan
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF00639B), // Seed Brand MikroTik Blue
    brightness: isDark ? Brightness.dark : Brightness.light,
  ),
  // Konfigurasi tema per-komponen di bawah...
)
```

### B. Hirarki Warna M3 (ColorScheme Tokens)
Jangan pernah menggunakan `Colors.black`, `Colors.white`, atau `Colors.blue` secara *hardcoded*. Gunakan token warna semantik dari `Theme.of(context).colorScheme`:

| Token M3 | Peruntukan di Aplikasi FNet |
| :--- | :--- |
| `primary` | Aksi utama, tombol simpan/login, indikator tab aktif |
| `onPrimary` | Teks/ikon di atas permukaan `primary` |
| `primaryContainer` | Aksen sekunder dengan kontras lembut, chip aktif, filter aktif |
| `onPrimaryContainer` | Teks/ikon di atas `primaryContainer` |
| `surface` | Latar belakang layar / scaffold |
| `surfaceContainerLow` | Latar kartu / card elevasi rendah |
| `surfaceContainer` | Kontainer kartu standar (Hotspot, Interface, DHCP) |
| `surfaceContainerHigh` | Dialog modal, bottom sheet, popup menu |
| `outline` / `outlineVariant`| Border kartu, garis pembatas, divider antar interface |
| `error` / `onError` | Status link down, autentikasi gagal, CPU kritis |

---

## 2. Peta Komponen: Material 2 vs Material 3

Setiap developer dilarang menggunakan komponen legacy (Material 2). Gunakan ekuivalen Material 3 berikut:

| Komponen | ❌ JANGAN GUNAKAN (Legacy / M2) | ✅ WAJIB GUNAKAN (Material 3) |
| :--- | :--- | :--- |
| **Navigasi Bawah** | `BottomNavigationBar` | `NavigationBar` + `NavigationDestination` |
| **Navigasi Samping** | `Drawer` klasik saja | `NavigationRail` (Tablet/Web) atau `NavigationDrawer` |
| **Header Layar** | `AppBar(elevation: 4)` | `AppBar` M3 (`scrolledUnderElevation`, `centerTitle`) |
| **Tombol Utama** | `RaisedButton` / `ElevatedButton` polos | `FilledButton` |
| **Tombol Sekunder**| Button dengan background kaku | `FilledButton.tonal` |
| **Tombol Garis** | `OutlineButton` (deprecated) | `OutlinedButton` |
| **Tombol Teks** | `FlatButton` (deprecated) | `TextButton` |
| **Pilihan Tab/Mode**| `ToggleButtons` / `TabBar` kaku | `SegmentedButton<T>` |
| **Input Dropdown** | `DropdownButtonFormField` | `DropdownMenu<T>` |
| **Input Teks** | `TextField` tanpa spesifikasi M3 | `TextField` dengan `OutlineInputBorder` (radius 12–16) |
| **Sakelar (Switch)**| Switch kecil M2 | `Switch` M3 dengan `thumbIcon` |
| **Kartu Kontainer**| `Card(elevation: 4, shadowColor: ...)` | `Card.filled` atau `Card.outlined` |
| **Status / Filter**| Badge buatan sendiri | `FilterChip`, `ChoiceChip`, `Badge` widget |
| **Bottom Sheet** | Modal tanpa pegangan geser | `showModalBottomSheet(showDragHandle: true)` |
| **Dialog Pop-up** | `AlertDialog` dengan sudut tajam | `AlertDialog` M3 (`borderRadius: BorderRadius.circular(28)`) |
| **Progress Bar** | Progress dengan ujung lancip | `LinearProgressIndicator(strokeCap: StrokeCap.round)` |

---

## 3. Implementasi Detail Setiap Komponen

### 3.1. Navigasi & Shell Aplikasi

#### A. `NavigationBar` (Bottom Navigation)
- Gunakan `NavigationBar` bawaan M3.
- Menggunakan `destinations: [NavigationDestination(...)]`.
- **Tinggi standar:** 80dp (secara otomatis memberi area sentuh yang lega dan nyaman di jempol).
- **Indikator pil:** Berbentuk kapsul otomatis melingkari ikon terpilih.

```dart
NavigationBar(
  selectedIndex: _selectedIndex,
  onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
  destinations: const [
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: 'Beranda',
    ),
    NavigationDestination(
      icon: Icon(Icons.wifi_outlined),
      selectedIcon: Icon(Icons.wifi),
      label: 'Hotspot',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: 'Pengaturan',
    ),
  ],
)
```

#### B. `AppBar`
- M3 menggunakan `scrolledUnderElevation` (default 3.0), di mana AppBar akan secara otomatis berganti warna tonalnya saat konten di bawahnya di-scroll, tanpa garis shadow hitam tajam.
- Gunakan `titleLarge` untuk judul dan `IconButton` standar M3 untuk aksi.

```dart
AppBar(
  title: Text(
    'FNet MikroTik Monitor',
    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
  ),
  actions: [
    IconButton(
      icon: const Icon(Icons.refresh),
      tooltip: 'Segarkan Data',
      onPressed: _refreshData,
    ),
  ],
)
```

---

### 3.2. Ragam Tombol (Buttons)

M3 membagi tombol berdasarkan hirarki penekanan visual (*emphasis*):

1. **High Emphasis (Aksi Utama): `FilledButton`**
   - Digunakan untuk: "Simpan Router", "Login", "Tambah User Hotspot".
   ```dart
   FilledButton.icon(
     onPressed: _submit,
     icon: const Icon(Icons.save),
     label: const Text('Simpan Konfigurasi'),
     style: FilledButton.styleFrom(
       minimumSize: const Size(double.infinity, 48), // Ergonomi 48dp
     ),
   )
   ```

2. **Medium-High Emphasis (Aksi Pendukung Kuat): `FilledButton.tonal`**
   - Digunakan untuk: "Test Koneksi", "Quick Ping", "Reboot Router".
   ```dart
   FilledButton.tonalIcon(
     onPressed: _testLatency,
     icon: const Icon(Icons.network_ping),
     label: const Text('Uji Koneksi'),
   )
   ```

3. **Medium Emphasis (Aksi Alternatif): `OutlinedButton`**
   - Digunakan untuk: "Batal", "Export Log", "Edit Profile".
   ```dart
   OutlinedButton(
     onPressed: () => Navigator.pop(context),
     child: const Text('Batal'),
   )
   ```

4. **Low Emphasis: `TextButton`**
   - Digunakan untuk tombol teks di dalam dialog atau footer.
   ```dart
   TextButton(
     onPressed: _openHelp,
     child: const Text('Bantuan'),
   )
   ```

5. **Aksi Melayang: `FloatingActionButton` (FAB)**
   - FAB M3 berbentuk **persegi membulat** (bukan lingkaran M2).
   - Radius sudut: 16dp.
   ```dart
   FloatingActionButton.extended(
     onPressed: _showAddModal,
     icon: const Icon(Icons.add),
     label: const Text('Tambah User'),
   )
   ```

6. **Pemilih Multi-Opsi: `SegmentedButton<T>`**
   - Menggantikan switch tab kaku untuk pemilihan interval (1s, 5s, 15s) atau filter interface (All, Running, Disabled).
   ```dart
   SegmentedButton<String>(
     segments: const [
       ButtonSegment(value: 'all', label: Text('Semua')),
       ButtonSegment(value: 'running', label: Text('Aktif')),
       ButtonSegment(value: 'down', label: Text('Mati')),
     ],
     selected: {_selectedFilter},
     onSelectionChanged: (newSelection) {
       setState(() => _selectedFilter = newSelection.first);
     },
   )
   ```

---

### 3.3. Formulir & Kontrol Masukan (Input & Controls)

#### A. `TextField` & `TextFormField`
- Terapkan `InputDecoration` dengan border `OutlineInputBorder` (radius 12dp-16dp).
- Sediakan `prefixIcon` dan `suffixIcon` yang proporsional.
- Jangan gunakan underline border jadul.

```dart
TextFormField(
  controller: _hostController,
  keyboardType: TextInputType.url,
  decoration: InputDecoration(
    labelText: 'IP / Host MikroTik',
    hintText: '192.168.88.1:8728',
    prefixIcon: const Icon(Icons.router_outlined),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    filled: true,
  ),
  style: FNetTheme.monoStyle(), // Font monospace untuk IP
)
```

#### B. `DropdownMenu<T>`
- M3 memperkenalkan `DropdownMenu<T>` resmi yang menggantikan `DropdownButtonFormField`.
- Memberikan dukungan pencarian terintegrasi, styling M3 terpadu, dan popup surface yang rapi.

```dart
DropdownMenu<String>(
  initialSelection: _selectedInterface,
  label: const Text('Pilih Interface'),
  leadingIcon: const Icon(Icons.settings_ethernet),
  dropdownMenuEntries: _interfaces.map((iface) {
    return DropdownMenuEntry(value: iface.name, label: iface.name);
  }).toList(),
  onSelected: (val) {
    if (val != null) setState(() => _selectedInterface = val);
  },
)
```

#### C. `Switch` (Material 3 Toggle)
- Switch M3 lebih lebar dengan thumb yang membesar saat aktif serta mendukung ikon status:

```dart
Switch(
  value: _autoRefresh,
  thumbIcon: WidgetStateProperty.resolveWith<Icon?>((states) {
    if (states.contains(WidgetState.selected)) {
      return const Icon(Icons.check, size: 16);
    }
    return const Icon(Icons.close, size: 16);
  }),
  onChanged: (val) => setState(() => _autoRefresh = val),
)
```

---

### 3.4. Kartu & Elevasi (Cards & Surfaces)

M3 tidak mengandalkan bayangan hitam pekat (*drop shadows*), melainkan **warna permukaan bertingkat (*Surface Container*)** dan border tipis:

1. **`Card.outlined` (Rekomendasi Utama untuk Daftar Item)**
   - Sangat cocok untuk daftar antarmuka ether/wlan, daftar user hotspot, dan sesi PPPoE.
   ```dart
   Card.outlined(
     shape: RoundedRectangleBorder(
       borderRadius: BorderRadius.circular(16),
       side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
     ),
     child: Padding(
       padding: const EdgeInsets.all(16),
       child: Column(...),
     ),
   )
   ```

2. **`Card.filled` (Untuk Ringkasan Metrik / Widget Header)**
   - Menggunakan warna latar `surfaceContainer` atau `surfaceContainerHigh`.
   ```dart
   Card.filled(
     color: Theme.of(context).colorScheme.surfaceContainerHighest,
     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
     child: ...,
   )
   ```

---

### 3.5. Lembar & Dialog (Sheets & Dialogs)

#### A. `showModalBottomSheet`
- Wajib memiliki **drag handle** (`showDragHandle: true`).
- Sudut atas membulat 28dp (`BorderRadius.vertical(top: Radius.circular(28))`).
- Gunakan `isScrollControlled: true` untuk form input agar tidak terhalang keyboard virtual.

```dart
showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  builder: (ctx) => Padding(
    padding: EdgeInsets.only(
      bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
      left: 16,
      right: 16,
      top: 8,
    ),
    child: const AddRouterModalSheet(),
  ),
);
```

#### B. `AlertDialog`
- Sudut radius standar M3 adalah **28dp**.
- Ikon opsional di bagian atas judul (`icon: Icon(...)`).

```dart
AlertDialog(
  icon: const Icon(Icons.warning_amber_rounded, size: 36, color: FNetTheme.rose),
  title: const Text('Hapus User Hotspot?'),
  content: const Text('Tindakan ini akan memutuskan koneksi pengguna segera.'),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
  actions: [
    TextButton(
      onPressed: () => Navigator.pop(context),
      child: const Text('Batal'),
    ),
    FilledButton(
      style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
      onPressed: _confirmDelete,
      child: const Text('Hapus'),
    ),
  ],
)
```

---

### 3.6. Indikator, Chip, & Badge

#### A. Indikator Progres (*Rounded Caps*)
- Semua `LinearProgressIndicator` wajib memiliki `strokeCap: StrokeCap.round` dan ketebalan minimal 8dp.

```dart
ClipRRect(
  borderRadius: BorderRadius.circular(4),
  child: LinearProgressIndicator(
    value: cpuLoad / 100.0,
    minHeight: 8,
    strokeCap: StrokeCap.round,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
    color: cpuLoad > 85 ? FNetTheme.rose : (cpuLoad > 60 ? FNetTheme.amber : FNetTheme.emerald),
  ),
)
```

#### B. `FilterChip` & `ChoiceChip`
- Gunakan chip bawaan M3 untuk filter daftar, status running, atau pemilihan profil.

```dart
FilterChip(
  label: const Text('Only Active'),
  selected: _onlyActive,
  onSelected: (val) => setState(() => _onlyActive = val),
)
```

#### C. `Badge` Widget
- Gunakan widget `Badge` M3 pada ikon lonceng notifikasi atau tab bar:

```dart
Badge(
  label: Text('$_alertCount'),
  isLabelVisible: _alertCount > 0,
  child: const Icon(Icons.notifications_outlined),
)
```

---

## 4. Standar Khusus FNet MikroTik (NOC Identity)

M3 fleksibel untuk mengakomodasi identitas khusus FNet:

1. **Warna Status Fungsional Jaringan:**
   - **Emerald (`#10B981`):** Online, running, ping <500ms.
   - **Amber (`#F59E0B`):** Warning, load 60–85%, ping 500–2000ms.
   - **Rose (`#EF4444`):** Link down, error, load >85%, RTO.
   - **Sky (`#0284C7`):** Aksen sekunder telemetri link data.

2. **Tipografi Angka Telemetri:**
   - Semua angka telemetri (IP Address, MAC, Uptime, Tx/Rx, Bps, Latensi) **wajib menggunakan font monospace** (`FNetTheme.monoStyle(...)`) agar angka tidak bergeser saat nilainya di-refresh secara realtime.

3. **Ergonomi Sentuh Mobile (Aturan Minimum 48×48 dp):**
   - Semua elemen yang dapat diklik (tombol, ikon filter, switch, checklist router) harus memiliki bounding box minimal **48×48 dp** (`minimumSize: const Size(48, 48)`).

4. **Penanganan Safe Area & Virtual Keyboard:**
   - Bungkus konten modal dengan `SafeArea` dan `MediaQuery.of(context).viewInsets.bottom` agar input tidak terhalang keyboard.
   - Pastikan `NavigationBar` tidak tertekan saat virtual keyboard terbuka.

---

## 5. Ringkasan Checklist Implementasi (Do's & Don'ts)

| Kategori | Wajib Dilakukan (DO) | Dilarang Keras (DON'T) |
| :--- | :--- | :--- |
| **Theme** | Setel `useMaterial3: true` di `ThemeData`. | Menggunakan `useMaterial3: false` atau theme M2 default. |
| **Warna** | Ambil dari `Theme.of(context).colorScheme`. | Hardcode warna seperti `Colors.blue[700]`. |
| **Navigasi** | Gunakan `NavigationBar` M3 (tinggi 80dp). | Menggunakan `BottomNavigationBar` kuno. |
| **Aksi Form**| Gunakan `FilledButton` untuk aksi submit primer. | Menggunakan `ElevatedButton` kusam tanpa kontras M3. |
| **Dropdown** | Gunakan `DropdownMenu<T>` M3. | Menggunakan `DropdownButtonFormField` lama. |
| **Dialog** | Gunakan `borderRadius: BorderRadius.circular(28)`. | Dialog kotak kaku bersudut tajam. |
| **Sudut Sudut**| Ikuti skala M3 (sm: 8dp, md: 12dp, lg: 16dp, xl: 28dp).| Nilai radius sembarangan (misal: 3dp, 7dp, 33dp). |
| **Angka** | Gunakan `FNetTheme.monoStyle()` untuk data jaringan. | Memakai font proporsional standar yang goyang saat reload. |
| **Ukuran** | Area sentuh minimum 48×48 dp untuk semua tombol. | Ikon aksi terlalu kecil (<36dp) yang sulit ditekan jempol. |
