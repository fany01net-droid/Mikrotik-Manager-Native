import 'package:flutter/material.dart';
import '../models/mikrotik_models.dart';
import '../services/mikrotik_api_service.dart';
import '../theme/fnet_theme.dart';
import '../utils/pppoe_utils.dart';
import '../widgets/toast_banner.dart';

class PppoeScreen extends StatefulWidget {
  final RouterProfile profile;

  const PppoeScreen({
    super.key,
    required this.profile,
  });

  @override
  State<PppoeScreen> createState() => PppoeScreenState();
}

class PppoeScreenState extends State<PppoeScreen> {
  int _selectedSubTab = 0; // 0: Secrets, 1: Active, 2: Profiles
  bool _isLoading = true;

  List<PppSecret> _secrets = [];
  List<PppActive> _activeSessions = [];
  List<PppProfile> _profiles = [];

  String _searchQuery = '';
  String _secretFilter = 'all';

  @override
  void initState() {
    super.initState();
    refreshData();
  }

  Future<void> refreshData() async {
    setState(() => _isLoading = true);
    try {
      final sFuture = MikrotikApiService.instance.getPppSecrets(widget.profile);
      final aFuture = MikrotikApiService.instance.getPppActive(widget.profile);
      final pFuture = MikrotikApiService.instance.getPppProfiles(widget.profile);

      final results = await Future.wait([sFuture, aFuture, pFuture]);

      if (mounted) {
        setState(() {
          _secrets = results[0] as List<PppSecret>;
          _activeSessions = results[1] as List<PppActive>;
          _profiles = results[2] as List<PppProfile>;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleExtend30Days(PppSecret secret) async {
    final updatedComment = PppoeUtils.extendExpiryDate(secret.comment);
    try {
      await MikrotikApiService.instance.updatePppSecret(widget.profile, secret.id, {
        'comment': updatedComment,
        'disabled': 'false',
      });
      if (mounted) {
        ToastBanner.show(
          context,
          message: 'Masa aktif ${secret.name} berhasil diperpanjang +30 hari.',
          type: ToastType.success,
        );
      }
      refreshData();
    } catch (e) {
      if (mounted) {
        ToastBanner.show(
          context,
          message: 'Gagal memperpanjang masa aktif: $e',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _handleToggleIsolir(PppSecret secret) async {
    final newDisabled = !secret.disabled;
    try {
      await MikrotikApiService.instance.updatePppSecret(widget.profile, secret.id, {
        'disabled': newDisabled ? 'true' : 'false',
      });
      if (newDisabled) {
        final active = _activeSessions.where((a) => a.name == secret.name).toList();
        for (final act in active) {
          try {
            await MikrotikApiService.instance.disconnectPppActive(widget.profile, act.id);
          } catch (_) {}
        }
      }
      if (mounted) {
        ToastBanner.show(
          context,
          message: 'Pelanggan ${secret.name} berhasil di-${newDisabled ? "isolir" : "buka isolir"}.',
          type: ToastType.success,
        );
      }
      refreshData();
    } catch (e) {
      if (mounted) {
        ToastBanner.show(
          context,
          message: 'Gagal mengubah status: $e',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _handleDisconnectActive(PppActive active) async {
    try {
      await MikrotikApiService.instance.disconnectPppActive(widget.profile, active.id);
      if (mounted) {
        ToastBanner.show(
          context,
          message: 'Sesi PPPoE ${active.name} berhasil diputuskan.',
          type: ToastType.success,
        );
      }
      refreshData();
    } catch (e) {
      if (mounted) {
        ToastBanner.show(
          context,
          message: 'Gagal memutuskan sesi: $e',
          type: ToastType.error,
        );
      }
    }
  }

  // --- M3 Add / Edit Secret Modal BottomSheet ---
  void _showSecretDialog({PppSecret? editingSecret, String? initialName, String? initialIp, String? initialComment}) {
    final isEditing = editingSecret != null;
    final nameCtrl = TextEditingController(text: editingSecret?.name ?? initialName ?? '');
    final passCtrl = TextEditingController(text: editingSecret?.password ?? '');
    final remoteIpCtrl = TextEditingController(text: editingSecret?.remoteAddress ?? initialIp ?? '');
    final noteCtrl = TextEditingController(
      text: editingSecret != null
          ? PppoeUtils.parseExpiryFromComment(editingSecret.comment).customerName
          : initialComment ?? '',
    );

    DateTime? selectedDate = editingSecret != null
        ? PppoeUtils.parseExpiryFromComment(editingSecret.comment).expiryDate
        : DateTime.now().add(const Duration(days: 30));

    String selectedProfile = editingSecret?.profile ?? (_profiles.isNotEmpty ? _profiles.first.name : 'default');
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
                        isEditing ? 'Edit Pelanggan PPPoE' : 'Tambah Pelanggan PPPoE',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Username
                  TextField(
                    controller: nameCtrl,
                    enabled: !isEditing,
                    decoration: const InputDecoration(
                      labelText: 'Username Pelanggan',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Password
                  TextField(
                    controller: passCtrl,
                    obscureText: obscurePass,
                    decoration: InputDecoration(
                      labelText: 'Kata Sandi PPPoE',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setModalState(() => obscurePass = !obscurePass),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Profile Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: _profiles.any((p) => p.name == selectedProfile) ? selectedProfile : null,
                    decoration: const InputDecoration(
                      labelText: 'Paket Kecepatan (PPP Profile)',
                      prefixIcon: Icon(Icons.speed),
                    ),
                    items: _profiles.map((p) {
                      return DropdownMenuItem(
                        value: p.name,
                        child: Text('${p.name} ${p.rateLimit.isNotEmpty ? "(${p.rateLimit})" : ""}'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedProfile = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Remote Address
                  TextField(
                    controller: remoteIpCtrl,
                    style: FNetTheme.monoStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'IP Static Remote (Opsional)',
                      hintText: '10.10.10.x',
                      prefixIcon: Icon(Icons.router_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Note / Customer Name
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nama Lengkap / Alamat / Catatan',
                      hintText: 'Pak Ahmad - Blok B2 No. 5',
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Expiry Date Picker Row
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: const Text('Tanggal Jatuh Tempo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      selectedDate != null
                          ? '${selectedDate!.day.toString().padLeft(2, "0")}-${selectedDate!.month.toString().padLeft(2, "0")}-${selectedDate!.year}'
                          : 'Tidak ada batas waktu',
                      style: FNetTheme.monoStyle(fontSize: 13, color: colorScheme.primary, fontWeight: FontWeight.w700),
                    ),
                    trailing: OutlinedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate ?? DateTime.now().add(const Duration(days: 30)),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setModalState(() => selectedDate = picked);
                        }
                      },
                      child: const Text('Pilih'),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // M3 Submit Button
                  FilledButton(
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      final pass = passCtrl.text;
                      final remoteIp = remoteIpCtrl.text.trim();
                      final note = noteCtrl.text.trim();

                      if (name.isEmpty) {
                        ToastBanner.show(ctx, message: 'Username tidak boleh kosong.', type: ToastType.error);
                        return;
                      }

                      final dateStr = selectedDate != null
                          ? '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, "0")}-${selectedDate!.day.toString().padLeft(2, "0")}'
                          : '';
                      final comment = PppoeUtils.buildExpiryComment(dateStr, note);

                      final payload = <String, String>{
                        'name': name,
                        'service': 'pppoe',
                        'profile': selectedProfile,
                        'comment': comment,
                      };
                      if (pass.isNotEmpty) payload['password'] = pass;
                      if (remoteIp.isNotEmpty) payload['remote-address'] = remoteIp;

                      Navigator.pop(ctx);

                      try {
                        if (isEditing) {
                          await MikrotikApiService.instance.updatePppSecret(widget.profile, editingSecret.id, payload);
                          if (mounted) {
                            ToastBanner.show(context, message: 'Pelanggan $name berhasil diperbarui.', type: ToastType.success);
                          }
                        } else {
                          await MikrotikApiService.instance.createPppSecret(widget.profile, payload);
                          if (mounted) {
                            ToastBanner.show(context, message: 'Pelanggan $name berhasil ditambahkan.', type: ToastType.success);
                          }
                        }
                        refreshData();
                      } catch (e) {
                        if (mounted) {
                          ToastBanner.show(context, message: 'Gagal menyimpan: $e', type: ToastType.error);
                        }
                      }
                    },
                    child: Text(isEditing ? 'Simpan Perubahan' : 'Buat Pelanggan PPPoE'),
                  ),

                  if (isEditing) ...[
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.error,
                        side: BorderSide(color: colorScheme.error.withValues(alpha: 0.5)),
                      ),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Hapus Pelanggan PPPoE'),
                      onPressed: () {
                        showDialog(
                          context: ctx,
                          builder: (dialogCtx) => AlertDialog(
                            icon: Icon(Icons.delete_outline, color: colorScheme.error),
                            title: const Text('Hapus Pelanggan'),
                            content: Text('Apakah Anda yakin ingin menghapus pelanggan "${editingSecret.name}"?'),
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
                                  try {
                                    await MikrotikApiService.instance.deletePppSecret(widget.profile, editingSecret.id);
                                    if (mounted) {
                                      ToastBanner.show(context, message: 'Pelanggan ${editingSecret.name} telah dihapus.', type: ToastType.success);
                                    }
                                    refreshData();
                                  } catch (e) {
                                    if (mounted) {
                                      ToastBanner.show(context, message: 'Gagal menghapus: $e', type: ToastType.error);
                                    }
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

  void openCreateSecret({String? initialName, String? initialIp, String? initialComment}) {
    setState(() => _selectedSubTab = 0);
    _showSecretDialog(initialName: initialName, initialIp: initialIp, initialComment: initialComment);
  }

  void openAddSecretPrefilled({required String name, required String ip, required String comment}) {
    openCreateSecret(initialName: name, initialIp: ip, initialComment: comment);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Column(
        children: [
          // M3 Segmented Button Sub Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                segments: [
                  ButtonSegment<int>(
                    value: 0,
                    icon: const Icon(Icons.vpn_key_outlined, size: 18),
                    label: Text('Pelanggan (${_secrets.length})'),
                  ),
                  ButtonSegment<int>(
                    value: 1,
                    icon: const Icon(Icons.online_prediction, size: 18),
                    label: Text('Aktif (${_activeSessions.length})'),
                  ),
                  ButtonSegment<int>(
                    value: 2,
                    icon: const Icon(Icons.speed, size: 18),
                    label: Text('Paket (${_profiles.length})'),
                  ),
                ],
                selected: {_selectedSubTab},
                onSelectionChanged: (set) => setState(() => _selectedSubTab = set.first),
              ),
            ),
          ),

          // Content body
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
                : RefreshIndicator(
                    onRefresh: refreshData,
                    color: colorScheme.primary,
                    child: _buildSubTabContent(),
                  ),
          ),
        ],
      ),
      floatingActionButton: _selectedSubTab == 0
          ? FloatingActionButton.extended(
              onPressed: () => _showSecretDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Pelanggan'),
            )
          : null,
    );
  }

  Widget _buildSubTabContent() {
    switch (_selectedSubTab) {
      case 0:
        return _buildSecretsTab();
      case 1:
        return _buildActiveSessionsTab();
      case 2:
        return _buildProfilesTab();
      default:
        return const SizedBox.shrink();
    }
  }

  // --- TAB 0: PPPoE Secrets ---
  Widget _buildSecretsTab() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final filtered = _secrets.where((s) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!s.name.toLowerCase().contains(q) && !s.comment.toLowerCase().contains(q)) {
          return false;
        }
      }
      final parsed = PppoeUtils.parseExpiryFromComment(s.comment);
      if (_secretFilter == 'active') {
        return !s.disabled && parsed.status == ExpiryStatus.active;
      } else if (_secretFilter == 'expiringSoon') {
        return !s.disabled && parsed.status == ExpiryStatus.expiringSoon;
      } else if (_secretFilter == 'expired') {
        return !s.disabled && parsed.status == ExpiryStatus.expired;
      } else if (_secretFilter == 'isolated') {
        return s.disabled;
      }
      return true;
    }).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Official M3 SearchBar
        SearchBar(
          hintText: 'Cari pelanggan PPPoE / catatan...',
          leading: const Icon(Icons.search),
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStatePropertyAll(colorScheme.surfaceContainerLowest),
          side: WidgetStatePropertyAll(BorderSide(color: colorScheme.outlineVariant)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onChanged: (val) => setState(() => _searchQuery = val),
        ),
        const SizedBox(height: 12),

        // M3 Filter Chips Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('all', 'Semua (${_secrets.length})'),
              _buildFilterChip('active', 'Aktif'),
              _buildFilterChip('expiringSoon', 'Segera Habis'),
              _buildFilterChip('expired', 'Kadaluarsa'),
              _buildFilterChip('isolated', 'Terisolir'),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (filtered.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(36),
              child: Text(
                'Tidak ada pelanggan yang cocok.',
                style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ),
          )
        else
          ...filtered.map((secret) {
            final parsed = PppoeUtils.parseExpiryFromComment(secret.comment);
            final isOnline = _activeSessions.any((a) => a.name == secret.name);

            Color badgeCol;
            String badgeText;

            if (secret.disabled) {
              badgeCol = colorScheme.error;
              badgeText = 'Isolir';
            } else {
              switch (parsed.status) {
                case ExpiryStatus.expired:
                  badgeCol = FNetTheme.rose;
                  badgeText = 'Kadaluarsa';
                  break;
                case ExpiryStatus.expiringSoon:
                  badgeCol = FNetTheme.amber;
                  badgeText = 'Sisa ${parsed.daysRemaining} hari';
                  break;
                case ExpiryStatus.active:
                  badgeCol = FNetTheme.emerald;
                  badgeText = 'Aktif (${parsed.daysRemaining}h)';
                  break;
                case ExpiryStatus.noExpiry:
                  badgeCol = Colors.grey;
                  badgeText = 'Tanpa Batas';
                  break;
              }
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: secret.disabled ? colorScheme.error.withValues(alpha: 0.6) : colorScheme.outlineVariant,
                  width: secret.disabled ? 1.5 : 1,
                ),
              ),
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
                            Badge(
                              smallSize: 10,
                              backgroundColor: isOnline ? FNetTheme.emerald : Colors.grey,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              secret.name,
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        Badge(
                          label: Text(badgeText),
                          backgroundColor: badgeCol.withValues(alpha: 0.16),
                          textColor: badgeCol,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (parsed.customerName.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          'Catatan: ${parsed.customerName}',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                        ),
                      ),
                    Row(
                      children: [
                        Text(
                          'Profil: ${secret.profile}',
                          style: FNetTheme.monoStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                        ),
                        if (secret.remoteAddress.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            '• IP: ${secret.remoteAddress}',
                            style: FNetTheme.monoStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                    if (parsed.expiryDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Jatuh Tempo: ${parsed.formattedExpiry}',
                          style: FNetTheme.monoStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: colorScheme.outlineVariant),
                    const SizedBox(height: 8),

                    // M3 Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: () => _handleExtend30Days(secret),
                          style: FilledButton.styleFrom(
                            backgroundColor: FNetTheme.emerald.withValues(alpha: 0.14),
                            foregroundColor: FNetTheme.emerald,
                            minimumSize: const Size(48, 40),
                          ),
                          icon: const Icon(Icons.more_time, size: 18),
                          label: const Text('+30 Hari', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _handleToggleIsolir(secret),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: secret.disabled ? FNetTheme.emerald : colorScheme.error,
                            side: BorderSide(color: secret.disabled ? FNetTheme.emerald : colorScheme.error),
                            minimumSize: const Size(48, 40),
                          ),
                          icon: Icon(secret.disabled ? Icons.lock_open : Icons.lock_outline, size: 18),
                          label: Text(secret.disabled ? 'Buka Isolir' : 'Isolir', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                        IconButton(
                          onPressed: () => _showSecretDialog(editingSecret: secret),
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 70),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _secretFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        onSelected: (_) => setState(() => _secretFilter = key),
      ),
    );
  }

  // --- TAB 1: PPPoE Active Sessions ---
  Widget _buildActiveSessionsTab() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_activeSessions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('Tidak ada sesi PPPoE aktif.', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _activeSessions.length,
      itemBuilder: (ctx, idx) {
        final active = _activeSessions[idx];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: FNetTheme.emerald.withValues(alpha: 0.16),
              foregroundColor: FNetTheme.emerald,
              radius: 20,
              child: const Icon(Icons.wifi_tethering, size: 20),
            ),
            title: Text(active.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text('IP: ${active.address} • MAC: ${active.callerId}', style: FNetTheme.monoStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
                Text('Uptime: ${active.uptime}', style: FNetTheme.monoStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
              ],
            ),
            trailing: IconButton(
              onPressed: () => _handleDisconnectActive(active),
              icon: const Icon(Icons.link_off, color: FNetTheme.rose, size: 22),
              tooltip: 'Putuskan Sesi',
            ),
          ),
        );
      },
    );
  }

  // --- TAB 2: PPPoE Profiles ---
  Widget _buildProfilesTab() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        ..._profiles.map((p) {
          final clientCount = _secrets.where((s) => s.profile == p.name).length;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(p.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      Badge(
                        label: Text('$clientCount Pelanggan'),
                        backgroundColor: colorScheme.primaryContainer,
                        textColor: colorScheme.onPrimaryContainer,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (p.rateLimit.isNotEmpty)
                    Text('Rate Limit: ${p.rateLimit}', style: FNetTheme.monoStyle(fontSize: 13, fontWeight: FontWeight.w800, color: FNetTheme.emerald)),
                  if (p.localAddress.isNotEmpty || p.remoteAddress.isNotEmpty)
                    Text(
                      'Local: ${p.localAddress.isNotEmpty ? p.localAddress : "-"} • Pool: ${p.remoteAddress.isNotEmpty ? p.remoteAddress : "-"}',
                      style: FNetTheme.monoStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
