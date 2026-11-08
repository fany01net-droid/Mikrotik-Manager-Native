import 'package:flutter/material.dart';
import '../models/mikrotik_models.dart';
import '../services/storage_service.dart';
import '../services/mikrotik_api_service.dart';
import 'beranda_screen.dart';
import 'pppoe_screen.dart';
import 'hotspot_screen.dart';
import 'dhcp_screen.dart';
import '../widgets/toast_banner.dart';

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
  int _currentPageIndex = 0; // Default: Dashboard
  bool _isSearching = false;
  String _appBarSearchQuery = '';
  final TextEditingController _appBarSearchController = TextEditingController();

  final GlobalKey<BerandaScreenState> _berandaKey = GlobalKey<BerandaScreenState>();
  final GlobalKey<PppoeScreenState> _pppoeKey = GlobalKey<PppoeScreenState>();
  final GlobalKey<HotspotScreenState> _hotspotKey = GlobalKey<HotspotScreenState>();
  final GlobalKey<DhcpScreenState> _dhcpKey = GlobalKey<DhcpScreenState>();

  final List<String> _titles = const [
    'Dashboard',
    'PPPoE',
    'Hotspot',
    'DHCP',
    'Pengaturan',
  ];

  List<RouterProfile> _profiles = [StorageService.defaultProfile];
  String _activeProfileId = 'default-profile';

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  @override
  void dispose() {
    _appBarSearchController.dispose();
    super.dispose();
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
        _currentPageIndex = 0; // Otomatis berpindah ke Dashboard untuk memuat data router yang dipilih
      });
    }
  }

  Map<String, String>? _prefilledPppoeData;

  void _handleConvertToPppoe({required String name, required String ip, required String comment}) {
    setState(() {
      _prefilledPppoeData = {
        'name': name,
        'ip': ip,
        'comment': comment,
      };
      _currentPageIndex = 1;
    });
  }

  Widget _buildActivePage(int index, RouterProfile active) {
    switch (index) {
      case 0:
        return BerandaScreen(
          key: _berandaKey,
          profile: active,
          onNavigateTab: (index) {
            setState(() {
              _currentPageIndex = index;
            });
          },
        );
      case 1:
        final prefill = _prefilledPppoeData;
        _prefilledPppoeData = null;
        return PppoeScreen(
          key: _pppoeKey,
          profile: active,
          initialSecretData: prefill,
          searchQuery: _appBarSearchQuery,
        );
      case 2:
        return HotspotScreen(
          key: _hotspotKey,
          profile: active,
          searchQuery: _appBarSearchQuery,
        );
      case 3:
        return DhcpScreen(
          key: _dhcpKey,
          profile: active,
          searchQuery: _appBarSearchQuery,
          onConvertToPppoe: _handleConvertToPppoe,
        );
      case 4:
        return SettingsContentPage(
          onToggleTheme: widget.onToggleTheme,
          isDark: widget.isDark,
          activeProfile: active,
          profiles: _profiles,
          onSwitchProfile: _handleSwitchProfile,
          onProfilesUpdated: _loadProfiles,
          onLogout: widget.onLogout,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _activeProfile;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: _isSearching && (_currentPageIndex >= 1 && _currentPageIndex <= 3)
          ? AppBar(
              titleSpacing: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Tutup Pencarian',
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _appBarSearchQuery = '';
                    _appBarSearchController.clear();
                  });
                },
              ),
              title: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: SizedBox(
                  height: 44,
                  child: TextField(
                    controller: _appBarSearchController,
                    autofocus: true,
                    style: theme.textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: _currentPageIndex == 1
                          ? 'Cari pelanggan PPPoE...'
                          : _currentPageIndex == 2
                              ? 'Cari voucher / user hotspot...'
                              : 'Cari IP, MAC, hostname DHCP...',
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _appBarSearchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              tooltip: 'Hapus',
                              onPressed: () {
                                setState(() {
                                  _appBarSearchQuery = '';
                                  _appBarSearchController.clear();
                                });
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHigh,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _appBarSearchQuery = val;
                      });
                    },
                  ),
                ),
              ),
            )
          : AppBar(
              title: Text(
                _titles[_currentPageIndex],
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              actions: [
                IconButton(
                  tooltip: 'Segarkan Data',
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    switch (_currentPageIndex) {
                      case 0:
                        _berandaKey.currentState?.refreshData();
                        break;
                      case 1:
                        _pppoeKey.currentState?.refreshData();
                        break;
                      case 2:
                        _hotspotKey.currentState?.refreshData();
                        break;
                      case 3:
                        _dhcpKey.currentState?.refreshData();
                        break;
                      default:
                        _loadProfiles();
                        break;
                    }
                  },
                ),
                if (_currentPageIndex == 0)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    tooltip: 'Opsi Dashboard',
                    onSelected: (val) {
                      if (val == 'edit') {
                        _berandaKey.currentState?.openCustomizeSheet();
                      } else if (val == 'show_all') {
                        _berandaKey.currentState?.showAllWidgets();
                      } else if (val == 'test_conn') {
                        _berandaKey.currentState?.testRouterConnection();
                      } else if (val == 'reset') {
                        _berandaKey.currentState?.resetAllDashboardSettings();
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.dashboard_customize_outlined, size: 20),
                            SizedBox(width: 10),
                            Text('Edit Tata Letak & Widget'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'show_all',
                        child: Row(
                          children: [
                            Icon(Icons.visibility_outlined, size: 20),
                            SizedBox(width: 10),
                            Text('Tampilkan Semua Widget'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'test_conn',
                        child: Row(
                          children: [
                            Icon(Icons.network_ping_rounded, size: 20),
                            SizedBox(width: 10),
                            Text('Uji Respon Koneksi'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'reset',
                        child: Row(
                          children: [
                            Icon(Icons.restart_alt_rounded, size: 20),
                            SizedBox(width: 10),
                            Text('Reset Tata Letak Default'),
                          ],
                        ),
                      ),
                    ],
                  ),
                if (_currentPageIndex >= 1 && _currentPageIndex <= 3)
                  IconButton(
                    tooltip: 'Cari',
                    icon: const Icon(Icons.search),
                    onPressed: () {
                      setState(() {
                        _isSearching = true;
                      });
                    },
                  ),
                const SizedBox(width: 8),
              ],
            ),
      body: _buildActivePage(_currentPageIndex, active),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentPageIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentPageIndex = index;
            _isSearching = false;
            _appBarSearchQuery = '';
            _appBarSearchController.clear();
          });
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.speed_outlined),
            selectedIcon: Icon(Icons.speed),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group),
            label: 'PPPoE',
          ),
          NavigationDestination(
            icon: Icon(Icons.wifi_outlined),
            selectedIcon: Icon(Icons.wifi),
            label: 'Hotspot',
          ),
          NavigationDestination(
            icon: Icon(Icons.lan_outlined),
            selectedIcon: Icon(Icons.lan),
            label: 'DHCP',
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

  void _showNotification(String msg, {bool isSuccess = true, bool atTop = false}) {
    ToastBanner.show(
      context,
      message: msg,
      type: isSuccess ? ToastType.success : ToastType.error,
      atTop: atTop,
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
              _showNotification('Berhasil keluar dari akun.');
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
    ConnectionTestResult? testResult;
    String? testValidationMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (modalCtx) => StatefulBuilder(
        builder: (innerCtx, setModalState) {
          final theme = Theme.of(innerCtx);
          final colorScheme = theme.colorScheme;

                return Padding(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 4,
                    bottom: MediaQuery.of(innerCtx).viewInsets.bottom + 24,
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
                                const Icon(Icons.router_outlined),
                                const SizedBox(width: 10),
                                Text(
                                  isAddingNew ? 'Tambah Profil Router' : 'Edit Profil Router',
                                  style: theme.textTheme.titleMedium,
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => Navigator.pop(modalCtx),
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
                  // Status / Hasil Tes Koneksi (Mengubah teks, tanpa elemen baru)
                  if (isTesting || testValidationMessage != null || testResult != null) ...[
                    const SizedBox(height: 14),
                    if (isTesting) ...[
                      LinearProgressIndicator(
                        borderRadius: BorderRadius.circular(4),
                        color: colorScheme.primary,
                        backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Center(
                      child: Text(
                        isTesting
                            ? 'Menguji koneksi ke router...'
                            : testValidationMessage != null
                                ? testValidationMessage!
                                : testResult!.success
                                    ? 'Terhubung ke router! Latensi: ${testResult!.durationMs}ms'
                                    : 'Koneksi gagal: ${testResult!.error ?? "Tidak ada respon"}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isTesting
                              ? colorScheme.primary
                              : (testValidationMessage != null || !testResult!.success)
                                  ? colorScheme.error
                                  : colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

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
                                      testValidationMessage = 'Host/IP router tidak boleh kosong.';
                                      testResult = null;
                                    });
                                    return;
                                  }
                                  setModalState(() {
                                    isTesting = true;
                                    testResult = null;
                                    testValidationMessage = null;
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
                                    testResult = res;
                                    testValidationMessage = null;
                                  });
                                },
                          icon: const Icon(Icons.network_check_rounded, size: 18),
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
                                testValidationMessage = 'Nama, Host/IP, dan Username wajib diisi.';
                                testResult = null;
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
                              Navigator.pop(modalCtx);
                              await StorageService.saveProfile(newProfile);
                              widget.onSwitchProfile?.call(newId);
                              widget.onProfilesUpdated?.call();
                              _showNotification('Router "$name" berhasil ditambahkan dan diaktifkan.');
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
                              Navigator.pop(modalCtx);
                              await StorageService.saveProfile(updatedProfile);
                              widget.onProfilesUpdated?.call();
                              _showNotification('Profil router "$name" berhasil disimpan.');
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
                          context: modalCtx,
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
                                  Navigator.pop(modalCtx);
                                  await StorageService.deleteProfile(profile.id);
                                  if (widget.activeProfile?.id == profile.id) {
                                    final remaining = widget.profiles.where((p) => p.id != profile.id).toList();
                                    if (remaining.isNotEmpty) {
                                      widget.onSwitchProfile?.call(remaining.first.id);
                                    }
                                  }
                                  widget.onProfilesUpdated?.call();
                                  _showNotification('Profil router "${profile.name}" telah dihapus.');
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
                      leading: const Icon(Icons.router_outlined),
                      title: Text(
                        p.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(p.host),
                      trailing: Switch(
                        value: isActive,
                        onChanged: (val) {
                          if (val && !isActive) {
                            widget.onSwitchProfile?.call(p.id);
                            _showNotification('Router "${p.name}" diaktifkan.');
                          } else if (!val && isActive) {
                            _showNotification('Router ini sedang aktif.');
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

        // Section: Operasional & Pemeliharaan
        _buildSectionHeader('Operasional & Pemeliharaan', colorScheme.primary),
        Card(
          elevation: 0,
          color: colorScheme.surfaceContainer,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('Bersihkan Cache Lokal'),
            subtitle: const Text('Hapus session log dan temporary stats'),
            onTap: () => _showNotification('Cache 12.4 MB berhasil dibersihkan!'),
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
