import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/mikrotik_models.dart';
import '../services/mikrotik_api_service.dart';
import '../theme/fnet_theme.dart';
import '../utils/format_utils.dart';
import '../utils/hotspot_utils.dart';
import '../widgets/toast_banner.dart';

class HotspotScreen extends StatefulWidget {
  final RouterProfile profile;

  const HotspotScreen({
    super.key,
    required this.profile,
  });

  @override
  State<HotspotScreen> createState() => HotspotScreenState();
}

class HotspotScreenState extends State<HotspotScreen> {
  int _selectedSubTab = 0; // 0: Users/Vouchers, 1: Active, 2: Profiles, 3: Generator
  bool _isLoading = true;

  List<HotspotUser> _users = [];
  List<HotspotActive> _activeSessions = [];
  List<HotspotProfile> _profiles = [];

  String _searchQuery = '';
  String _userFilter = 'all';

  @override
  void initState() {
    super.initState();
    refreshData();
  }

  Future<void> refreshData() async {
    setState(() => _isLoading = true);
    try {
      final uFuture = MikrotikApiService.instance.getHotspotUsers(widget.profile);
      final aFuture = MikrotikApiService.instance.getHotspotActive(widget.profile);
      final pFuture = MikrotikApiService.instance.getHotspotProfiles(widget.profile);

      final results = await Future.wait([uFuture, aFuture, pFuture]);

      if (mounted) {
        setState(() {
          _users = results[0] as List<HotspotUser>;
          _activeSessions = results[1] as List<HotspotActive>;
          _profiles = results[2] as List<HotspotProfile>;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleResetMac(HotspotUser user) async {
    try {
      await MikrotikApiService.instance.updateHotspotUser(widget.profile, user.id, {
        'mac-address': '00:00:00:00:00:00',
      });
      final active = _activeSessions.where((a) => a.user == user.name).toList();
      for (final act in active) {
        try {
          await MikrotikApiService.instance.disconnectHotspotActive(widget.profile, act.id);
        } catch (_) {}
      }
      if (mounted) {
        ToastBanner.show(
          context,
          message: 'Kuncian MAC voucher ${user.name} berhasil di-reset.',
          type: ToastType.success,
        );
      }
      refreshData();
    } catch (e) {
      if (mounted) {
        ToastBanner.show(
          context,
          message: 'Gagal mereset MAC: $e',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _handleDisconnectActive(HotspotActive active) async {
    try {
      await MikrotikApiService.instance.disconnectHotspotActive(widget.profile, active.id);
      if (mounted) {
        ToastBanner.show(
          context,
          message: 'Sesi voucher ${active.user} berhasil diputuskan.',
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

  // --- M3 Thermal Slip Receipt Modal ---
  void _showPrintVoucherReceipt(HotspotUser user) {
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final colorScheme = theme.colorScheme;

        return AlertDialog(
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.onPrimaryContainer,
                child: const Icon(Icons.wifi, size: 28),
              ),
              const SizedBox(height: 14),
              Text(
                'FNet Hotspot Voucher',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                'Internet Cepat & Handal',
                style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Divider(thickness: 1, color: colorScheme.outlineVariant),
              const SizedBox(height: 14),

              // Code Box
              Card(
                elevation: 0,
                color: colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  child: Column(
                    children: [
                      Text('KODE LOGIN VOUCHER', style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      SelectableText(
                        user.name,
                        style: FNetTheme.monoStyle(fontSize: 24, fontWeight: FontWeight.w900, color: colorScheme.primary),
                      ),
                      if (user.password.isNotEmpty && user.password != user.name) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Password: ${user.password}',
                          style: FNetTheme.monoStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Paket / Profil:', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                  Text(user.profile, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ],
              ),
              if (user.limitUptime.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Masa Aktif:', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                    Text(user.limitUptime, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: user.name));
                        ToastBanner.show(ctx, message: 'Kode voucher berhasil disalin!', type: ToastType.success);
                      },
                      icon: const Icon(Icons.copy_outlined, size: 16),
                      label: const Text('Salin'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Tutup'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // --- M3 Batch Voucher Generator Modal ---
  void _showBatchGenerateModal() {
    final prefixCtrl = TextEditingController(text: 'fn-');
    final countCtrl = TextEditingController(text: '10');
    final limitCtrl = TextEditingController(text: '3h');
    final commentCtrl = TextEditingController(text: 'Batch ${DateTime.now().day}/${DateTime.now().month}');
    String selectedProfile = _profiles.isNotEmpty ? _profiles.first.name : 'default';
    int codeLength = 6;
    bool isGenerating = false;

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
                        'Generate Voucher Massal',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: prefixCtrl,
                          decoration: const InputDecoration(labelText: 'Prefix Kode', hintText: 'fn-'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: countCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Jumlah Voucher', hintText: '10'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  DropdownButtonFormField<String>(
                    initialValue: _profiles.any((p) => p.name == selectedProfile) ? selectedProfile : null,
                    decoration: const InputDecoration(
                      labelText: 'Paket / Profil Hotspot',
                      prefixIcon: Icon(Icons.speed),
                    ),
                    items: _profiles.map((p) => DropdownMenuItem(value: p.name, child: Text(p.name))).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedProfile = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: limitCtrl,
                    style: FNetTheme.monoStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Limit Waktu Uptime',
                      hintText: '3h, 1d, 30m',
                      prefixIcon: Icon(Icons.timer_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: commentCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Catatan Batch / Penjualan',
                      hintText: 'Event Warung Kopi / Batch 1',
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                  ),
                  const SizedBox(height: 24),

                  FilledButton(
                    onPressed: isGenerating
                        ? null
                        : () async {
                            final count = int.tryParse(countCtrl.text.trim()) ?? 0;
                            if (count <= 0 || count > 100) {
                              ToastBanner.show(ctx, message: 'Jumlah voucher harus antara 1 sampai 100.', type: ToastType.error);
                              return;
                            }

                            setModalState(() => isGenerating = true);

                            final vouchers = HotspotUtils.generateBatchVouchers(
                              prefix: prefixCtrl.text.trim(),
                              count: count,
                              codeLength: codeLength,
                              profile: selectedProfile,
                              limitUptime: limitCtrl.text.trim(),
                              comment: commentCtrl.text.trim(),
                            );

                            int successCount = 0;
                            for (final payload in vouchers) {
                              try {
                                await MikrotikApiService.instance.createHotspotUser(widget.profile, payload);
                                successCount++;
                              } catch (_) {}
                            }

                            if (ctx.mounted) Navigator.pop(ctx);
                            refreshData();
                            if (mounted) {
                              ToastBanner.show(
                                context,
                                message: 'Berhasil membuat $successCount dari $count voucher massal.',
                                type: ToastType.success,
                              );
                            }
                          },
                    child: isGenerating
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.onPrimary),
                          )
                        : const Text('Generate Voucher Sekarang'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- M3 Add / Edit Single Voucher Modal ---
  void _showSingleVoucherModal({HotspotUser? editingUser}) {
    final isEditing = editingUser != null;
    final nameCtrl = TextEditingController(text: editingUser?.name ?? '');
    final passCtrl = TextEditingController(text: editingUser?.password ?? '');
    final limitCtrl = TextEditingController(text: editingUser?.limitUptime ?? '3h');
    final commentCtrl = TextEditingController(text: editingUser?.comment ?? '');
    String selectedProfile = editingUser?.profile ?? (_profiles.isNotEmpty ? _profiles.first.name : 'default');

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
                        isEditing ? 'Edit Voucher Hotspot' : 'Buat Voucher Manual',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: nameCtrl,
                    enabled: !isEditing,
                    decoration: const InputDecoration(
                      labelText: 'Kode / Username Voucher',
                      prefixIcon: Icon(Icons.confirmation_number_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: passCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Password (Biarkan kosong jika sama)',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 14),

                  DropdownButtonFormField<String>(
                    initialValue: _profiles.any((p) => p.name == selectedProfile) ? selectedProfile : null,
                    decoration: const InputDecoration(
                      labelText: 'Paket Hotspot',
                      prefixIcon: Icon(Icons.speed),
                    ),
                    items: _profiles.map((p) => DropdownMenuItem(value: p.name, child: Text(p.name))).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedProfile = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: limitCtrl,
                    style: FNetTheme.monoStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Limit Waktu (Contoh: 3h, 1d)',
                      prefixIcon: Icon(Icons.timer_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: commentCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Catatan Penjualan / Nama Pembeli',
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                  ),
                  const SizedBox(height: 24),

                  FilledButton(
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      final pass = passCtrl.text.trim().isNotEmpty ? passCtrl.text.trim() : name;
                      if (name.isEmpty) {
                        ToastBanner.show(ctx, message: 'Username tidak boleh kosong.', type: ToastType.error);
                        return;
                      }

                      final payload = <String, dynamic>{
                        'name': name,
                        'password': pass,
                        'profile': selectedProfile,
                        if (limitCtrl.text.trim().isNotEmpty) 'limit-uptime': limitCtrl.text.trim(),
                        if (commentCtrl.text.trim().isNotEmpty) 'comment': commentCtrl.text.trim(),
                      };

                      Navigator.pop(ctx);
                      try {
                        if (isEditing) {
                          await MikrotikApiService.instance.updateHotspotUser(widget.profile, editingUser.id, payload);
                          if (mounted) {
                            ToastBanner.show(context, message: 'Voucher $name diperbarui.', type: ToastType.success);
                          }
                        } else {
                          await MikrotikApiService.instance.createHotspotUser(widget.profile, payload);
                          if (mounted) {
                            ToastBanner.show(context, message: 'Voucher $name berhasil dibuat.', type: ToastType.success);
                          }
                        }
                        refreshData();
                      } catch (e) {
                        if (mounted) {
                          ToastBanner.show(context, message: 'Gagal menyimpan voucher: $e', type: ToastType.error);
                        }
                      }
                    },
                    child: Text(isEditing ? 'Simpan Perubahan' : 'Buat Voucher'),
                  ),

                  if (isEditing) ...[
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.error,
                        side: BorderSide(color: colorScheme.error.withValues(alpha: 0.5)),
                      ),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Hapus Voucher Hotspot'),
                      onPressed: () {
                        showDialog(
                          context: ctx,
                          builder: (dialogCtx) => AlertDialog(
                            icon: Icon(Icons.delete_outline, color: colorScheme.error),
                            title: const Text('Hapus Voucher'),
                            content: Text('Apakah Anda yakin ingin menghapus voucher "${editingUser.name}"?'),
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
                                    await MikrotikApiService.instance.deleteHotspotUser(widget.profile, editingUser.id);
                                    if (mounted) {
                                      ToastBanner.show(context, message: 'Voucher ${editingUser.name} telah dihapus.', type: ToastType.success);
                                    }
                                    refreshData();
                                  } catch (e) {
                                    if (mounted) {
                                      ToastBanner.show(context, message: 'Gagal menghapus voucher: $e', type: ToastType.error);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Column(
        children: [
          // Official Material 3 SegmentedButton for Sub-Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                segments: [
                  ButtonSegment<int>(
                    value: 0,
                    icon: const Icon(Icons.confirmation_number_outlined, size: 18),
                    label: Text('Voucher (${_users.length})'),
                  ),
                  ButtonSegment<int>(
                    value: 1,
                    icon: const Icon(Icons.devices, size: 18),
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
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'batchGen',
                  onPressed: _showBatchGenerateModal,
                  icon: const Icon(Icons.auto_mode),
                  label: const Text('Batch'),
                ),
                const SizedBox(width: 10),
                FloatingActionButton(
                  heroTag: 'singleUser',
                  onPressed: () => _showSingleVoucherModal(),
                  child: const Icon(Icons.add),
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildSubTabContent() {
    switch (_selectedSubTab) {
      case 0:
        return _buildVouchersTab();
      case 1:
        return _buildActiveSessionsTab();
      case 2:
        return _buildProfilesTab();
      default:
        return const SizedBox.shrink();
    }
  }

  // --- TAB 0: Hotspot Vouchers ---
  Widget _buildVouchersTab() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final filtered = _users.where((u) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!u.name.toLowerCase().contains(q) && !u.comment.toLowerCase().contains(q)) {
          return false;
        }
      }
      final exp = HotspotUtils.calculateHotspotUserExpiry(u, _profiles);
      if (_userFilter == 'active') {
        return exp.status == HotspotStatus.active;
      } else if (_userFilter == 'expiringSoon') {
        return exp.status == HotspotStatus.expiringSoon;
      } else if (_userFilter == 'expired') {
        return exp.status == HotspotStatus.expired;
      } else if (_userFilter == 'unused') {
        return exp.status == HotspotStatus.unused;
      }
      return true;
    }).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Official M3 SearchBar
        SearchBar(
          hintText: 'Cari kode voucher / catatan...',
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

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('all', 'Semua (${_users.length})'),
              _buildFilterChip('active', 'Aktif'),
              _buildFilterChip('expiringSoon', 'Segera Habis'),
              _buildFilterChip('expired', 'Kadaluarsa'),
              _buildFilterChip('unused', 'Belum Dipakai'),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (filtered.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(36),
              child: Text('Tidak ada voucher yang cocok.', style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
            ),
          )
        else
          ...filtered.map((user) {
            final exp = HotspotUtils.calculateHotspotUserExpiry(user, _profiles);
            final isOnline = _activeSessions.any((a) => a.user == user.name);

            Color badgeCol;
            switch (exp.status) {
              case HotspotStatus.active:
                badgeCol = FNetTheme.emerald;
                break;
              case HotspotStatus.expiringSoon:
                badgeCol = FNetTheme.amber;
                break;
              case HotspotStatus.expired:
                badgeCol = FNetTheme.rose;
                break;
              case HotspotStatus.unused:
                badgeCol = FNetTheme.sky;
                break;
              case HotspotStatus.disabled:
                badgeCol = Colors.grey;
                break;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
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
                            SelectableText(
                              user.name,
                              style: FNetTheme.monoStyle(fontSize: 16, fontWeight: FontWeight.w800, color: colorScheme.onSurface),
                            ),
                          ],
                        ),
                        Badge(
                          label: Text(exp.badgeText),
                          backgroundColor: badgeCol.withValues(alpha: 0.16),
                          textColor: badgeCol,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Text('Profil: ${user.profile}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colorScheme.onSurface)),
                        const SizedBox(width: 8),
                        Text('• ${exp.sisaText}', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                      ],
                    ),
                    if (user.comment.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text('Catatan: ${user.comment}', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      'Pemakaian: ${FormatUtils.formatBytes(user.bytesIn + user.bytesOut)}',
                      style: FNetTheme.monoStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: colorScheme.outlineVariant),
                    const SizedBox(height: 8),

                    // M3 Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: () => _showPrintVoucherReceipt(user),
                          style: FilledButton.styleFrom(
                            backgroundColor: colorScheme.primaryContainer,
                            foregroundColor: colorScheme.onPrimaryContainer,
                            minimumSize: const Size(48, 40),
                          ),
                          icon: const Icon(Icons.receipt_long_outlined, size: 18),
                          label: const Text('Cetak Slip', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _handleResetMac(user),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: FNetTheme.amber,
                            side: const BorderSide(color: FNetTheme.amber),
                            minimumSize: const Size(48, 40),
                          ),
                          icon: const Icon(Icons.phonelink_erase, size: 18),
                          label: const Text('Reset MAC', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                        IconButton(
                          onPressed: () => _showSingleVoucherModal(editingUser: user),
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
    final isSelected = _userFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        onSelected: (_) => setState(() => _userFilter = key),
      ),
    );
  }

  // --- TAB 1: Hotspot Active Sessions ---
  Widget _buildActiveSessionsTab() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_activeSessions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('Tidak ada sesi voucher aktif.', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)),
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
              child: const Icon(Icons.wifi, size: 20),
            ),
            title: Text(active.user, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text('IP: ${active.address} • MAC: ${active.macAddress}', style: FNetTheme.monoStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
                Text('Sisa Sesi: ${active.sessionTimeLeft.isNotEmpty ? active.sessionTimeLeft : active.uptime}', style: FNetTheme.monoStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
              ],
            ),
            trailing: IconButton(
              onPressed: () => _handleDisconnectActive(active),
              icon: const Icon(Icons.link_off, color: FNetTheme.rose, size: 22),
              tooltip: 'Putuskan Voucher',
            ),
          ),
        );
      },
    );
  }

  // --- TAB 2: Hotspot Profiles ---
  Widget _buildProfilesTab() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        ..._profiles.map((p) {
          final voucherCount = _users.where((u) => u.profile == p.name).length;
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
                        label: Text('$voucherCount Voucher'),
                        backgroundColor: colorScheme.primaryContainer,
                        textColor: colorScheme.onPrimaryContainer,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (p.rateLimit.isNotEmpty)
                    Text('Rate Limit: ${p.rateLimit}', style: FNetTheme.monoStyle(fontSize: 13, fontWeight: FontWeight.w800, color: FNetTheme.emerald)),
                  Text(
                    'Shared Users: ${p.sharedUsers} • Pool: ${p.addressPool.isNotEmpty ? p.addressPool : "none"}',
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
