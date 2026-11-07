import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/mikrotik_models.dart';
import '../services/mikrotik_api_service.dart';
import '../services/storage_service.dart';
import '../theme/fnet_theme.dart';
import '../widgets/toast_banner.dart';

class SettingsScreen extends StatefulWidget {
  final List<RouterProfile> profiles;
  final String activeProfileId;
  final ValueChanged<String> onSwitchProfile;
  final VoidCallback onProfilesUpdated;
  final bool isDark;
  final ValueChanged<bool> onThemeToggle;
  final VoidCallback onLogout;

  const SettingsScreen({
    super.key,
    required this.profiles,
    required this.activeProfileId,
    required this.onSwitchProfile,
    required this.onProfilesUpdated,
    required this.isDark,
    required this.onThemeToggle,
    required this.onLogout,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Map<String, ConnectionTestResult?> _testResults = {};
  final Map<String, bool> _testingMap = {};

  Future<void> _testRouterConnection(RouterProfile profile) async {
    setState(() => _testingMap[profile.id] = true);
    HapticFeedback.lightImpact();

    final result = await MikrotikApiService.instance.testConnection(profile);

    if (mounted) {
      setState(() {
        _testingMap[profile.id] = false;
        _testResults[profile.id] = result;
      });

      if (result.success) {
        ToastBanner.show(
          context,
          message: 'Terhubung ke ${profile.name}! Latensi: ${result.durationMs}ms',
          type: ToastType.success,
        );
      } else {
        ToastBanner.show(
          context,
          message: 'Koneksi gagal: ${result.error}',
          type: ToastType.error,
        );
      }
    }
  }

  void _showRouterModal({RouterProfile? editing}) {
    final isEditing = editing != null;
    final nameCtrl = TextEditingController(text: editing?.name ?? 'MikroTik Tambahan');
    final hostCtrl = TextEditingController(text: editing?.host ?? '192.168.88.1');
    final portCtrl = TextEditingController(text: (editing?.port ?? 80).toString());
    final userCtrl = TextEditingController(text: editing?.username ?? 'admin');
    final passCtrl = TextEditingController(text: editing?.password ?? '');
    bool useHttps = editing?.useHttps ?? false;
    bool obscurePass = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final theme = Theme.of(ctx);
          final colorScheme = theme.colorScheme;

          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 8,
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
                      Text(
                        isEditing ? 'Edit Profil Router' : 'Tambah Profil Router',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nama Profil Router',
                      prefixIcon: Icon(Icons.label_outline),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: hostCtrl,
                          style: FNetTheme.monoStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'IP / Host MikroTik',
                            hintText: '192.168.88.1',
                            prefixIcon: Icon(Icons.computer_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: portCtrl,
                          keyboardType: TextInputType.number,
                          style: FNetTheme.monoStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'Port',
                            hintText: '80',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  SwitchListTile(
                    title: const Text('Gunakan HTTPS / SSL', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    value: useHttps,
                    contentPadding: EdgeInsets.zero,
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
                  const SizedBox(height: 10),

                  TextField(
                    controller: userCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Username RouterOS',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: passCtrl,
                    obscureText: obscurePass,
                    decoration: InputDecoration(
                      labelText: 'Password RouterOS',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setModalState(() => obscurePass = !obscurePass),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  FilledButton(
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      final host = hostCtrl.text.trim();
                      final port = int.tryParse(portCtrl.text.trim()) ?? (useHttps ? 443 : 80);
                      final user = userCtrl.text.trim();
                      final pass = passCtrl.text;

                      if (name.isEmpty || host.isEmpty || user.isEmpty) {
                        ToastBanner.show(ctx, message: 'Nama, Host, dan Username wajib diisi.', type: ToastType.error);
                        return;
                      }

                      final newProfile = RouterProfile(
                        id: editing?.id ?? 'profile-${DateTime.now().millisecondsSinceEpoch}',
                        name: name,
                        host: host,
                        port: port,
                        useHttps: useHttps,
                        username: user,
                        password: pass,
                      );

                      Navigator.pop(ctx);
                      await StorageService.saveProfile(newProfile);
                      widget.onProfilesUpdated();
                      if (mounted) {
                        ToastBanner.show(context, message: 'Profil router $name berhasil disimpan.', type: ToastType.success);
                      }
                    },
                    child: Text(isEditing ? 'Simpan Perubahan' : 'Tambah Router'),
                  ),

                  if (isEditing && widget.profiles.length > 1) ...[
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.error,
                        side: BorderSide(color: colorScheme.error.withValues(alpha: 0.5)),
                      ),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Hapus Profil Router'),
                      onPressed: () {
                        showDialog(
                          context: ctx,
                          builder: (dialogCtx) => AlertDialog(
                            icon: Icon(Icons.delete_outline, color: colorScheme.error),
                            title: const Text('Hapus Profil Router'),
                            content: Text('Apakah Anda yakin ingin menghapus profil "${editing.name}"?'),
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
                                  await StorageService.deleteProfile(editing.id);
                                  if (widget.activeProfileId == editing.id) {
                                    final remaining = widget.profiles.where((p) => p.id != editing.id).toList();
                                    if (remaining.isNotEmpty) {
                                      widget.onSwitchProfile(remaining.first.id);
                                    }
                                  }
                                  widget.onProfilesUpdated();
                                  if (mounted) {
                                    ToastBanner.show(context, message: 'Profil router telah dihapus.', type: ToastType.success);
                                  }
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

  void _showChangeMasterAuthModal() {
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    StorageService.getMasterAuth().then((auth) {
      userCtrl.text = auth.username;
      passCtrl.text = auth.password;
    });

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Kredensial Petugas', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: userCtrl,
                decoration: const InputDecoration(labelText: 'Username Baru', prefixIcon: Icon(Icons.person)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passCtrl,
                decoration: const InputDecoration(labelText: 'Password Baru', prefixIcon: Icon(Icons.lock)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(
              onPressed: () async {
                final u = userCtrl.text.trim();
                final p = passCtrl.text;
                if (u.isEmpty || p.isEmpty) {
                  ToastBanner.show(ctx, message: 'Username & Password tidak boleh kosong.', type: ToastType.error);
                  return;
                }
                await StorageService.saveMasterAuth(MasterAuth(username: u, password: p));
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ToastBanner.show(context, message: 'Kredensial petugas berhasil diubah.', type: ToastType.success);
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Profil MikroTik (${widget.profiles.length})',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _showRouterModal(),
              style: FilledButton.styleFrom(minimumSize: const Size(48, 38)),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tambah Router', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 10),

        ...widget.profiles.map((profile) {
          final isActive = profile.id == widget.activeProfileId;
          final isTesting = _testingMap[profile.id] == true;
          final testRes = _testResults[profile.id];

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isActive ? colorScheme.primary : colorScheme.outlineVariant,
                width: isActive ? 2 : 1,
              ),
            ),
            child: InkWell(
              onTap: () {
                if (!isActive) {
                  widget.onSwitchProfile(profile.id);
                  ToastBanner.show(context, message: 'Beralih ke router ${profile.name}', type: ToastType.info);
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: isActive ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest,
                              foregroundColor: isActive ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                              child: const Icon(Icons.router_outlined, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      profile.name,
                                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                                    ),
                                    if (isActive) ...[
                                      const SizedBox(width: 8),
                                      Badge(
                                        label: const Text('Aktif'),
                                        backgroundColor: colorScheme.primaryContainer,
                                        textColor: colorScheme.onPrimaryContainer,
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  '${profile.host}:${profile.port} (${profile.username})',
                                  style: FNetTheme.monoStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => _showRouterModal(editing: profile),
                          icon: const Icon(Icons.settings_outlined, size: 20),
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: colorScheme.outlineVariant),
                    const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        OutlinedButton.icon(
                          onPressed: isTesting ? null : () => _testRouterConnection(profile),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(48, 38),
                          ),
                          icon: isTesting
                              ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary))
                              : const Icon(Icons.network_check_outlined, size: 16),
                          label: Text(
                            isTesting ? 'Menguji...' : 'Uji Koneksi',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (testRes != null)
                          Badge(
                            label: Text(
                              testRes.success ? '${testRes.durationMs}ms' : 'Gagal',
                              style: FNetTheme.monoStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: FNetTheme.latencyColor(testRes.durationMs),
                              ),
                            ),
                            backgroundColor: FNetTheme.latencyColor(testRes.durationMs).withValues(alpha: 0.16),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 16),

        Text(
          'Preferensi & Keamanan',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),

        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.dark_mode_outlined),
                title: const Text('Mode Gelap (NOC Dark Slate)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                value: widget.isDark,
                onChanged: (val) => widget.onThemeToggle(val),
              ),
              Divider(height: 1, color: colorScheme.outlineVariant),

              ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: const Text('Ganti Kredensial Petugas', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                subtitle: Text('Ubah username dan password login', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: _showChangeMasterAuthModal,
              ),
              Divider(height: 1, color: colorScheme.outlineVariant),

              ListTile(
                leading: const Icon(Icons.logout, color: FNetTheme.rose),
                title: const Text('Keluar Sesi Petugas', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: FNetTheme.rose)),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      icon: Icon(Icons.logout, color: colorScheme.error),
                      title: const Text('Konfirmasi Keluar', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      content: const Text('Apakah Anda yakin ingin keluar dari sesi petugas?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
                          onPressed: () {
                            Navigator.pop(ctx);
                            widget.onLogout();
                          },
                          child: const Text('Keluar'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        Center(
          child: Column(
            children: [
              Text(
                'FNet MikroTik Monitor',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                'Versi 1.1.0 • Material Design 3 (M3)',
                style: FNetTheme.monoStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 2),
              Text(
                'Zero Cloud Dependency • Privacy First',
                style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
