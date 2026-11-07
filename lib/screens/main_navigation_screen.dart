import 'package:flutter/material.dart';
import '../models/mikrotik_models.dart';
import '../services/storage_service.dart';
import '../services/mikrotik_api_service.dart';

class MainNavigationScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDark;
  final VoidCallback? onLogout;

  const MainNavigationScreen({
    super.key,
    required this.onToggleTheme,
    required this.isDark,
    this.onLogout,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentPageIndex = 0; // Default: Home

  final List<String> _titles = const [
    'Home',
    'Pengaturan',
  ];

  List<RouterProfile> _profiles = [StorageService.defaultProfile];
  String _activeProfileId = 'default-profile';

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final profiles = await StorageService.getProfiles();
    final activeId = await StorageService.getActiveProfileId();
    if (mounted) {
      setState(() {
        _profiles = profiles;
        _activeProfileId = activeId;
      });
    }
  }

  RouterProfile get _activeProfile {
    return _profiles.firstWhere(
      (p) => p.id == _activeProfileId,
      orElse: () => _profiles.isNotEmpty ? _profiles.first : StorageService.defaultProfile,
    );
  }

  void _handleSwitchProfile(String id) async {
    await StorageService.setActiveProfileId(id);
    if (mounted) {
      setState(() {
        _activeProfileId = id;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _activeProfile;

    final List<Widget> pages = [
      HomeContentPage(profile: active),
      SettingsContentPage(
        onToggleTheme: widget.onToggleTheme,
        isDark: widget.isDark,
        activeProfile: active,
        profiles: _profiles,
        onSwitchProfile: _handleSwitchProfile,
        onProfilesUpdated: _loadProfiles,
        onLogout: widget.onLogout,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titles[_currentPageIndex],
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: 'Ganti Tema',
            icon: Icon(
              widget.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
            onPressed: widget.onToggleTheme,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: pages[_currentPageIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentPageIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentPageIndex = index;
          });
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Pengaturan',
          ),
        ],
      ),
    );
  }
}

/// ==========================================
/// 1. HALAMAN HOME (BERANDA BERSIH)
/// 100% PURE MATERIAL 3 WIDGETS
/// ==========================================
class HomeContentPage extends StatelessWidget {
  final RouterProfile? profile;

  const HomeContentPage({super.key, this.profile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.dashboard_outlined,
                size: 36,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Beranda',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Halaman telah dibersihkan.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ==========================================
/// 2. HALAMAN PENGATURAN (SETTINGS SCREEN)
/// 100% PURE MATERIAL 3 WIDGETS
/// ==========================================
class SettingsContentPage extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDark;
  final RouterProfile? activeProfile;
  final List<RouterProfile> profiles;
  final ValueChanged<String>? onSwitchProfile;
  final VoidCallback? onProfilesUpdated;
  final VoidCallback? onLogout;

  const SettingsContentPage({
    super.key,
    required this.onToggleTheme,
    required this.isDark,
    this.activeProfile,
    this.profiles = const [],
    this.onSwitchProfile,
    this.onProfilesUpdated,
    this.onLogout,
  });

  @override
  State<SettingsContentPage> createState() => SettingsContentPageState();
}

class SettingsContentPageState extends State<SettingsContentPage> {
  bool _autoReconnect = true;
  bool _alertCpu = true;

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar dari Akun Router?'),
        content: const Text('Sesi koneksi API Mikrotik akan dihentikan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _showSnack('Berhasil keluar dari akun.');
              widget.onLogout?.call();
            },
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 6.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
          color: color,
        ),
      ),
    );
  }

  /// Drawer / Modal Bottom Sheet Edit Router (100% Material 3)
  void _showEditRouterDrawer({RouterProfile? profileToEdit, bool isAddingNew = false}) {
    final profile = profileToEdit ?? widget.activeProfile ?? StorageService.defaultProfile;
    final nameCtrl = TextEditingController(text: isAddingNew ? 'MikroTik ${widget.profiles.length + 1}' : profile.name);
    final hostCtrl = TextEditingController(text: isAddingNew ? '192.168.88.2' : profile.host);
    final portCtrl = TextEditingController(text: (isAddingNew ? 80 : profile.port).toString());
    final userCtrl = TextEditingController(text: isAddingNew ? 'admin' : profile.username);
    final passCtrl = TextEditingController(text: isAddingNew ? '' : profile.password);
    bool useHttps = isAddingNew ? false : profile.useHttps;
    bool obscurePass = true;
    bool isTesting = false;
    String? statusMessage;
    bool isStatusSuccess = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final theme = Theme.of(ctx);
          final colorScheme = theme.colorScheme;

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 4,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.router_rounded, color: colorScheme.primary),
                          const SizedBox(width: 10),
                          Text(
                            isAddingNew ? 'Tambah Profil Router' : 'Edit Profil Router',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Nama Router
                  TextFormField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Nama Router',
                      hintText: 'misal: mikrotik01',
                      prefixIcon: const Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Row: Host / IP & Port
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: hostCtrl,
                          decoration: InputDecoration(
                            labelText: 'Host / IP Router',
                            hintText: '192.168.88.1',
                            prefixIcon: const Icon(Icons.dns_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            filled: true,
                            fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: portCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Port',
                            hintText: '80',
                            prefixIcon: const Icon(Icons.tag_rounded),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            filled: true,
                            fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Switch HTTPS
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Gunakan HTTPS / SSL', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    value: useHttps,
                    onChanged: (val) {
                      setModalState(() {
                        useHttps = val;
                        if (val && portCtrl.text == '80') {
                          portCtrl.text = '443';
                        } else if (!val && portCtrl.text == '443') {
                          portCtrl.text = '80';
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 4),

                  // Username
                  TextFormField(
                    controller: userCtrl,
                    decoration: InputDecoration(
                      labelText: 'Username RouterOS',
                      hintText: 'admin',
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Password
                  TextFormField(
                    controller: passCtrl,
                    obscureText: obscurePass,
                    decoration: InputDecoration(
                      labelText: 'Password RouterOS',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setModalState(() => obscurePass = !obscurePass),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Feedback Status Card di dalam Modal Drawer (Tidak ketutupan)
                  if (statusMessage != null) ...[
                    Card(
                      elevation: 0,
                      color: isStatusSuccess
                          ? colorScheme.primaryContainer.withValues(alpha: 0.5)
                          : colorScheme.errorContainer.withValues(alpha: 0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isStatusSuccess
                              ? colorScheme.primary.withValues(alpha: 0.3)
                              : colorScheme.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            Icon(
                              isStatusSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                              size: 20,
                              color: isStatusSuccess ? colorScheme.primary : colorScheme.error,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                statusMessage!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isStatusSuccess
                                      ? colorScheme.onPrimaryContainer
                                      : colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () => setModalState(() => statusMessage = null),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Tombol Aksi 1 Baris: Tes Koneksi & Simpan
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: isTesting
                              ? null
                              : () async {
                                  final host = hostCtrl.text.trim();
                                  if (host.isEmpty) {
                                    setModalState(() {
                                      statusMessage = 'Host/IP router tidak boleh kosong.';
                                      isStatusSuccess = false;
                                    });
                                    return;
                                  }
                                  setModalState(() {
                                    isTesting = true;
                                    statusMessage = null;
                                  });

                                  final testProfile = RouterProfile(
                                    id: 'temp-test',
                                    name: nameCtrl.text.trim(),
                                    host: host,
                                    port: int.tryParse(portCtrl.text.trim()) ?? (useHttps ? 443 : 80),
                                    useHttps: useHttps,
                                    username: userCtrl.text.trim(),
                                    password: passCtrl.text,
                                    timeoutSeconds: 5,
                                  );

                                  final res = await MikrotikApiService.instance.testConnection(testProfile);

                                  setModalState(() {
                                    isTesting = false;
                                    if (res.success) {
                                      statusMessage = 'Terhubung ke router! Latensi: ${res.durationMs}ms';
                                      isStatusSuccess = true;
                                    } else {
                                      statusMessage = 'Koneksi gagal: ${res.error ?? "Tidak ada respon"}';
                                      isStatusSuccess = false;
                                    }
                                  });
                                },
                          icon: isTesting
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary),
                                )
                              : const Icon(Icons.network_check_rounded, size: 18),
                          label: Text(
                            isTesting ? 'Menguji...' : 'Tes Koneksi',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () async {
                            final name = nameCtrl.text.trim();
                            final host = hostCtrl.text.trim();
                            final port = int.tryParse(portCtrl.text.trim()) ?? (useHttps ? 443 : 80);
                            final user = userCtrl.text.trim();
                            final pass = passCtrl.text;

                            if (name.isEmpty || host.isEmpty || user.isEmpty) {
                              setModalState(() {
                                statusMessage = 'Nama, Host/IP, dan Username wajib diisi.';
                                isStatusSuccess = false;
                              });
                              return;
                            }

                            if (isAddingNew) {
                              final newId = 'router_${DateTime.now().millisecondsSinceEpoch}';
                              final newProfile = RouterProfile(
                                id: newId,
                                name: name,
                                host: host,
                                port: port,
                                useHttps: useHttps,
                                username: user,
                                password: pass,
                              );
                              Navigator.pop(ctx);
                              await StorageService.saveProfile(newProfile);
                              widget.onSwitchProfile?.call(newId);
                              widget.onProfilesUpdated?.call();
                              _showSnack('Router "$name" berhasil ditambahkan dan diaktifkan.');
                            } else {
                              final updatedProfile = RouterProfile(
                                id: profile.id,
                                name: name,
                                host: host,
                                port: port,
                                useHttps: useHttps,
                                username: user,
                                password: pass,
                              );
                              Navigator.pop(ctx);
                              await StorageService.saveProfile(updatedProfile);
                              widget.onProfilesUpdated?.call();
                              _showSnack('Profil router "$name" berhasil disimpan.');
                            }
                          },
                          icon: const Icon(Icons.save_rounded, size: 18),
                          label: const Text(
                            'Simpan',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Tombol Hapus Profil Router (Hanya muncul saat edit dan ada lebih dari 1 router)
                  if (!isAddingNew && widget.profiles.length > 1) ...[
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.error,
                        side: BorderSide(color: colorScheme.error.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Hapus Profil Router', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        showDialog(
                          context: ctx,
                          builder: (dialogCtx) => AlertDialog(
                            icon: Icon(Icons.delete_outline_rounded, color: colorScheme.error),
                            title: const Text('Hapus Router?'),
                            content: Text('Apakah Anda yakin ingin menghapus profil router "${profile.name}"?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogCtx),
                                child: const Text('Batal'),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
                                onPressed: () async {
                                  Navigator.pop(dialogCtx);
                                  Navigator.pop(ctx);
                                  await StorageService.deleteProfile(profile.id);
                                  if (widget.activeProfile?.id == profile.id) {
                                    final remaining = widget.profiles.where((p) => p.id != profile.id).toList();
                                    if (remaining.isNotEmpty) {
                                      widget.onSwitchProfile?.call(remaining.first.id);
                                    }
                                  }
                                  widget.onProfilesUpdated?.call();
                                  _showSnack('Profil router "${profile.name}" telah dihapus.');
                                },
                                child: const Text('Hapus'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final active = widget.activeProfile;
    final profilesList = widget.profiles.isNotEmpty
        ? widget.profiles
        : [active ?? StorageService.defaultProfile];

    return ListView(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 12.0, bottom: 88.0),
      children: [
        // Card Router MikroTik (Group nempel seperti Tampilan & Notifikasi)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader('Router MikroTik (${widget.profiles.length})', colorScheme.primary),
            TextButton.icon(
              onPressed: () => _showEditRouterDrawer(isAddingNew: true),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Tambah', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        Card(
          elevation: 0,
          color: colorScheme.surfaceContainer,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Column(
            children: [
              for (int i = 0; i < profilesList.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                Builder(
                  builder: (ctx) {
                    final p = profilesList[i];
                    final isActive = p.id == (active?.id ?? '');
                    return ListTile(
                      leading: Icon(
                        Icons.router_outlined,
                        color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
                      ),
                      title: Text(
                        p.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isActive ? colorScheme.primary : colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        p.host,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: Switch(
                        value: isActive,
                        onChanged: (val) {
                          if (val && !isActive) {
                            widget.onSwitchProfile?.call(p.id);
                            _showSnack('Router "${p.name}" diaktifkan.');
                          } else if (!val && isActive) {
                            _showSnack('Router ini sedang aktif.');
                          }
                        },
                      ),
                      onTap: () => _showEditRouterDrawer(profileToEdit: p),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Auto Reconnect Card
        Card(
          elevation: 0,
          color: colorScheme.surfaceContainer,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: SwitchListTile(
            secondary: const Icon(Icons.sync_outlined),
            title: const Text('Auto Reconnect'),
            subtitle: const Text('Sambungkan kembali otomatis jika koneksi putus'),
            value: _autoReconnect,
            onChanged: (val) => setState(() => _autoReconnect = val),
          ),
        ),
        const SizedBox(height: 16),

        // Section: Tampilan & Preferensi
        _buildSectionHeader('Tampilan & Notifikasi', colorScheme.primary),
        Card(
          elevation: 0,
          color: colorScheme.surfaceContainer,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.dark_mode_outlined),
                title: const Text('Mode Gelap'),
                subtitle: const Text('Sesuaikan tema terang/gelap M3'),
                value: widget.isDark,
                onChanged: (_) => widget.onToggleTheme(),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              SwitchListTile(
                secondary: const Icon(Icons.notifications_active_outlined),
                title: const Text('Peringatan CPU > 90%'),
                subtitle: const Text('Push notifikasi saat resource router tinggi'),
                value: _alertCpu,
                onChanged: (val) => setState(() => _alertCpu = val),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Section: Operasional & Cadangan
        _buildSectionHeader('Operasional & Pemeliharaan', colorScheme.primary),
        Card(
          elevation: 0,
          color: colorScheme.surfaceContainer,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.cloud_upload_outlined),
                title: const Text('Backup Konfigurasi'),
                subtitle: const Text('Ekspor file konfigurasi RouterOS (.backup)'),
                onTap: () => _showSnack('Backup config_mikrotik.backup berhasil dibuat!'),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.cleaning_services_outlined),
                title: const Text('Bersihkan Cache Lokal'),
                subtitle: const Text('Hapus session log dan temporary stats'),
                onTap: () => _showSnack('Cache 12.4 MB berhasil dibersihkan!'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Tombol Keluar (Sign Out)
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: colorScheme.error,
            side: BorderSide(color: colorScheme.error.withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: _confirmSignOut,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Keluar dari Akun Router', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
